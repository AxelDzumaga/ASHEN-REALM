extends Node

## Combat Domain M6 — real (non-headless) engineering render smoke. Not a
## Human Visual Playtest (--headless's dummy renderer cannot produce real
## frames or drive AnimatedSprite2D/Tween choreography meaningfully). This
## specifically targets the M6 finding that some player-actor choreography
## call sites still drove the legacy hidden %PlayerCharacterView instead of
## the actor_id -> CombatCharacterView registry: every scenario asserts the
## REGISTRY-RESOLVED view's _current_animation_name actually changed, and
## that the legacy node never left IDLE. No subjective visual acceptance
## required — engineering assertions only, plus PNG captures as evidence.

const COMBAT_SCENE := preload("res://scenes/combat/combat.tscn")
const ASH_CRAWLER: EnemyData = preload("res://data/enemies/ash_crawler.tres")
const CALL_EMBERS_ACTION: EnemyActionData = preload("res://data/enemy_actions/call_embers.tres")
const OUTPUT_DIR := "res://build/combat_domain_render_smoke"

var _failures: Array[String] = []
var _seed: int = 990001


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"combat_domain_render_smoke")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _scenario_protagonist_only()
	await _scenario_protagonist_and_companion()
	await _scenario_synthetic_5v5()
	await _scenario_boss()
	await _scenario_boss_summon_phase()
	await _scenario_warden_counter()
	print("[COMBAT_RENDER_SMOKE] failures=%s" % JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(label: String, condition: bool) -> void:
	print("[COMBAT_RENDER_SMOKE] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


func _next_seed() -> int:
	_seed += 1
	return _seed


func _synthetic_ally_data(id: String) -> CompanionData:
	var data: CompanionData = CompanionData.new()
	data.companion_id = StringName(id)
	data.display_name = id
	data.max_hp = 40
	data.attack = 8
	data.defense = 2
	data.ability_id = StringName("%s_ability" % id)
	data.ability_name = "%s ABILITY" % id
	data.ability_every_actions = 3
	data.ability_status_id = &""
	return data


func _start_synthetic_combat(ally_count: int, extra_enemy_count: int, is_boss: bool = false, biome: BiomeData = null) -> Control:
	RunManager.start_new_run(_next_seed())
	if biome == null:
		biome = BiomeCatalog.ASHEN_WASTES
	RunManager.current_run.biome_data = biome
	RunManager.current_run.biome_id = biome.id
	RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	var combat: Control = COMBAT_SCENE.instantiate()
	var ally_data_list: Array[CompanionData] = []
	for ally_index: int in range(ally_count):
		ally_data_list.append(_synthetic_ally_data("a%d" % (ally_index + 1)))
	combat.set("_ally_data_override", ally_data_list)
	combat.configure(biome, is_boss, false)
	add_child(combat)
	await _wait_for_player_input(combat, 900)
	var enemy_actors: Array = combat.get("enemy_actors")
	var occupied_slots: Array[int] = []
	for occupying_actor: CombatActor in enemy_actors:
		occupied_slots.append(occupying_actor.formation_slot)
	var free_slots: Array[int] = CombatRules.find_available_formation_slots(occupied_slots, extra_enemy_count)
	for extra_index: int in range(extra_enemy_count):
		var extra: CombatActor = CombatActor.from_enemy(
			StringName("enemy_synthetic_%d" % extra_index), ASH_CRAWLER, CombatActor.ActorType.NORMAL_ENEMY,
		)
		extra.formation_slot = free_slots[extra_index]
		enemy_actors.append(extra)
	if extra_enemy_count > 0:
		combat.call("_build_enemy_slots")
	return combat


func _wait_for_player_input(combat: Control, maximum_frames: int) -> void:
	var frames: int = 0
	while int(combat.get("_phase")) != 1 and not bool(combat.get("_result_resolved")) and frames < maximum_frames:
		await get_tree().process_frame
		frames += 1


func _end_combat(combat: Control) -> void:
	combat.queue_free()
	await get_tree().process_frame
	RunManager.current_run = null


func _capture(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s.png" % [OUTPUT_DIR, label]
	var error: Error = image.save_png(path)
	print("[COMBAT_RENDER_SMOKE] CAPTURE %s -> %s error=%d" % [label, ProjectSettings.globalize_path(path), error])


## Registry-resolved view for the acting actor must actually receive the
## animation call; the legacy fixed %PlayerCharacterView must stay IDLE —
## the exact regression fixed on this branch (combat.gd _run_player_basic_
## action/_resolve_warden_counter/_execute_active_skill/_finish_defeat).
##
## The action function's own final beat calls play_idle() on whoever it
## animated before the turn/counter completes, and play_hit()/play_attack()
## on the acting view can be gated behind an earlier `await` (e.g. the
## counter's boss_view.play_attack() + choreography.begin_static() runs
## before player_actor_view.play_hit()) — so neither "check right after
## firing" nor "check after full completion" reliably samples the moment
## the call happened. Instead: fire the coroutine WITHOUT awaiting it (it
## still runs synchronously up to its first internal `await`, same as if
## awaited), then poll every frame for up to max_frames, OR-ing in whether
## the registry view was ever seen away from IDLE and AND-ing whether the
## legacy node ever left IDLE (it must not, for the whole window).
func _watch_view_routing(combat: Control, player_actor: CombatActor, label: String, action: Callable, max_frames: int = 240) -> void:
	var registry_view: CombatCharacterView = combat.call("_get_actor_view", player_actor)
	var legacy_view: CombatCharacterView = combat.get("player_view")
	_check("%s_registry_view_registered" % label, is_instance_valid(registry_view))
	_check("%s_registry_view_is_not_legacy_node" % label, registry_view != legacy_view)
	_check("%s_registry_view_visible_in_tree" % label, is_instance_valid(registry_view) and registry_view.is_visible_in_tree())
	_check("%s_legacy_node_hidden" % label, is_instance_valid(legacy_view) and not legacy_view.is_visible_in_tree())
	var registry_seen_non_idle: bool = false
	var legacy_stayed_idle: bool = true
	action.call()
	# Deliberately NOT gated on _phase: action is called directly (bypassing
	# _commit_player_action, the only place that flips _phase away from
	# PLAYER_INPUT), so _phase never changes here — a fixed frame budget
	# (plenty for a ~0.2-0.4s choreography beat at any real frame rate) is
	# the only reliable stop condition.
	var frames: int = 0
	while frames < max_frames and not bool(combat.get("_result_resolved")):
		if is_instance_valid(registry_view) and StringName(registry_view.get("_current_animation_name")) != CombatCharacterView.IDLE:
			registry_seen_non_idle = true
		if is_instance_valid(legacy_view) and StringName(legacy_view.get("_current_animation_name")) != CombatCharacterView.IDLE:
			legacy_stayed_idle = false
		await get_tree().process_frame
		frames += 1
	_check("%s_registry_view_animated_away_from_idle" % label, registry_seen_non_idle)
	_check("%s_legacy_node_never_animated" % label, legacy_stayed_idle)


func _fire_basic_attack_and_check(combat: Control, player_actor: CombatActor, target_actor: CombatActor, label: String) -> void:
	await _watch_view_routing(combat, player_actor, label, func() -> void: combat.call("_run_player_basic_action", target_actor))
	await _wait_for_player_input(combat, 900)


## A — protagonist only (1v1), real GPU render.
func _scenario_protagonist_only() -> void:
	var combat: Control = await _start_synthetic_combat(0, 0)
	var player_actor: CombatActor = combat.get("player_actor")
	var enemy_actor: CombatActor = combat.get("enemy_actor")
	_check("protagonist_only_one_slot", (combat.get("player_actors") as Array).size() == 1)
	await _capture("01_protagonist_only_pre_attack")
	await _fire_basic_attack_and_check(combat, player_actor, enemy_actor, "protagonist_only")
	await _capture("02_protagonist_only_post_attack")
	await _end_combat(combat)


## B — protagonist + companion (production path, not the synthetic seam).
func _scenario_protagonist_and_companion() -> void:
	RunManager.start_new_run(_next_seed())
	var biome: BiomeData = BiomeCatalog.ASHEN_WASTES
	RunManager.current_run.biome_data = biome
	RunManager.current_run.biome_id = biome.id
	RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	RunManager.current_run.equipped_companion_id = CompanionCatalog.EMBER_HOUND_ID
	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(biome, false, false)
	add_child(combat)
	await _wait_for_player_input(combat, 900)
	var player_actor: CombatActor = combat.get("player_actor")
	_check("companion_two_player_actors", (combat.get("player_actors") as Array).size() == 2)
	var enemy_actor: CombatActor = combat.get("enemy_actor")
	await _fire_basic_attack_and_check(combat, player_actor, enemy_actor, "companion")
	await _capture("03_protagonist_and_companion")
	await _end_combat(combat)


## C + D — synthetic 5v5, plus five-enemy target selection.
func _scenario_synthetic_5v5() -> void:
	var combat: Control = await _start_synthetic_combat(4, 4)
	var player_actor: CombatActor = combat.get("player_actor")
	var player_actors: Array = combat.get("player_actors")
	var enemy_actors: Array[CombatActor] = combat.get("enemy_actors")
	_check("5v5_player_team_is_five", player_actors.size() == 5)
	_check("5v5_enemy_team_is_five", enemy_actors.size() == 5)
	var e4: CombatActor = enemy_actors[4]
	combat.call("_on_enemy_target_requested", e4)
	_check("5v5_fifth_enemy_selectable", combat.get("selected_enemy_actor") == e4)
	await _fire_basic_attack_and_check(combat, player_actor, e4, "5v5")
	await _capture("04_synthetic_5v5")
	await _end_combat(combat)


## E — boss encounter (Warden), real GPU render.
func _scenario_boss() -> void:
	var combat: Control = await _start_synthetic_combat(0, 0, true, BiomeCatalog.ASHEN_WASTES)
	var player_actor: CombatActor = combat.get("player_actor")
	var boss_actor: CombatActor = combat.get("_boss_actor")
	_check("boss_present", boss_actor != null)
	await _capture("05_boss_encounter")
	if boss_actor != null:
		await _fire_basic_attack_and_check(combat, player_actor, boss_actor, "boss")
	await _end_combat(combat)


## F — boss summon/phase transition (Sunken Pyre, Ember Marsh — matches the
## fixture already used by combat_5v5_capacity_test/combat_event_order_test).
func _scenario_boss_summon_phase() -> void:
	var combat: Control = await _start_synthetic_combat(0, 0, true, BiomeCatalog.EMBER_MARSH)
	var boss_actor: CombatActor = combat.get("_boss_actor")
	var boss_controller: BossEncounterController = combat.get("_boss_controller")
	_check("summon_boss_present", boss_actor != null)
	if boss_actor == null:
		await _end_combat(combat)
		return
	boss_actor.set_current_hp(roundi(float(boss_actor.get_max_hp()) * 0.65))
	await combat.call("_check_boss_phase_transition")
	_check("summon_phase_pending", boss_controller.get_pending_summon_phase() != null)
	var ai_state: EnemyAIRuntimeState = EnemyAIRuntimeState.new()
	var enemy_count_before: int = (combat.get("enemy_actors") as Array).size()
	await combat.call("_run_boss_summon_action", boss_actor, CALL_EMBERS_ACTION, ai_state)
	var enemy_count_after: int = (combat.get("enemy_actors") as Array).size()
	_check("summon_added_new_enemy_actor", enemy_count_after > enemy_count_before or enemy_count_after == 5)
	await _capture("06_boss_summon_phase")
	await _end_combat(combat)


## G — Warden counter, the exact call site the M6 finding was in
## (_resolve_warden_counter, combat.gd).
func _scenario_warden_counter() -> void:
	var combat: Control = await _start_synthetic_combat(0, 0, true, BiomeCatalog.ASHEN_WASTES)
	var player_actor: CombatActor = combat.get("player_actor")
	var boss_actor: CombatActor = combat.get("_boss_actor")
	_check("counter_boss_present", boss_actor != null)
	if boss_actor == null:
		await _end_combat(combat)
		return
	var boss_controller: BossEncounterController = combat.get("_boss_controller")
	boss_controller.arm_counter()
	_check("counter_armed", boss_controller.can_counter_basic(boss_actor))
	# _resolve_warden_counter() called directly (not via _run_player_basic_
	# action) so the watch window covers ITS OWN play_hit() call
	# (combat.gd:2109), not the preceding basic-attack animation.
	await _watch_view_routing(combat, player_actor, "counter", func() -> void: combat.call("_resolve_warden_counter", boss_actor))
	await _capture("07_warden_counter")
	await _end_combat(combat)

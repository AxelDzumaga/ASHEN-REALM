extends Node

const COMBAT_SCENE := preload("res://scenes/combat/combat.tscn")
const WARDEN := preload("res://data/enemies/bosses/ashen_warden.tres")
const SUNKEN_PYRE := preload("res://data/enemies/ember_marsh/bosses/sunken_pyre.tres")
const SUPPORT_PROFILE := preload("res://data/enemy_ai_profiles/support_random.tres")
const GUARD_ACTION := preload("res://data/enemy_actions/guard_stance.tres")
const SUMMON_ACTION := preload("res://data/enemy_actions/call_embers.tres")

var failures: Array[String] = []


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"enemy_intent_runtime")
	# El profile aislado arranca sin tutoriales completados (a diferencia del
	# profile real, donde ya estaban todos vistos) — sin esto, el overlay de
	# tutorial de combate bloquea el avance headless esperando un dismiss que
	# nunca llega. Mismo patrón que map3d_defeat_flow_test.gd.
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	_run_planner_contract_tests()
	await _run_combat_integration_test()
	if DebugConfig.get_visual_slice_mode() == &"elite":
		await _run_elite_integration_test()
	if DebugConfig.get_visual_slice_mode() == &"boss":
		await _run_boss_integration_test()
		await _run_summon_integration_test()
	print("[INTENT_TEST] failures=%s" % JSON.stringify(failures))
	get_tree().quit(1 if not failures.is_empty() else 0)


func _run_planner_contract_tests() -> void:
	var player: CombatActor = CombatActor.new(&"player", "Wanderer", CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER, 100, 100, 20, 5)
	var companion: CombatActor = CombatActor.new(&"companion", "Ember Hound", CombatActor.Team.PLAYER, CombatActor.ActorType.COMPANION, 48, 48, 9, 3)
	companion.formation_slot = 1
	var enemy_data: EnemyData = preload("res://data/enemies/ember_acolyte.tres")
	var enemy: CombatActor = CombatActor.from_enemy(&"enemy_test", enemy_data, CombatActor.ActorType.NORMAL_ENEMY)
	var state: EnemyAIRuntimeState = EnemyAIRuntimeState.new()
	var targets: Array[CombatActor] = [player, companion]
	var player_only: Array[CombatActor] = []
	player_only.append(player)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 610061
	var cooldowns_before: Dictionary = state.action_cooldowns.duplicate(true)
	var turn_before: int = state.turn_count
	var intent: EnemyIntent = EnemyIntentPlanner.plan(enemy, SUPPORT_PROFILE, state, targets, rng, 1)
	_check(intent != null, "intent generated")
	_check(state.action_cooldowns == cooldowns_before and state.turn_count == turn_before, "planning does not consume cooldown or turn")
	var rng_state_after_plan: int = rng.state
	var resolved: CombatActor = intent.resolve_execution_target(targets)
	_check(rng.state == rng_state_after_plan, "execution target resolution consumes no RNG")
	_check(resolved == intent.target_actor, "stable planned target")
	_check(intent.action_id == intent.action.action_id, "stored action identity")

	var repeated_action: EnemyActionData = intent.action
	state.record_action(repeated_action)
	_check(state.last_action_id == repeated_action.action_id, "execution records planned action")
	_check(state.turn_count == 1, "turn consumed only on execution")

	var random_action: EnemyActionData = EnemyActionData.new()
	random_action.action_id = &"random_test"
	random_action.action_type = EnemyAIEnums.ActionType.ATTACK
	random_action.override_target_policy = true
	random_action.target_policy = EnemyAIEnums.TargetPolicy.RANDOM_ALIVE
	var random_profile: EnemyAIData = EnemyAIData.new()
	random_profile.ai_id = &"random_test"
	random_profile.actions = [random_action]
	var random_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	random_rng.seed = 7
	var random_player: CombatActor = CombatActor.new(&"random_player", "Wanderer", CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER, 100, 100, 20, 5)
	var random_companion: CombatActor = CombatActor.new(&"random_companion", "Hound", CombatActor.Team.PLAYER, CombatActor.ActorType.COMPANION, 48, 48, 9, 3)
	var random_targets: Array[CombatActor] = [random_player, random_companion]
	var random_intent: EnemyIntent = EnemyIntentPlanner.plan(enemy, random_profile, EnemyAIRuntimeState.new(), random_targets, random_rng, 2)
	var original_random_target: CombatActor = random_intent.target_actor
	original_random_target.set_current_hp(0)
	var fallback_targets: Array[CombatActor] = []
	fallback_targets.append(random_companion if original_random_target == random_player else random_player)
	var fallback_rng_state: int = random_rng.state
	_check(random_intent.resolve_execution_target(fallback_targets) == fallback_targets[0], "dead random target uses deterministic fallback")
	_check(random_rng.state == fallback_rng_state, "retarget consumes no RNG")

	var preferred_action: EnemyActionData = EnemyActionData.new()
	preferred_action.action_id = &"companion_hunt"
	preferred_action.override_target_policy = true
	preferred_action.target_policy = EnemyAIEnums.TargetPolicy.COMPANION_PREFERRED
	var preferred_profile: EnemyAIData = EnemyAIData.new()
	preferred_profile.actions = [preferred_action]
	var fresh_companion: CombatActor = CombatActor.new(&"companion_2", "Ember Hound", CombatActor.Team.PLAYER, CombatActor.ActorType.COMPANION, 48, 48, 9, 3)
	var companion_targets: Array[CombatActor] = [player, fresh_companion]
	var preferred_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	preferred_rng.seed = 9
	var preferred_intent: EnemyIntent = EnemyIntentPlanner.plan(enemy, preferred_profile, EnemyAIRuntimeState.new(), companion_targets, preferred_rng, 3)
	_check(preferred_intent.target_actor == fresh_companion, "companion preferred target planned")
	fresh_companion.set_current_hp(0)
	_check(preferred_intent.resolve_execution_target(player_only) == player, "dead companion retargets player")

	var guard_profile: EnemyAIData = EnemyAIData.new()
	guard_profile.role = EnemyAIEnums.Role.DEFENDER
	guard_profile.actions = [GUARD_ACTION]
	var guard_state: EnemyAIRuntimeState = EnemyAIRuntimeState.new()
	guard_state.activate_guard_stance(3)
	var guard_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	guard_rng.seed = 11
	var guard_intent: EnemyIntent = EnemyIntentPlanner.plan(enemy, guard_profile, guard_state, player_only, guard_rng, 4)
	_check(guard_intent != null and guard_intent.category == EnemyIntent.Category.DEFEND, "defend intent category")
	_check(guard_state.guard_stance_active, "planning preserves active guard stance")
	_check(guard_state.action_cooldowns.is_empty(), "defend planning does not start cooldown")
	guard_state.record_action(guard_intent.action)
	_check(int(guard_state.action_cooldowns.get(GUARD_ACTION.action_id, 0)) == GUARD_ACTION.cooldown, "cooldown starts on execution")

	var status_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	status_rng.seed = 13
	var status_action: EnemyActionData = preload("res://data/enemy_actions/weakening_blow.tres")
	var status_profile: EnemyAIData = EnemyAIData.new()
	status_profile.role = EnemyAIEnums.Role.SUPPORT
	status_profile.actions = [status_action]
	var status_intent: EnemyIntent = EnemyIntentPlanner.plan(enemy, status_profile, EnemyAIRuntimeState.new(), player_only, status_rng, 5)
	_check(status_intent != null and status_intent.category == EnemyIntent.Category.STATUS, "status intent category")
	_check(status_intent.status_effect == &"weaken" and status_intent.status_stacks == 1, "status intent exposes effect")
	enemy.set_current_hp(0)
	_check(not status_intent.can_execute(), "dead source cannot execute intent")

	_run_boss_and_summon_tests(player)


func _run_boss_and_summon_tests(player: CombatActor) -> void:
	var player_only: Array[CombatActor] = []
	player_only.append(player)
	var warden: CombatActor = CombatActor.from_enemy(&"warden", WARDEN, CombatActor.ActorType.BOSS)
	var warden_controller: BossEncounterController = BossEncounterController.new(WARDEN.boss_encounter, warden)
	warden.set_current_hp(roundi(float(warden.get_max_hp()) * 0.65))
	var transition: BossEncounterController.TransitionResult = warden_controller.check_phase_transition()
	_check(transition != null and warden_controller.runtime.current_phase_index == 1, "boss phase transition detected")
	var warden_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	warden_rng.seed = 17
	var warden_intent: EnemyIntent = EnemyIntentPlanner.plan(
		warden, warden_controller.get_active_ai_profile(WARDEN.ai_profile), EnemyAIRuntimeState.new(), player_only, warden_rng, 6,
	)
	_check(warden_intent != null and warden_intent.source_actor == warden, "boss intent uses active phase profile")

	var pyre: CombatActor = CombatActor.from_enemy(&"pyre", SUNKEN_PYRE, CombatActor.ActorType.BOSS)
	var pyre_controller: BossEncounterController = BossEncounterController.new(SUNKEN_PYRE.boss_encounter, pyre)
	pyre.set_current_hp(roundi(float(pyre.get_max_hp()) * 0.65))
	var summon_transition: BossEncounterController.TransitionResult = pyre_controller.check_phase_transition()
	_check(summon_transition != null and pyre_controller.get_pending_summon_count() == 2, "summon reserved by phase without execution")
	var summon_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	summon_rng.seed = 19
	var summon_intent: EnemyIntent = EnemyIntentPlanner.plan(
		pyre,
		pyre_controller.get_active_ai_profile(SUNKEN_PYRE.ai_profile),
		EnemyAIRuntimeState.new(),
		player_only,
		summon_rng,
		7,
		pyre_controller.get_forced_action(pyre),
	)
	_check(summon_intent != null and summon_intent.category == EnemyIntent.Category.SUMMON, "summon intent planned")
	_check(pyre_controller.get_pending_summon_count() == 2 and not pyre_controller.runtime.summon_completed, "planning does not consume summon")
	_check(summon_intent.action == SUMMON_ACTION, "summon execution stores canonical action")


func _run_combat_integration_test() -> void:
	RunManager.start_new_run(610061)
	RunManager.current_run.biome_data = BiomeCatalog.ASHEN_WASTES
	RunManager.current_run.biome_id = BiomeCatalog.ASHEN_WASTES.id
	RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	RunManager.current_run.equipped_companion_id = CompanionCatalog.EMBER_HOUND_ID
	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(BiomeCatalog.ASHEN_WASTES, false, false)
	add_child(combat)
	var frames: int = 0
	while int(combat.get("_phase")) != 1 and frames < 600:
		await get_tree().process_frame
		frames += 1
	var intents: Dictionary = combat.get("_enemy_intents")
	var enemies: Array = combat.get("enemy_actors")
	_check(intents.size() == enemies.size() and intents.size() > 0, "first player turn has intent for every enemy")
	var planned_actions: Dictionary[StringName, StringName] = {}
	var planned_ids: Dictionary[StringName, StringName] = {}
	for actor: CombatActor in enemies:
		var planned: EnemyIntent = intents.get(actor.actor_id) as EnemyIntent
		if planned != null:
			planned_actions[actor.actor_id] = planned.action_id
			planned_ids[actor.actor_id] = planned.plan_id
	combat.call("_on_attack_pressed")
	frames = 0
	while int(combat.get("_phase")) != 1 and not bool(combat.get("_result_resolved")) and frames < 1200:
		await get_tree().process_frame
		frames += 1
	if not bool(combat.get("_result_resolved")):
		var states: Dictionary = combat.get("_enemy_ai_states")
		for actor: CombatActor in combat.get("enemy_actors"):
			var state: EnemyAIRuntimeState = states.get(actor.actor_id) as EnemyAIRuntimeState
			if planned_actions.has(actor.actor_id) and state != null and state.turn_count > 0:
				_check(state.last_action_id == planned_actions[actor.actor_id], "execution matches plan %s" % actor.actor_id)
		var next_intents: Dictionary = combat.get("_enemy_intents")
		_check(not next_intents.is_empty(), "next player turn receives new intents")
		for actor_id: StringName in planned_ids:
			var next_intent: EnemyIntent = next_intents.get(actor_id) as EnemyIntent
			if next_intent != null:
				_check(next_intent.plan_id != planned_ids[actor_id], "next intent has new plan id %s" % actor_id)
		if enemies.size() > 1:
			var defeated_before_turn: CombatActor = enemies[enemies.size() - 1] as CombatActor
			defeated_before_turn.set_current_hp(0)
			await combat.call("_present_enemy_death", defeated_before_turn)
			_check(not (combat.get("_enemy_intents") as Dictionary).has(defeated_before_turn.actor_id), "enemy death removes pending intent")
	combat.queue_free()
	await get_tree().process_frame
	RunManager.end_run()


func _run_boss_integration_test() -> void:
	RunManager.start_new_run(610062)
	RunManager.current_run.biome_data = BiomeCatalog.ASHEN_WASTES
	RunManager.current_run.biome_id = BiomeCatalog.ASHEN_WASTES.id
	RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(BiomeCatalog.ASHEN_WASTES, true, false)
	add_child(combat)
	await _wait_for_player_input(combat)
	var boss: CombatActor = combat.get("_boss_actor") as CombatActor
	var before: EnemyIntent = (combat.get("_enemy_intents") as Dictionary).get(boss.actor_id) as EnemyIntent
	_check(before != null, "boss has first-turn intent")
	boss.set_current_hp(roundi(float(boss.get_max_hp()) * 0.65))
	await combat.call("_check_boss_phase_transition")
	var after: EnemyIntent = (combat.get("_enemy_intents") as Dictionary).get(boss.actor_id) as EnemyIntent
	_check(after != null and after.plan_id != before.plan_id, "phase transition invalidates old boss intent")
	var boss_controller: BossEncounterController = combat.get("_boss_controller") as BossEncounterController
	_check(boss_controller.runtime.current_phase_index == 1, "runtime boss uses new phase")
	combat.queue_free()
	await get_tree().process_frame
	RunManager.end_run()


func _run_elite_integration_test() -> void:
	RunManager.start_new_run(610064)
	RunManager.current_run.biome_data = BiomeCatalog.ASHEN_WASTES
	RunManager.current_run.biome_id = BiomeCatalog.ASHEN_WASTES.id
	RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(BiomeCatalog.ASHEN_WASTES, false, true)
	add_child(combat)
	await _wait_for_player_input(combat)
	var enemies: Array = combat.get("enemy_actors")
	var intents: Dictionary = combat.get("_enemy_intents") as Dictionary
	_check(enemies.size() == 1 and intents.size() == 1, "elite receives first-turn intent")
	combat.call("_on_attack_pressed")
	await _wait_for_player_input(combat, 1200)
	var state: EnemyAIRuntimeState = (combat.get("_enemy_ai_states") as Dictionary).get((enemies[0] as CombatActor).actor_id) as EnemyAIRuntimeState
	_check(state != null and state.turn_count == 1, "elite executes planned turn")
	combat.queue_free()
	await get_tree().process_frame
	RunManager.end_run()


func _run_summon_integration_test() -> void:
	RunManager.start_new_run(610063)
	RunManager.current_run.biome_data = BiomeCatalog.EMBER_MARSH
	RunManager.current_run.biome_id = BiomeCatalog.EMBER_MARSH.id
	RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(BiomeCatalog.EMBER_MARSH, true, false)
	add_child(combat)
	await _wait_for_player_input(combat)
	var boss: CombatActor = combat.get("_boss_actor") as CombatActor
	boss.set_current_hp(roundi(float(boss.get_max_hp()) * 0.65))
	await combat.call("_check_boss_phase_transition")
	var summon_intent: EnemyIntent = (combat.get("_enemy_intents") as Dictionary).get(boss.actor_id) as EnemyIntent
	_check(summon_intent != null and summon_intent.category == EnemyIntent.Category.SUMMON, "phase creates real summon intent")
	combat.call("_on_attack_pressed")
	await _wait_for_player_input(combat, 1600)
	var enemies: Array = combat.get("enemy_actors")
	var intents: Dictionary = combat.get("_enemy_intents") as Dictionary
	_check(enemies.size() == 3, "summon creates two minions")
	_check(intents.size() == 3, "summoned enemies receive intents next player turn")
	var states: Dictionary = combat.get("_enemy_ai_states") as Dictionary
	var minions_waited: bool = true
	for actor: CombatActor in enemies:
		if actor.actor_type == CombatActor.ActorType.MINION:
			var state: EnemyAIRuntimeState = states.get(actor.actor_id) as EnemyAIRuntimeState
			minions_waited = minions_waited and state != null and state.turn_count == 0
	_check(minions_waited, "summons do not attack on creation round")
	combat.queue_free()
	await get_tree().process_frame
	RunManager.end_run()


func _wait_for_player_input(combat: Control, maximum_frames: int = 800) -> void:
	var frames: int = 0
	while int(combat.get("_phase")) != 1 and not bool(combat.get("_result_resolved")) and frames < maximum_frames:
		await get_tree().process_frame
		frames += 1
	_check(int(combat.get("_phase")) == 1 or bool(combat.get("_result_resolved")), "combat reaches player input")


func _check(condition: bool, label: String) -> void:
	print("[INTENT_TEST] %s=%s" % [label, condition])
	if not condition:
		failures.append(label)

extends Node

const TEST_SAVE := "user://stage72_systems/profile.json"
const REPORT_PATH := "res://build/stage72/stage72_systems_runtime.json"

## Fase 2 elemental — contenido piloto Ash/Miasma, ver _test_elemental_phase2_content().
const ASH_CRAWLER: EnemyData = preload("res://data/enemies/ash_crawler.tres")
const MIRE_SEER: EnemyData = preload("res://data/enemies/ember_marsh/mire_seer.tres")
const CINDER_CURSE: EnemyActionData = preload("res://data/enemy_actions/cinder_curse.tres")
const MIRE_DECAY_ACTION: EnemyActionData = preload("res://data/enemy_actions/mire_decay.tres")
const ASHEN_WARDEN_ENCOUNTER: BossEncounterData = preload("res://data/boss_encounters/ashen_warden.tres")

var _checks: Dictionary = {}
var _failures: Array[String] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_SAVE.get_base_dir()))
	SaveManager.save_path = TEST_SAVE
	_cleanup()
	_test_level_and_xp()
	_test_migration_and_save()
	_test_run_xp_deposit()
	await _test_equipment_requirements()
	_test_appearance_hooks()
	_test_affinities()
	_test_elemental_reactions()
	_test_elemental_phase2_content()
	_test_spawn_architecture()
	await _test_ui_contracts()
	_write_report()
	_cleanup()
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_level_and_xp() -> void:
	var fresh := ProfileData.new()
	_check("new_profile_level_1_xp_0", fresh.player_level == 1 and fresh.player_xp == 0)
	_check("xp_gain_without_level", fresh.add_player_xp(90) == 0 and fresh.player_level == 1 and fresh.player_xp == 90)
	_check("xp_overflow", fresh.add_player_xp(20) == 1 and fresh.player_level == 2 and fresh.player_xp == 10)
	var multi := ProfileData.new()
	var amount: int = PlayerProgressionConfig.xp_required_for_level(1) + PlayerProgressionConfig.xp_required_for_level(2) + 7
	_check("xp_multi_level", multi.add_player_xp(amount) == 2 and multi.player_level == 3 and multi.player_xp == 7)
	var invalid := ProfileData.from_dictionary({"player_level": -99, "player_xp": -5})
	_check("invalid_progress_sanitized", invalid.player_level == 1 and invalid.player_xp == 0)
	_check("curve_increases", PlayerProgressionConfig.xp_required_for_level(4) > PlayerProgressionConfig.xp_required_for_level(3))


func _test_migration_and_save() -> void:
	var legacy := {
		"save_version": 10,
		"total_ash": 321,
		"permanent_attack_level": 2,
		"completed_milestone_ids": ["first_expedition"],
		"owned_equipment": {"wardens_edge": 1},
		"equipped_weapon_id": "wardens_edge",
	}
	_write_json(TEST_SAVE, legacy)
	_check("v10_loads", SaveManager.load_profile())
	_check("v10_defaults_level", SaveManager.profile.player_level == 1 and SaveManager.profile.player_xp == 0)
	_check("v10_preserves_data", SaveManager.profile.total_ash == 321 and SaveManager.profile.permanent_attack_level == 2 and "first_expedition" in SaveManager.profile.completed_milestone_ids)
	_check("legacy_equipment_preserved", SaveManager.profile.equipped_weapon_id == "wardens_edge")
	var migrated: Dictionary = _read_json(TEST_SAVE)
	_check("migration_writes_current", int(migrated.get("save_version", 0)) == SaveManager.SAVE_VERSION)
	SaveManager.profile.add_player_xp(37)
	_check("current_save", SaveManager.save_profile())
	SaveManager.profile = ProfileData.new()
	_check("current_load", SaveManager.load_profile() and SaveManager.profile.player_xp == 37)


func _test_equipment_requirements() -> void:
	var high_item: EquipmentData = EquipmentCatalog.WARDENS_EDGE
	SaveManager.profile.player_level = 1
	SaveManager.profile.owned_equipment[String(high_item.id)] = 1
	_check("equipment_insufficient_domain", not SaveManager.can_equip_item(high_item) and not SaveManager.equip_item(String(high_item.id)))
	_check("blocked_item_remains_owned", int(SaveManager.profile.owned_equipment.get(String(high_item.id), 0)) == 1)
	SaveManager.profile.player_level = high_item.required_level
	_check("equipment_sufficient_domain", SaveManager.can_equip_item(high_item) and SaveManager.equip_item(String(high_item.id)))
	_check("equipment_save_load", SaveManager.load_profile() and SaveManager.profile.equipped_weapon_id == String(high_item.id))
	SaveManager.profile.player_level = 1
	_check("legacy_equipped_stays_active", SaveManager.profile.equipped_weapon_id == String(high_item.id) and not SaveManager.can_equip_item(high_item))


func _test_run_xp_deposit() -> void:
	SaveManager.profile = ProfileData.new()
	var run := RunState.new()
	run.record_normal_combat_victory()
	run.record_elite_combat_victory()
	var expected: int = PlayerProgressionConfig.RUN_FINISH_XP + PlayerProgressionConfig.NORMAL_COMBAT_XP + PlayerProgressionConfig.ELITE_COMBAT_XP
	_check("run_xp_source_calculation", PlayerProgressionConfig.calculate_run_xp(run) == expected)
	_check("run_xp_deposit", SaveManager.deposit_run(run) and run.player_xp_earned == expected)
	var xp_after: int = SaveManager.profile.player_xp
	_check("run_xp_no_duplicate_deposit", not SaveManager.deposit_run(run) and SaveManager.profile.player_xp == xp_after)


func _test_appearance_hooks() -> void:
	_check("visual_catalog_complete", EquipmentVisualCatalog.validate_catalog().is_empty())
	var item: EquipmentData = EquipmentCatalog.ASHEN_BLADE
	_check("equipped_visual_selection", EquipmentVisualCatalog.get_for_item(item) != null)
	var invalid := EquipmentData.new()
	invalid.slot = EquipmentData.Slot.WEAPON
	invalid.visual_id = &"missing_visual"
	_check("missing_visual_fallback", EquipmentVisualCatalog.get_for_item(invalid) == null and EquipmentVisualCatalog.get_visual_label(invalid) == "SIN CAPA VISUAL")
	_check("unequip_visual_reset", EquipmentVisualCatalog.get_for_item(null) == null)


func _test_affinities() -> void:
	var none: Array[StringName] = []
	var ember: Array[StringName] = [&"ember"]
	_check("affinity_normal_unchanged", int(AffinityResolver.resolve_damage_preview(100, &"physical", none, none, none)["damage"]) == 100)
	_check("affinity_resistance_path", int(AffinityResolver.resolve_damage_preview(100, &"ember", ember, none, none)["damage"]) == 75)
	_check("affinity_weakness_path", int(AffinityResolver.resolve_damage_preview(100, &"ember", none, ember, none)["damage"]) == 125)
	_check("affinity_immunity_path", int(AffinityResolver.resolve_damage_preview(100, &"ember", none, none, ember)["damage"]) == 0)
	var interaction: Dictionary = AffinityResolver.preview_status_interaction(&"burn", [&"wet"])
	_check("wet_burn_demo", interaction["rule_id"] == &"wet_reduces_burn_duration" and int(interaction["duration_delta"]) == -1)
	_check("affinity_deterministic", AffinityResolver.resolve_damage_preview(37, &"ember", ember, none, none) == AffinityResolver.resolve_damage_preview(37, &"ember", ember, none, none))


## Cierre de Fase 1 (2026-09-03): reacciones Wet+Frost/Wet+Storm y los
## statuses nuevos DECAY/CURSE. Todo testeable sin escena de Combat — son
## CombatActor + CombatStatusController en aislamiento (RefCounted puro).
func _test_elemental_reactions() -> void:
	var statuses := CombatStatusController.new()

	var dry_target: CombatActor = _new_test_actor(&"dry")
	statuses.apply_status(dry_target, &"chilled", null, 1)
	_check("chilled_no_wet_base_stacks", dry_target.get_status(&"chilled").stacks == 1)

	var wet_target: CombatActor = _new_test_actor(&"wet_target")
	statuses.apply_status(wet_target, &"wet", null, 1)
	statuses.apply_status(wet_target, &"chilled", null, 1)
	_check("chilled_wet_bonus_stacks", wet_target.get_status(&"chilled").stacks == 2)

	var wet_source: CombatActor = _new_test_actor(&"wet_source")
	var chain_target: CombatActor = _new_test_actor(&"chain_target")
	statuses.apply_status(wet_source, &"wet", null, 1)
	statuses.apply_status(wet_source, &"shock", null, 1, -1, [chain_target])
	_check("shock_chains_from_wet_target", wet_source.has_status(&"shock") and chain_target.has_status(&"shock"))

	var dry_source: CombatActor = _new_test_actor(&"dry_source")
	var no_chain_target: CombatActor = _new_test_actor(&"no_chain_target")
	statuses.apply_status(dry_source, &"shock", null, 1, -1, [no_chain_target])
	_check("shock_no_chain_without_wet", dry_source.has_status(&"shock") and not no_chain_target.has_status(&"shock"))

	var already_shocked: CombatActor = _new_test_actor(&"already_shocked")
	statuses.apply_status(already_shocked, &"shock", null, 1)
	var next_candidate: CombatActor = _new_test_actor(&"next_candidate")
	var wet_source_2: CombatActor = _new_test_actor(&"wet_source_2")
	statuses.apply_status(wet_source_2, &"wet", null, 1)
	statuses.apply_status(wet_source_2, &"shock", null, 1, -1, [already_shocked, next_candidate])
	_check("shock_chain_skips_already_shocked", next_candidate.has_status(&"shock"))

	var decaying: CombatActor = _new_test_actor(&"decaying")
	statuses.apply_status(decaying, &"decay", null, 1)
	var before_tick: int = decaying.get_current_hp()
	statuses.process_turn_start(decaying)
	_check("decay_dot_ticks", decaying.get_current_hp() == before_tick - int(StatusEffectCatalog.DECAY.magnitude_per_stack))
	_check("decay_reduces_healing", CombatStatusController.get_effective_healing(decaying, 100) == 85)
	var undecayed: CombatActor = _new_test_actor(&"undecayed")
	_check("no_decay_full_healing", CombatStatusController.get_effective_healing(undecayed, 100) == 100)

	var cursed: CombatActor = _new_test_actor(&"cursed")
	statuses.apply_status(cursed, &"curse", null, 1)
	_check("curse_increases_damage", statuses.get_effective_incoming_damage(cursed, 100) == 115)
	_check("curse_immune_stays_zero", statuses.get_effective_incoming_damage(cursed, 0) == 0)
	var uncursed: CombatActor = _new_test_actor(&"uncursed")
	_check("no_curse_unchanged_damage", statuses.get_effective_incoming_damage(uncursed, 100) == 100)


func _new_test_actor(id: StringName) -> CombatActor:
	return CombatActor.new(id, String(id), CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY, 50, 50, 10, 2)


## Fase 2 elemental (2026-09-03): contenido piloto Ash/Curse (Ashen Wastes) y
## Miasma/Decay (Ember Marsh) — enemy tags, acción nueva por élite, fase de
## boss. Todo data-driven sobre el mismo mecanismo genérico de Fase 1, sin
## escena de Combat (AffinityResolver/CombatStatusController/BossEncounterController
## son RefCounted puros).
func _test_elemental_phase2_content() -> void:
	# Ash_crawler: sigue resistiendo Ember (identidad de bioma sin tocar) y
	# ahora es débil a Ash (tag nuevo, Pass Criteria punto 1).
	_check("ash_crawler_weak_to_ash", int(AffinityResolver.resolve_damage_preview(100, &"ash", ASH_CRAWLER.resistance_tags, ASH_CRAWLER.weakness_tags, ASH_CRAWLER.immunity_tags)["damage"]) == 125)
	_check("ash_crawler_still_resists_ember", int(AffinityResolver.resolve_damage_preview(100, &"ember", ASH_CRAWLER.resistance_tags, ASH_CRAWLER.weakness_tags, ASH_CRAWLER.immunity_tags)["damage"]) == 75)
	# Mire_seer: sigue resistiendo Tide y ahora es débil a Miasma.
	_check("mire_seer_weak_to_miasma", int(AffinityResolver.resolve_damage_preview(100, &"miasma", MIRE_SEER.resistance_tags, MIRE_SEER.weakness_tags, MIRE_SEER.immunity_tags)["damage"]) == 125)
	_check("mire_seer_still_resists_tide", int(AffinityResolver.resolve_damage_preview(100, &"tide", MIRE_SEER.resistance_tags, MIRE_SEER.weakness_tags, MIRE_SEER.immunity_tags)["damage"]) == 75)

	# Acción nueva del élite de Ashen Wastes: aplica CURSE, y CURSE aumenta el
	# daño recibido vía el multiplicador ya existente (get_effective_incoming_damage).
	var statuses := CombatStatusController.new()
	var cursed_target: CombatActor = _new_test_actor(&"cinder_curse_target")
	statuses.apply_status(cursed_target, CINDER_CURSE.status_id, null, CINDER_CURSE.status_stacks, CINDER_CURSE.status_duration)
	_check("cinder_curse_applies_curse_status", cursed_target.has_status(&"curse"))
	_check("cinder_curse_increases_damage_one_stack", statuses.get_effective_incoming_damage(cursed_target, 100) == 115)
	# "Creciente si no se interrumpe": reaplicar suma stacks, con cap (Pass Criteria: reportar cap si existe).
	statuses.apply_status(cursed_target, CINDER_CURSE.status_id, null, CINDER_CURSE.status_stacks, CINDER_CURSE.status_duration)
	statuses.apply_status(cursed_target, CINDER_CURSE.status_id, null, CINDER_CURSE.status_stacks, CINDER_CURSE.status_duration)
	statuses.apply_status(cursed_target, CINDER_CURSE.status_id, null, CINDER_CURSE.status_stacks, CINDER_CURSE.status_duration)
	_check("cinder_curse_stacks_cap_at_3", cursed_target.get_status(&"curse").stacks == 3)
	_check("cinder_curse_damage_capped_at_3_stacks", statuses.get_effective_incoming_damage(cursed_target, 100) == 145)

	# Acción nueva del élite de Ember Marsh: aplica DECAY, y DECAY reduce
	# curación recibida sin llevarla a negativo (get_effective_healing).
	var decaying_target: CombatActor = _new_test_actor(&"mire_decay_target")
	statuses.apply_status(decaying_target, MIRE_DECAY_ACTION.status_id, null, MIRE_DECAY_ACTION.status_stacks, MIRE_DECAY_ACTION.status_duration)
	_check("mire_decay_applies_decay_status", decaying_target.has_status(&"decay"))
	_check("mire_decay_reduces_healing_one_stack", CombatStatusController.get_effective_healing(decaying_target, 100) == 85)
	_check("mire_decay_small_heal_not_negative", CombatStatusController.get_effective_healing(decaying_target, 5) == 4)
	statuses.apply_status(decaying_target, MIRE_DECAY_ACTION.status_id, null, MIRE_DECAY_ACTION.status_stacks, MIRE_DECAY_ACTION.status_duration)
	statuses.apply_status(decaying_target, MIRE_DECAY_ACTION.status_id, null, MIRE_DECAY_ACTION.status_stacks, MIRE_DECAY_ACTION.status_duration)
	_check("mire_decay_stacks_cap_at_3", decaying_target.get_status(&"decay").stacks == 3)
	_check("mire_decay_capped_healing_not_negative", CombatStatusController.get_effective_healing(decaying_target, 100) == 55)

	# Fase de Curse de Ashen Warden: se activa exactamente en el threshold
	# correcto (35% HP, warden_phase_3 "ashen_judgment"), una sola vez.
	var boss_actor := CombatActor.new(&"ashen_warden_test", "Ashen Warden", CombatActor.Team.ENEMY, CombatActor.ActorType.BOSS, 145, 145, 15, 11)
	var boss_controller := BossEncounterController.new(ASHEN_WARDEN_ENCOUNTER, boss_actor)
	boss_actor.set_current_hp(52) # 35.9% > 35% — todavía no debe cruzar a la fase 3.
	boss_controller.check_phase_transition()
	_check("ashen_warden_phase3_not_yet_above_threshold", boss_controller.get_current_phase().phase_id != &"ashen_judgment")
	boss_actor.set_current_hp(50) # 34.5% <= 35% — cruza a "ashen_judgment".
	var transition := boss_controller.check_phase_transition()
	_check("ashen_warden_phase3_triggers_at_threshold", boss_controller.get_current_phase().phase_id == &"ashen_judgment")
	_check("ashen_warden_phase3_transition_result_not_null", transition != null)
	var active_actions: Array[EnemyActionData] = boss_controller.get_active_ai_profile(null).actions
	var has_curse_action: bool = false
	for action: EnemyActionData in active_actions:
		if action != null and action.action_id == &"ashen_judgment_curse":
			has_curse_action = true
	_check("ashen_warden_phase3_profile_has_curse_action", has_curse_action)
	var repeat_transition := boss_controller.check_phase_transition()
	_check("ashen_warden_phase3_no_duplicate_transition", repeat_transition == null)


func _test_spawn_architecture() -> void:
	var native_enemy := EnemyData.new()
	native_enemy.id = &"native_test"
	var global_enemy := EnemyData.new()
	global_enemy.id = &"global_test"
	var locked_enemy := EnemyData.new()
	locked_enemy.id = &"locked_test"
	var native_entry := EnemySpawnEntryData.new()
	native_entry.enemy = native_enemy
	native_entry.category = EnemySpawnEntryData.Category.NATIVE
	native_entry.weight = 10
	native_entry.native_biomes = [&"test_biome"]
	var global_entry := EnemySpawnEntryData.new()
	global_entry.enemy = global_enemy
	global_entry.category = EnemySpawnEntryData.Category.COMMON_GLOBAL
	global_entry.weight = 10
	var locked_entry := EnemySpawnEntryData.new()
	locked_entry.enemy = locked_enemy
	locked_entry.category = EnemySpawnEntryData.Category.BIOME_LOCKED
	locked_entry.native_biomes = [&"other_biome"]
	var biome := BiomeData.new()
	biome.id = &"test_biome"
	biome.normal_spawn_entries = [native_entry, global_entry, locked_entry]
	var pool: Array[EnemyData] = EnemySpawnResolver.get_pool(biome)
	_check("spawn_global_cross_biome", global_enemy in pool)
	_check("spawn_locked_stays_locked", locked_enemy not in pool)
	_check("spawn_no_empty_pool", not pool.is_empty())
	_check("spawn_deterministic_seed", EnemySpawnResolver.pick_enemy(biome, 72) == EnemySpawnResolver.pick_enemy(biome, 72))
	var native_count: int = 0
	var global_count: int = 0
	for seed: int in range(1000, 2000):
		var picked: EnemyData = EnemySpawnResolver.pick_enemy(biome, seed)
		native_count += 1 if picked == native_enemy else 0
		global_count += 1 if picked == global_enemy else 0
	_check("spawn_native_more_common", native_count > global_count)
	_check("legacy_spawn_fallback", EnemySpawnResolver.get_pool(BiomeCatalog.ASHEN_WASTES) == BiomeCatalog.ASHEN_WASTES.normal_enemy_pool)


func _test_ui_contracts() -> void:
	SaveManager.profile.player_level = 1
	SaveManager.profile.player_xp = 25
	SaveManager.profile.owned_equipment = {"wardens_edge": 1}
	SaveManager.profile.equipped_weapon_id = ""
	var equipment_screen: Control = preload("res://scenes/lobby/equipment.tscn").instantiate()
	add_child(equipment_screen)
	await get_tree().process_frame
	var blocked_found: bool = false
	for button: Button in _find_buttons(equipment_screen):
		if "NIV 9" in button.text:
			blocked_found = button.disabled
	_check("equipment_ui_disabled", blocked_found)
	equipment_screen.queue_free()
	await get_tree().process_frame
	var lobby: Control = preload("res://scenes/lobby/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().process_frame
	var level_label: Label = lobby.get_node("%PlayerLevelLabel")
	var xp_bar: ProgressBar = lobby.get_node("%PlayerXpBar")
	_check("refuge_level_xp_visible", "NIV 1" in level_label.text and int(xp_bar.value) == 25)
	lobby.queue_free()
	await get_tree().process_frame
	var results: Control = preload("res://scenes/results/run_result.tscn").instantiate()
	_check("results_xp_contract", results.get_node("%PlayerXpLabel") != null and results.get_node("%PlayerXpBar") != null)
	results.free()


func _find_buttons(root: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child: Node in root.find_children("*", "Button", true, false):
		result.append(child as Button)
	return result


func _check(id: String, condition: bool) -> void:
	_checks[id] = condition
	if not condition:
		_failures.append(id)


func _write_report() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_PATH.get_base_dir()))
	_write_json(REPORT_PATH, {
		"schema": 1,
		"checks": _checks,
		"failures": _failures,
		"passed": _failures.is_empty(),
		"save_version": SaveManager.SAVE_VERSION,
		"debug_tools_enabled": DebugConfig.DEBUG_TOOLS_ENABLED,
		"personal_profile_touched": false,
	})
	print("STAGE72_SYSTEMS %d/%d" % [_checks.size() - _failures.size(), _checks.size()])


func _write_json(path: String, value: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "  "))
	file.close()


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text()) if file != null else {}
	if file != null:
		file.close()
	return data if typeof(data) == TYPE_DICTIONARY else {}


func _cleanup() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = TEST_SAVE + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

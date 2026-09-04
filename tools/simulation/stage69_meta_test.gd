extends Node

const TEST_SAVE := "user://stage69_meta_test/profile.json"

var _checks: Dictionary = {}
var _failures: Array[String] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_SAVE.get_base_dir()))
	SaveManager.save_path = TEST_SAVE
	_cleanup_test_files()
	_test_new_and_v9_profiles()
	_test_purchases_and_selection()
	_test_duplicate_sink()
	_test_save_roundtrip()
	_test_run_application_and_affinity()
	await _test_results_display()
	var report := {
		"schema": 1,
		"checks": _checks,
		"failures": _failures,
		"save_version": SaveManager.SAVE_VERSION,
		"real_profile_touched": false,
	}
	var output_path := "res://build/stage69/meta_tests.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path.get_base_dir()))
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	_cleanup_test_files()
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_new_and_v9_profiles() -> void:
	var fresh := ProfileData.new()
	_check("new_profile", fresh.owned_meta_unlock_ids.is_empty() and fresh.selected_starting_option_id.is_empty())
	var legacy := ProfileData.from_dictionary({
		"total_ash": 137,
		"permanent_health_level": 3,
		"permanent_attack_level": 2,
		"permanent_defense_level": 1,
		"owned_equipment": {"ember_fang": 2},
		"equipped_weapon_id": "ember_fang",
		"completed_milestone_ids": ["first_expedition"],
	})
	_check("existing_profile_defaults", legacy.owned_meta_unlock_ids.is_empty() and legacy.selected_starting_option_id.is_empty())
	_check("migration_preserves_inventory", int(legacy.owned_equipment.get("ember_fang", 0)) == 2 and legacy.equipped_weapon_id == "ember_fang")
	_check("migration_preserves_ash_and_power", legacy.total_ash == 137 and legacy.permanent_health_level == 3 and legacy.permanent_attack_level == 2 and legacy.permanent_defense_level == 1)


func _test_purchases_and_selection() -> void:
	SaveManager.profile = ProfileData.new()
	SaveManager.profile.total_ash = 300
	_check("purchase_power_upgrade", SaveManager.try_purchase_upgrade(PermanentUpgradeConfig.UpgradeType.VITALITY) and SaveManager.profile.permanent_health_level == 1)
	var ash_after_power: int = SaveManager.profile.total_ash
	_check("purchase_unlock", SaveManager.try_purchase_meta_unlock(MetaUnlockCatalog.EMBER_FOCUS) and SaveManager.profile.total_ash == ash_after_power - 45)
	_check("already_owned", not SaveManager.try_purchase_meta_unlock(MetaUnlockCatalog.EMBER_FOCUS))
	_check("unlock_condition", not SaveManager.try_purchase_meta_unlock(MetaUnlockCatalog.VIGIL_FOCUS))
	SaveManager.profile.completed_milestone_ids.append("first_expedition")
	_check("milestone_unlock", SaveManager.try_purchase_meta_unlock(MetaUnlockCatalog.VIGIL_FOCUS))
	_check("selected_option", SaveManager.select_starting_option(MetaUnlockCatalog.EMBER_FOCUS) and SaveManager.profile.selected_starting_option_id == MetaUnlockCatalog.EMBER_FOCUS)
	_check("invalid_selection_fallback", not SaveManager.select_starting_option(&"missing") and SaveManager.profile.selected_starting_option_id == MetaUnlockCatalog.EMBER_FOCUS)
	var ash_before_insufficient: int = SaveManager.profile.total_ash
	SaveManager.profile.total_ash = 0
	SaveManager.profile.completed_milestone_ids.append("first_victory")
	_check("insufficient_ash", not SaveManager.try_purchase_meta_unlock(MetaUnlockCatalog.RENEWAL_FOCUS))
	SaveManager.profile.total_ash = ash_before_insufficient


func _test_duplicate_sink() -> void:
	SaveManager.profile = ProfileData.new()
	SaveManager.profile.owned_equipment["ashen_blade"] = 1
	var run := RunState.new()
	var before: int = SaveManager.profile.total_ash
	SaveManager._grant_or_salvage_equipment("ashen_blade", run)
	_check("duplicate", run.duplicate_converted_id == &"ashen_blade")
	_check("duplicate_sink", run.duplicate_ash_awarded == 10 and SaveManager.profile.total_ash == before + 10 and int(SaveManager.profile.owned_equipment["ashen_blade"]) == 1)
	SaveManager.profile.owned_equipment["ashen_blade"] = 3
	var salvage: int = SaveManager.salvage_equipment_duplicates("ashen_blade")
	_check("legacy_duplicate_salvage", salvage == 20 and int(SaveManager.profile.owned_equipment["ashen_blade"]) == 1)


func _test_save_roundtrip() -> void:
	SaveManager.profile.total_ash = 321
	SaveManager.profile.permanent_attack_level = 2
	SaveManager.profile.owned_meta_unlock_ids = [MetaUnlockCatalog.EMBER_FOCUS]
	SaveManager.profile.selected_starting_option_id = MetaUnlockCatalog.EMBER_FOCUS
	SaveManager.profile.owned_equipment["ember_fang"] = 1
	var saved: bool = SaveManager.save_profile()
	SaveManager.profile = ProfileData.new()
	var loaded: bool = SaveManager.load_profile()
	_check("save_load", saved and loaded and SaveManager.profile.selected_starting_option_id == MetaUnlockCatalog.EMBER_FOCUS)
	_check("no_ash_loss", SaveManager.profile.total_ash == 321)
	_check("no_inventory_loss", int(SaveManager.profile.owned_equipment.get("ember_fang", 0)) == 1)


func _test_run_application_and_affinity() -> void:
	var run: RunState = RunManager.start_new_run(690069)
	_check("run_selected_option", run.starting_option_id == MetaUnlockCatalog.EMBER_FOCUS)
	RunManager.end_run()
	var default_offense: int = 0
	var focused_offense: int = 0
	for index: int in range(300):
		var neutral := RunState.new()
		var focused := RunState.new()
		focused.starting_option_id = MetaUnlockCatalog.EMBER_FOCUS
		for boon: UpgradeData in BuildRewardResolver.generate_boon_options(neutral, false, 690000 + index * 97):
			default_offense += 1 if boon.affinity == UpgradeData.Affinity.OFFENSE else 0
		for boon: UpgradeData in BuildRewardResolver.generate_boon_options(focused, false, 690000 + index * 97):
			focused_offense += 1 if boon.affinity == UpgradeData.Affinity.OFFENSE else 0
	_check("horizontal_affinity_changes_options", focused_offense > default_offense)


func _test_results_display() -> void:
	var run := RunState.new()
	run.biome_data = BiomeCatalog.get_or_default(&"ashen_wastes")
	run.biome_id = run.biome_data.id
	run.board_tile_sequence = [BoardTileData.TileType.EMPTY, BoardTileData.TileType.BOSS]
	run.pending_loot_id = "ashen_blade"
	run.loot_rolled = true
	run.rewards_deposited = true
	run.duplicate_converted_id = &"ashen_blade"
	run.duplicate_ash_awarded = 10
	run.starting_option_id = MetaUnlockCatalog.EMBER_FOCUS
	RunManager.current_run = run
	var screen: Control = preload("res://scenes/results/run_result.tscn").instantiate()
	screen.configure(false)
	add_child(screen)
	await get_tree().process_frame
	var loot_label: Label = screen.get_node("%LootNameLabel")
	var summary: Label = screen.get_node("%SummaryLabel")
	_check("results_display", "DUPLICADO RECICLADO" in loot_label.text and "Senda de Brasa" in summary.tooltip_text)
	screen.queue_free()
	RunManager.current_run = null


func _check(name: String, condition: bool) -> void:
	_checks[name] = condition
	if not condition:
		_failures.append(name)


func _cleanup_test_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = TEST_SAVE + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

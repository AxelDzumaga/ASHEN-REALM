extends Node

const TEST_SAVE := "user://stage78_economy/profile.json"
const REPORT_PATH := "res://build/stage78/stage78_economy_runtime.json"

var checks: Dictionary = {}
var failures: Array[String] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_SAVE.get_base_dir()))
	SaveManager.save_path = TEST_SAVE
	_cleanup()
	_test_fresh_and_migration()
	_test_chests()
	_test_boss_deposit()
	_test_shop()
	_test_refinement()
	await _test_ui()
	_write_report()
	_cleanup()
	get_tree().quit(0 if failures.is_empty() else 1)


func _test_fresh_and_migration() -> void:
	var fresh := ProfileData.new()
	_check("fresh_economy_zero", fresh.guardian_sigils == 0 and fresh.forge_shards == 0 and fresh.equipment_refinement.is_empty())
	var legacy := {"save_version": 11, "total_ash": 321, "player_level": 6, "player_xp": 17, "owned_equipment": {"wardens_edge": 1}, "equipped_weapon_id": "wardens_edge", "completed_milestone_ids": ["first_expedition"]}
	_write_json(TEST_SAVE, legacy)
	_check("v11_load", SaveManager.load_profile())
	_check("v11_preserves_profile", SaveManager.profile.total_ash == 321 and SaveManager.profile.player_level == 6 and SaveManager.profile.equipped_weapon_id == "wardens_edge")
	_check("v11_economy_defaults", SaveManager.profile.guardian_sigils == 0 and SaveManager.profile.forge_shards == 0 and SaveManager.profile.equipment_refinement.is_empty())
	_check("migration_writes_current_version", int(_read_json(TEST_SAVE).get("save_version", 0)) == SaveManager.SAVE_VERSION)


func _test_chests() -> void:
	var profile := ProfileData.new()
	var chest := ChestCatalog.get_by_id(ChestCatalog.WARDEN_RELIQUARY)
	var first: Dictionary = ChestResolver.resolve(chest, profile, 7801)
	var second: Dictionary = ChestResolver.resolve(chest, profile, 7801)
	_check("chest_deterministic", first == second)
	_check("chest_minimum_rewards", first.get("items", []).size() >= chest.min_rewards)
	var floor_ok := true
	for equipment_id: String in first.get("items", []):
		floor_ok = floor_ok and EquipmentCatalog.get_by_id(equipment_id).rarity >= EquipmentData.Rarity.RARE
	_check("boss_chest_rarity_floor", floor_ok)
	profile.chest_pity[String(chest.pity_key)] = chest.epic_pity_limit - 1
	var pity: Dictionary = ChestResolver.resolve(chest, profile, 99)
	_check("epic_pity", bool(pity.get("pity_triggered", false)) and bool(pity.get("contains_epic", false)) and int(pity.get("pity_after", -1)) == 0)


func _test_boss_deposit() -> void:
	SaveManager.profile = ProfileData.new()
	var run := RunState.new()
	run.biome_data = BiomeCatalog.ASHEN_WASTES
	run.record_boss_victory()
	run.loot_rolled = true
	_check("boss_deposit", SaveManager.deposit_run(run))
	var encounter: BossEncounterData = run.biome_data.boss.boss_encounter
	_check("boss_chest_awarded", run.boss_chest_awarded and int(SaveManager.profile.unopened_chests.get(String(encounter.boss_chest_id), 0)) == 1)
	_check("boss_sigils_awarded", SaveManager.profile.guardian_sigils == encounter.guardian_sigils_reward)
	var sigils_after: int = SaveManager.profile.guardian_sigils
	_check("boss_deposit_idempotent", not SaveManager.deposit_run(run) and SaveManager.profile.guardian_sigils == sigils_after and int(SaveManager.profile.unopened_chests.get(String(encounter.boss_chest_id), 0)) == 1)
	var opened: Dictionary = SaveManager.open_chest(encounter.boss_chest_id, 7802)
	_check("chest_open_atomic", not opened.is_empty() and int(SaveManager.profile.unopened_chests.get(String(encounter.boss_chest_id), 0)) == 0)
	_check("chest_cannot_reopen", SaveManager.open_chest(encounter.boss_chest_id, 7802).is_empty())
	_check("chest_rewards_owned", int(SaveManager.profile.owned_equipment.get(String(opened["items"][0]), 0)) >= 1)
	_check("chest_reopen_blocked_after_load", SaveManager.load_profile() and SaveManager.open_chest(encounter.boss_chest_id, 7802).is_empty())


func _test_shop() -> void:
	SaveManager.profile = ProfileData.new()
	SaveManager.profile.player_level = 10
	SaveManager.profile.total_ash = 2000
	_check("shop_purchase", SaveManager.purchase_shop_offer(&"rare_chest"))
	_check("shop_reward_and_price", int(SaveManager.profile.unopened_chests.get(String(ChestCatalog.RARE_RELIQUARY), 0)) == 1 and SaveManager.profile.total_ash == 1780)
	_check("shop_stock_double_buy_guard", not SaveManager.purchase_shop_offer(&"rare_chest") and SaveManager.profile.total_ash == 1780)
	_check("shop_stock_persists", SaveManager.load_profile() and not SaveManager.purchase_shop_offer(&"rare_chest"))
	_check("shop_invalid_offer", not SaveManager.purchase_shop_offer(&"invalid"))
	SaveManager.profile.total_ash = 0
	_check("shop_insufficient", not SaveManager.purchase_shop_offer(&"ash_cache"))
	SaveManager.profile.boss_defeat_counts["ashen_warden"] = 1
	SaveManager.profile.guardian_sigils = 8
	_check("shop_boss_currency", SaveManager.purchase_shop_offer(&"warden_chest") and SaveManager.profile.guardian_sigils == 0)
	SaveManager.profile.player_level = 1
	_check("shop_required_level", ShopCatalog.get_by_id(&"warden_edge_direct", SaveManager.profile) == null)


func _test_refinement() -> void:
	SaveManager.profile = ProfileData.new()
	SaveManager.profile.owned_equipment["ashen_blade"] = 2
	SaveManager.profile.total_ash = 1_000_000
	SaveManager.profile.forge_shards = 1000
	SaveManager.profile.guardian_sigils = 1000
	SaveManager.profile.biome_materials[String(BiomeCatalog.DEFAULT_BIOME_ID)] = 1000
	var first_cost: Dictionary = RefinementConfig.get_cost(EquipmentCatalog.ASHEN_BLADE, 0)
	_check("refinement_cost_valid", int(first_cost.get("ash", 0)) > 0 and int(first_cost.get("forge_shards", -1)) == 0)
	_check("refinement_plus_one", SaveManager.refine_equipment("ashen_blade") and int(SaveManager.profile.equipment_refinement.get("ashen_blade", 0)) == 1)
	for index: int in range(1, RefinementConfig.MAX_REFINEMENT):
		SaveManager.refine_equipment("ashen_blade")
	_check("refinement_max", int(SaveManager.profile.equipment_refinement.get("ashen_blade", 0)) == RefinementConfig.MAX_REFINEMENT and not SaveManager.refine_equipment("ashen_blade"))
	_check("refinement_never_destroys", int(SaveManager.profile.owned_equipment.get("ashen_blade", 0)) == 2)
	var refinement_before: int = int(SaveManager.profile.equipment_refinement["ashen_blade"])
	_check("salvage_duplicate_preserves_investment", SaveManager.salvage_equipment_duplicates("ashen_blade") > 0 and int(SaveManager.profile.owned_equipment["ashen_blade"]) == 1 and int(SaveManager.profile.equipment_refinement["ashen_blade"]) == refinement_before)
	_check("refinement_save_load", SaveManager.load_profile() and int(SaveManager.profile.equipment_refinement.get("ashen_blade", 0)) == RefinementConfig.MAX_REFINEMENT)
	SaveManager.profile.total_ash = 0
	SaveManager.profile.owned_equipment["cinder_knife"] = 1
	_check("refinement_insufficient", not SaveManager.refine_equipment("cinder_knife"))


func _test_ui() -> void:
	var shop := preload("res://scenes/lobby/shop.tscn").instantiate()
	add_child(shop)
	await get_tree().process_frame
	_check("shop_ui_loads", shop.find_children("*", "Button", true, false).size() >= 2)
	_check("shop_touch_targets", _buttons_touch_safe(shop))
	shop.queue_free()
	await get_tree().process_frame
	var forge := preload("res://scenes/lobby/refinement.tscn").instantiate()
	add_child(forge)
	await get_tree().process_frame
	_check("refinement_ui_loads", forge.find_children("*", "Button", true, false).size() >= 2)
	_check("refinement_touch_targets", _buttons_touch_safe(forge))
	forge.queue_free()
	await get_tree().process_frame
	var lobby := preload("res://scenes/lobby/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().process_frame
	_check("refuge_economy_touch_targets", (lobby.get_node("%ShopButton") as Button).custom_minimum_size.y >= 48.0 and (lobby.get_node("%RefinementButton") as Button).custom_minimum_size.y >= 48.0)
	_check("refuge_economy_access", lobby.get_node_or_null("%ShopButton") is Button and lobby.get_node_or_null("%RefinementButton") is Button)
	lobby.queue_free()
	await get_tree().process_frame


func _buttons_touch_safe(root: Node) -> bool:
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.custom_minimum_size.y < 48.0 and button.size.y < 48.0:
			return false
	return true


func _check(id: String, passed: bool) -> void:
	checks[id] = passed
	if not passed:
		failures.append(id)


func _write_report() -> void:
	_write_json(REPORT_PATH, {"schema": 1, "checks": checks, "failures": failures, "passed": failures.is_empty(), "save_version": SaveManager.SAVE_VERSION, "debug_tools_enabled": DebugConfig.DEBUG_TOOLS_ENABLED, "personal_profile_touched": false})
	print("STAGE78_ECONOMY %d/%d" % [checks.size() - failures.size(), checks.size()])


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

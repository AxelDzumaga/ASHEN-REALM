extends Node

## Equipment 2.0 Fase 1 — domain + integration + migration tests. Perfil
## aislado (SaveManager.use_isolated_test_profile), nunca toca el perfil
## real. Ver PHASE 7 del prompt de la feature.

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"equipment2_phase1")
	_test_slot_enum_ordinals()
	_test_five_slot_stat_aggregation()
	_test_set_bonus_two_piece()
	_test_visual_fallback()
	_test_equip_five_slots()
	_test_shop_rotation_new_slots()
	_test_refinement_slot_agnostic()
	_test_salvage_slot_agnostic()
	_test_favorite_toggle()
	_test_migration_armor_to_chest()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print("EQUIPMENT2_PHASE1 " + JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _test_slot_enum_ordinals() -> void:
	# CHEST debe conservar el ordinal 1 que tenía ARMOR — así los .tres
	# existentes con slot=1 siguen resolviendo a CHEST sin tocarlos.
	_check("weapon_ordinal_0", int(EquipmentData.Slot.WEAPON) == 0)
	_check("chest_ordinal_1", int(EquipmentData.Slot.CHEST) == 1)
	_check("head_ordinal_2", int(EquipmentData.Slot.HEAD) == 2)
	_check("cape_ordinal_3", int(EquipmentData.Slot.CAPE) == 3)
	_check("relic_ordinal_4", int(EquipmentData.Slot.RELIC) == 4)
	_check("legacy_armor_tres_resolves_chest", EquipmentCatalog.WARDEN_PLATE.slot == EquipmentData.Slot.CHEST)


func _test_five_slot_stat_aggregation() -> void:
	SaveManager.profile = ProfileData.new()
	SaveManager.profile.owned_equipment = {
		"ashen_blade": 1, "warden_plate": 1, "weathered_hood": 1,
		"frayed_cloak": 1, "dull_amulet": 1,
	}
	SaveManager.profile.player_level = 20
	SaveManager.profile.equipped_weapon_id = "ashen_blade"
	SaveManager.profile.equipped_armor_id = "warden_plate"
	SaveManager.profile.equipped_slots = {
		"head": "weathered_hood", "cape": "frayed_cloak", "relic": "dull_amulet",
	}
	var run := RunState.new()
	run.apply_permanent_upgrades(SaveManager.profile)
	var expected_defense: int = RunState.BASE_DEFENSE + EquipmentCatalog.WARDEN_PLATE.defense_bonus + EquipmentCatalog.WEATHERED_HOOD.defense_bonus
	var expected_health: int = RunState.BASE_MAX_HEALTH + EquipmentCatalog.WARDEN_PLATE.max_health_bonus + EquipmentCatalog.WEATHERED_HOOD.max_health_bonus + EquipmentCatalog.FRAYED_CLOAK.max_health_bonus
	var expected_attack: int = RunState.BASE_ATTACK + EquipmentCatalog.ASHEN_BLADE.attack_bonus
	_check("aggregate_defense_5_slots", run.defense == expected_defense)
	_check("aggregate_health_5_slots", run.max_health == expected_health)
	_check("aggregate_attack_5_slots", run.attack == expected_attack)
	_check("aggregate_crit_from_relic", run.equipment_crit_chance == EquipmentCatalog.DULL_AMULET.crit_chance)


func _test_set_bonus_two_piece() -> void:
	SaveManager.profile = ProfileData.new()
	SaveManager.profile.owned_equipment = {"wardens_edge": 1, "warden_plate": 1}
	SaveManager.profile.player_level = 20
	SaveManager.profile.equipped_weapon_id = "wardens_edge"
	SaveManager.profile.equipped_armor_id = "warden_plate"
	var run_with_set := RunState.new()
	run_with_set.apply_permanent_upgrades(SaveManager.profile)
	_check("set_bonus_active_with_2_pieces", run_with_set.has_equipment_passive(&"warden_set_resonance"))

	SaveManager.profile.owned_equipment = {"wardens_edge": 1}
	SaveManager.profile.equipped_armor_id = ""
	var run_without_set := RunState.new()
	run_without_set.apply_permanent_upgrades(SaveManager.profile)
	_check("set_bonus_inactive_with_1_piece", not run_without_set.has_equipment_passive(&"warden_set_resonance"))
	_check("set_size_ashen_warden_is_2", EquipmentCatalog.get_set_size(&"ashen_warden_set") == 2)


func _test_visual_fallback() -> void:
	var invalid := EquipmentData.new()
	invalid.visual_id = &"does_not_exist_anywhere"
	invalid.slot = EquipmentData.Slot.CHEST
	_check("visual_fallback_null_no_crash", EquipmentVisualCatalog.get_for_item(invalid) == null)
	_check("visual_catalog_no_gaps_for_visual_slots", EquipmentVisualCatalog.validate_catalog().is_empty())
	_check("relic_exempt_from_visual_requirement", not EquipmentData.slot_is_visual(EquipmentData.Slot.RELIC))


func _test_equip_five_slots() -> void:
	SaveManager.profile = ProfileData.new()
	SaveManager.profile.player_level = 20
	SaveManager.profile.owned_equipment = {
		"ashen_blade": 1, "ashen_vestment": 1, "weathered_hood": 1,
		"frayed_cloak": 1, "dull_amulet": 1,
	}
	_check("equip_weapon", SaveManager.equip_item("ashen_blade"))
	_check("equip_chest", SaveManager.equip_item("ashen_vestment"))
	_check("equip_head", SaveManager.equip_item("weathered_hood"))
	_check("equip_cape", SaveManager.equip_item("frayed_cloak"))
	_check("equip_relic", SaveManager.equip_item("dull_amulet"))
	_check("all_5_slots_equipped_simultaneously", (
		SaveManager.profile.equipped_weapon_id == "ashen_blade"
		and SaveManager.profile.equipped_armor_id == "ashen_vestment"
		and SaveManager.get_equipped_id_for_slot(EquipmentData.Slot.HEAD) == "weathered_hood"
		and SaveManager.get_equipped_id_for_slot(EquipmentData.Slot.CAPE) == "frayed_cloak"
		and SaveManager.get_equipped_id_for_slot(EquipmentData.Slot.RELIC) == "dull_amulet"
	))


func _test_shop_rotation_new_slots() -> void:
	SaveManager.profile = ProfileData.new()
	SaveManager.profile.player_level = 20
	SaveManager.profile.total_runs = 0
	var offers: Array[ShopOfferData] = ShopCatalog.get_available(SaveManager.profile)
	var groups: Array[StringName] = []
	for offer: ShopOfferData in offers:
		groups.append(offer.offer_id)
	_check("shop_offers_head", &"rotating_head" in groups)
	_check("shop_offers_cape", &"rotating_cape" in groups)
	_check("shop_offers_relic", &"rotating_relic" in groups)
	var head_offer: ShopOfferData = ShopCatalog.get_by_id(&"rotating_head", SaveManager.profile)
	_check("shop_head_offer_resolves_item", head_offer != null and not String(head_offer.reward_id).is_empty())


func _test_refinement_slot_agnostic() -> void:
	SaveManager.profile = ProfileData.new()
	SaveManager.profile.owned_equipment = {"weathered_hood": 1}
	SaveManager.profile.total_ash = 1_000_000
	SaveManager.profile.forge_shards = 1000
	SaveManager.profile.guardian_sigils = 1000
	_check("refine_head_slot_works", SaveManager.refine_equipment("weathered_hood") and int(SaveManager.profile.equipment_refinement.get("weathered_hood", 0)) == 1)


func _test_salvage_slot_agnostic() -> void:
	SaveManager.profile = ProfileData.new()
	SaveManager.profile.owned_equipment = {"frayed_cloak": 3}
	var before: int = SaveManager.profile.total_ash
	var salvaged: int = SaveManager.salvage_equipment_duplicates("frayed_cloak")
	_check("salvage_cape_slot_works", salvaged > 0 and SaveManager.profile.total_ash > before and int(SaveManager.profile.owned_equipment["frayed_cloak"]) == 1)


func _test_favorite_toggle() -> void:
	SaveManager.profile = ProfileData.new()
	SaveManager.profile.owned_equipment = {"dull_amulet": 1}
	_check("favorite_starts_false", not SaveManager.is_equipment_favorite("dull_amulet"))
	SaveManager.toggle_equipment_favorite("dull_amulet")
	_check("favorite_toggled_true", SaveManager.is_equipment_favorite("dull_amulet"))
	SaveManager.toggle_equipment_favorite("dull_amulet")
	_check("favorite_toggled_back_false", not SaveManager.is_equipment_favorite("dull_amulet"))


## El caso central de PASS CRITERIA: un perfil v13 (pre-Equipment 2.0) con
## ARMOR equipado/inventariado debe terminar como CHEST con refinement,
## rareza, locked y equipado intactos — sin reconstruir nada a mano. Pasa
## por SaveManager.load_profile() real (no solo ProfileData.from_dictionary)
## para ejercitar también _sanitize_equipment()/_sanitize_equipped_slots().
func _test_migration_armor_to_chest() -> void:
	var legacy_dict: Dictionary = {
		"save_version": 13,
		"total_ash": 500,
		"owned_equipment": {"warden_plate": 2, "ashen_blade": 1},
		"equipment_refinement": {"warden_plate": 7},
		"locked_equipment_ids": ["warden_plate"],
		"equipped_weapon_id": "ashen_blade",
		"equipped_armor_id": "warden_plate",
	}
	_write_json(SaveManager.save_path, legacy_dict)
	_check("legacy_v13_loads", SaveManager.load_profile())
	var migrated: ProfileData = SaveManager.profile
	var warden_plate_item: EquipmentData = EquipmentCatalog.get_by_id("warden_plate")
	_check("migrated_item_resolves_to_chest_slot", warden_plate_item.slot == EquipmentData.Slot.CHEST)
	_check("migrated_owned_quantity_preserved", int(migrated.owned_equipment.get("warden_plate", 0)) == 2)
	_check("migrated_refinement_preserved", int(migrated.equipment_refinement.get("warden_plate", 0)) == 7)
	_check("migrated_locked_preserved", "warden_plate" in migrated.locked_equipment_ids)
	_check("migrated_equipped_field_preserved", migrated.equipped_armor_id == "warden_plate")
	_check("migrated_equipped_resolves_via_catalog_helper", EquipmentCatalog.get_equipped_id_for_slot(migrated, EquipmentData.Slot.CHEST) == "warden_plate")
	_check("migrated_equipped_slots_defaults_empty", migrated.equipped_slots.is_empty())
	_check("migrated_favorite_defaults_empty", migrated.favorite_equipment_ids.is_empty())
	var rewritten: Dictionary = _read_json(SaveManager.save_path)
	_check("migrated_save_rewritten_as_v14", int(rewritten.get("save_version", 0)) == SaveManager.SAVE_VERSION)

	# Malformado: equipped_slots con basura no debe crashear ni filtrarse —
	# clave no-slot, valor no-string, e ítem no poseído se descartan todos.
	var malformed_dict: Dictionary = legacy_dict.duplicate(true)
	malformed_dict["equipped_slots"] = {"head": 12345, "not_a_slot": "weathered_hood", "relic": "dull_amulet", "cape": "not_owned_item"}
	malformed_dict["owned_equipment"] = {"warden_plate": 2, "ashen_blade": 1, "dull_amulet": 1}
	_write_json(SaveManager.save_path, malformed_dict)
	_check("malformed_v13_loads_no_crash", SaveManager.load_profile())
	var malformed_profile: ProfileData = SaveManager.profile
	_check("malformed_valid_slot_entry_kept", malformed_profile.equipped_slots.get("relic", "") == "dull_amulet")
	_check("malformed_bad_key_entries_dropped", not malformed_profile.equipped_slots.has("head") and not malformed_profile.equipped_slots.has("not_a_slot"))
	_check("malformed_unowned_item_dropped", not malformed_profile.equipped_slots.has("cape"))


func _write_json(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data if typeof(json.data) == TYPE_DICTIONARY else {}

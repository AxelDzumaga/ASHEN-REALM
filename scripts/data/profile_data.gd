class_name ProfileData
extends RefCounted

var total_ash: int = 0
var guardian_sigils: int = 0
var forge_shards: int = 0
var player_level: int = PlayerProgressionConfig.START_LEVEL
var player_xp: int = 0
var permanent_health_level: int = 0
var permanent_attack_level: int = 0
var permanent_defense_level: int = 0
var total_runs: int = 0
var total_victories: int = 0
var total_defeats: int = 0
var total_combats_won: int = 0
var total_bosses_defeated: int = 0
var total_companion_runs: int = 0
var boss_defeat_counts: Dictionary = {}
var completed_milestone_ids: Array[String] = []
var pending_milestone_ids: Array[String] = []
var owned_equipment: Dictionary = {}
var equipment_refinement: Dictionary = {}
var biome_materials: Dictionary = {}
## Bloqueo manual contra salvage accidental (Fase 2 de equipamiento). El
## bloqueo automático de piezas de set equipadas NO vive acá — se calcula
## en SaveManager.is_equipment_locked(), no se persiste por separado.
var locked_equipment_ids: Array[String] = []
## Favoritos manuales del jugador (distinto de locked: no bloquea salvage,
## solo prioriza/filtra en Inventory). Equipment 2.0 Fase 1.
var favorite_equipment_ids: Array[String] = []
## Qué ids de equipment ya vio el jugador — falta de presencia acá + poseído
## = "NUEVO". Ver from_dictionary() para el relleno en saves viejos.
var seen_equipment_ids: Array[String] = []
var unopened_chests: Dictionary = {}
var chest_pity: Dictionary = {}
var opened_chest_counts: Dictionary = {}
var shop_purchase_counts: Dictionary = {}
var equipped_weapon_id: String = ""
var equipped_armor_id: String = ""
## Equipment 2.0 Fase 1 — slots nuevos (HEAD, CAPE, RELIC), claves en
## minúscula vía EquipmentData.get_slot_name(slot).to_lower(). WEAPON/CHEST
## siguen viviendo en los campos dedicados de arriba (no se tocan: ~15
## call-sites existentes los leen directamente) — este diccionario es
## deliberadamente el único lugar que Fase 2 necesita tocar para agregar
## SHOULDERS/HANDS/LEGS/FEET/RING_1/RING_2, sin nuevos campos por slot.
var equipped_slots: Dictionary[String, String] = {}
var selected_biome_id: StringName = BiomeCatalog.DEFAULT_BIOME_ID
var selected_active_skill_id: StringName = ActiveSkillCatalog.DEFAULT_SKILL_ID
var unlocked_skill_ids: Array[StringName] = ActiveSkillCatalog.get_default_unlocked_ids()
var equipped_skill_ids: Array[StringName] = ActiveSkillCatalog.get_default_loadout()
var unlocked_companion_ids: Array[StringName] = CompanionCatalog.get_default_unlocked_ids()
var equipped_companion_id: StringName = &""
var discovered_codex_entries: Array[String] = []
var seen_codex_entries: Array[String] = []
var completed_tutorials: Array[String] = []
var owned_meta_unlock_ids: Array[StringName] = []
var selected_starting_option_id: StringName = &""


func to_dictionary() -> Dictionary:
	return {
		"total_ash": total_ash,
		"guardian_sigils": guardian_sigils,
		"forge_shards": forge_shards,
		"player_level": player_level,
		"player_xp": player_xp,
		"permanent_health_level": permanent_health_level,
		"permanent_attack_level": permanent_attack_level,
		"permanent_defense_level": permanent_defense_level,
		"total_runs": total_runs,
		"total_victories": total_victories,
		"total_defeats": total_defeats,
		"total_combats_won": total_combats_won,
		"total_bosses_defeated": total_bosses_defeated,
		"total_companion_runs": total_companion_runs,
		"boss_defeat_counts": boss_defeat_counts.duplicate(),
		"completed_milestone_ids": completed_milestone_ids.duplicate(),
		"pending_milestone_ids": pending_milestone_ids.duplicate(),
		"owned_equipment": owned_equipment.duplicate(),
		"equipment_refinement": equipment_refinement.duplicate(),
		"biome_materials": biome_materials.duplicate(),
		"locked_equipment_ids": locked_equipment_ids.duplicate(),
		"favorite_equipment_ids": favorite_equipment_ids.duplicate(),
		"seen_equipment_ids": seen_equipment_ids.duplicate(),
		"unopened_chests": unopened_chests.duplicate(),
		"chest_pity": chest_pity.duplicate(),
		"opened_chest_counts": opened_chest_counts.duplicate(),
		"shop_purchase_counts": shop_purchase_counts.duplicate(),
		"equipped_weapon_id": equipped_weapon_id,
		"equipped_armor_id": equipped_armor_id,
		"equipped_slots": equipped_slots.duplicate(),
		"selected_biome_id": String(selected_biome_id),
		"selected_active_skill_id": String(selected_active_skill_id),
		"unlocked_skill_ids": _string_names_to_strings(unlocked_skill_ids),
		"equipped_skill_ids": _string_names_to_strings(equipped_skill_ids),
		"unlocked_companion_ids": _string_names_to_strings(unlocked_companion_ids),
		"equipped_companion_id": String(equipped_companion_id),
		"discovered_codex_entries": discovered_codex_entries.duplicate(),
		"seen_codex_entries": seen_codex_entries.duplicate(),
		"completed_tutorials": completed_tutorials.duplicate(),
		"owned_meta_unlock_ids": _string_names_to_strings(owned_meta_unlock_ids),
		"selected_starting_option_id": String(selected_starting_option_id),
	}


static func from_dictionary(data: Dictionary) -> ProfileData:
	var profile := ProfileData.new()
	profile.total_ash = _read_int(data, "total_ash", 0, 0, 2_000_000_000)
	profile.guardian_sigils = _read_int(data, "guardian_sigils", 0, 0, 2_000_000_000)
	profile.forge_shards = _read_int(data, "forge_shards", 0, 0, 2_000_000_000)
	var raw_level: int = _read_int(
		data, "player_level", PlayerProgressionConfig.START_LEVEL,
		PlayerProgressionConfig.START_LEVEL, PlayerProgressionConfig.MAX_LEVEL,
	)
	var raw_xp: int = _read_int(data, "player_xp", 0, 0, 2_000_000_000)
	var progress: Dictionary = PlayerProgressionConfig.sanitize_progress(raw_level, raw_xp)
	profile.player_level = int(progress["level"])
	profile.player_xp = int(progress["xp"])
	profile.permanent_health_level = _read_int(data, "permanent_health_level", 0, 0, 10)
	profile.permanent_attack_level = _read_int(data, "permanent_attack_level", 0, 0, 10)
	profile.permanent_defense_level = _read_int(data, "permanent_defense_level", 0, 0, 10)
	profile.total_runs = _read_int(data, "total_runs", 0, 0, 2_000_000_000)
	profile.total_victories = _read_int(data, "total_victories", 0, 0, profile.total_runs)
	profile.total_defeats = _read_int(
		data, "total_defeats", maxi(0, profile.total_runs - profile.total_victories), 0, profile.total_runs,
	)
	profile.total_combats_won = _read_int(data, "total_combats_won", 0, 0, 2_000_000_000)
	profile.total_bosses_defeated = _read_int(
		data, "total_bosses_defeated", profile.total_victories, 0, profile.total_victories,
	)
	profile.total_companion_runs = _read_int(data, "total_companion_runs", 0, 0, profile.total_runs)
	profile.boss_defeat_counts = _read_counter_dictionary(data, "boss_defeat_counts")
	profile.completed_milestone_ids = _read_string_array(data, "completed_milestone_ids")
	profile.pending_milestone_ids = _read_string_array(data, "pending_milestone_ids")
	profile.owned_equipment = _read_inventory(data)
	profile.equipment_refinement = _read_counter_dictionary(data, "equipment_refinement")
	profile.biome_materials = _read_counter_dictionary(data, "biome_materials")
	profile.locked_equipment_ids = _read_string_array(data, "locked_equipment_ids")
	profile.favorite_equipment_ids = _read_string_array(data, "favorite_equipment_ids")
	if data.has("seen_equipment_ids"):
		profile.seen_equipment_ids = _read_string_array(data, "seen_equipment_ids")
	else:
		# Save de antes de esta feature: todo lo ya poseído se marca "visto"
		# para no barrer el inventario entero con badges NUEVO de golpe.
		var owned_ids: Array[String] = []
		for key: Variant in profile.owned_equipment.keys():
			owned_ids.append(String(key))
		profile.seen_equipment_ids = owned_ids
	profile.unopened_chests = _read_counter_dictionary(data, "unopened_chests")
	profile.chest_pity = _read_counter_dictionary(data, "chest_pity")
	profile.opened_chest_counts = _read_counter_dictionary(data, "opened_chest_counts")
	profile.shop_purchase_counts = _read_counter_dictionary(data, "shop_purchase_counts")
	profile.equipped_weapon_id = _read_string(data, "equipped_weapon_id")
	profile.equipped_armor_id = _read_string(data, "equipped_armor_id")
	profile.equipped_slots = _read_string_dictionary(data, "equipped_slots")
	profile.selected_biome_id = StringName(_read_string(data, "selected_biome_id", String(BiomeCatalog.DEFAULT_BIOME_ID)))
	profile.selected_active_skill_id = StringName(_read_string(data, "selected_active_skill_id", String(ActiveSkillCatalog.DEFAULT_SKILL_ID)))
	profile.unlocked_skill_ids = ActiveSkillCatalog.sanitize_unlocked_ids(_read_string_name_array(data, "unlocked_skill_ids"))
	if data.has("equipped_skill_ids"):
		profile.equipped_skill_ids = ActiveSkillCatalog.sanitize_loadout(
			_read_string_name_array(data, "equipped_skill_ids", true),
			profile.unlocked_skill_ids,
		)
	else:
		profile.equipped_skill_ids = ActiveSkillCatalog.migrate_legacy_loadout(
			profile.selected_active_skill_id,
			profile.unlocked_skill_ids,
		)
	profile.selected_active_skill_id = _first_equipped_skill_id(profile.equipped_skill_ids)
	profile.unlocked_companion_ids = CompanionCatalog.sanitize_unlocked_ids(
		_read_string_name_array(data, "unlocked_companion_ids")
	)
	profile.equipped_companion_id = CompanionCatalog.sanitize_equipped_id(
		StringName(_read_string(data, "equipped_companion_id")),
		profile.unlocked_companion_ids,
	)
	profile.discovered_codex_entries = _read_string_array(data, "discovered_codex_entries")
	profile.seen_codex_entries = _read_string_array(data, "seen_codex_entries")
	profile.completed_tutorials = _read_string_array(data, "completed_tutorials")
	profile.owned_meta_unlock_ids = MetaUnlockCatalog.sanitize_owned_ids(
		_read_string_name_array(data, "owned_meta_unlock_ids")
	)
	profile.selected_starting_option_id = MetaUnlockCatalog.sanitize_selected_id(
		StringName(_read_string(data, "selected_starting_option_id")),
		profile.owned_meta_unlock_ids,
	)
	return profile


func add_player_xp(amount: int) -> int:
	if amount <= 0 or player_level >= PlayerProgressionConfig.MAX_LEVEL:
		return 0
	player_xp += amount
	var previous_level: int = player_level
	var progress: Dictionary = PlayerProgressionConfig.sanitize_progress(player_level, player_xp)
	player_level = int(progress["level"])
	player_xp = int(progress["xp"])
	return player_level - previous_level


func get_player_xp_requirement() -> int:
	return PlayerProgressionConfig.xp_required_for_level(player_level)


static func _read_string_name_array(data: Dictionary, key: String, keep_empty: bool = false) -> Array[StringName]:
	var result: Array[StringName] = []
	var raw: Variant = data.get(key, [])
	if typeof(raw) != TYPE_ARRAY:
		return result
	for value: Variant in raw:
		if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
			var text_value: String = String(value)
			if keep_empty or not text_value.is_empty():
				result.append(StringName(text_value))
	return result


static func _string_names_to_strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result


static func _first_equipped_skill_id(loadout: Array[StringName]) -> StringName:
	for skill_id: StringName in loadout:
		if not skill_id.is_empty():
			return skill_id
	return ActiveSkillCatalog.DEFAULT_SKILL_ID


static func _read_string_array(data: Dictionary, key: String) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = data.get(key, [])
	if typeof(raw) != TYPE_ARRAY:
		return result
	for value: Variant in raw:
		if typeof(value) == TYPE_STRING and not String(value).is_empty():
			result.append(String(value))
	return result


static func _read_inventory(data: Dictionary) -> Dictionary:
	var inventory: Dictionary = {}
	var raw: Variant = data.get("owned_equipment", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return inventory
	for key: Variant in raw:
		if typeof(key) != TYPE_STRING and typeof(key) != TYPE_STRING_NAME:
			continue
		var amount: Variant = raw[key]
		if typeof(amount) != TYPE_INT and typeof(amount) != TYPE_FLOAT:
			continue
		var safe_amount := clampi(int(amount), 0, 2_000_000_000)
		if safe_amount > 0:
			inventory[String(key)] = safe_amount
	return inventory


## Equipment 2.0 Fase 1 — slot_name -> equipment_id, malformado se descarta
## entrada por entrada (nunca crashea ni pierde el resto del save).
static func _read_string_dictionary(data: Dictionary, key: String) -> Dictionary:
	var result: Dictionary[String, String] = {}
	var raw: Variant = data.get(key, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	for raw_key: Variant in raw:
		if typeof(raw_key) != TYPE_STRING and typeof(raw_key) != TYPE_STRING_NAME:
			continue
		var raw_value: Variant = raw[raw_key]
		if typeof(raw_value) != TYPE_STRING and typeof(raw_value) != TYPE_STRING_NAME:
			continue
		if String(raw_value).is_empty():
			continue
		result[String(raw_key)] = String(raw_value)
	return result


static func _read_counter_dictionary(data: Dictionary, key: String) -> Dictionary:
	var result: Dictionary = {}
	var raw: Variant = data.get(key, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	for raw_key: Variant in raw:
		if typeof(raw_key) != TYPE_STRING and typeof(raw_key) != TYPE_STRING_NAME:
			continue
		var raw_value: Variant = raw[raw_key]
		if typeof(raw_value) != TYPE_INT and typeof(raw_value) != TYPE_FLOAT:
			continue
		if typeof(raw_value) == TYPE_FLOAT and (is_nan(raw_value) or is_inf(raw_value)):
			continue
		var value: int = clampi(int(raw_value), 0, 2_000_000_000)
		if value > 0:
			result[String(raw_key)] = value
	return result


static func _read_string(data: Dictionary, key: String, default_value: String = "") -> String:
	var value: Variant = data.get(key, default_value)
	return value if typeof(value) == TYPE_STRING else ""


static func _read_int(data: Dictionary, key: String, default_value: int, minimum: int, maximum: int) -> int:
	if not data.has(key):
		return default_value
	var value: Variant = data[key]
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return default_value
	if typeof(value) == TYPE_FLOAT and (is_nan(value) or is_inf(value)):
		return default_value
	return clampi(int(value), minimum, maximum)

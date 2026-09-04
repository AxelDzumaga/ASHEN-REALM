class_name EquipmentCatalog
extends RefCounted

const ASHEN_BLADE: EquipmentData = preload("res://data/equipment/weapons/ashen_blade.tres")
const EMBER_FANG: EquipmentData = preload("res://data/equipment/weapons/ember_fang.tres")
const WARDENS_EDGE: EquipmentData = preload("res://data/equipment/weapons/wardens_edge.tres")
const CINDER_KNIFE: EquipmentData = preload("res://data/equipment/weapons/cinder_knife.tres")
const RUNIC_EDGE: EquipmentData = preload("res://data/equipment/weapons/runic_edge.tres")
const BLOOD_CLEAVER: EquipmentData = preload("res://data/equipment/weapons/blood_cleaver.tres")
const SUNDER_PIKE: EquipmentData = preload("res://data/equipment/weapons/sunder_pike.tres")
const VIGIL_NEEDLE: EquipmentData = preload("res://data/equipment/weapons/vigil_needle.tres")
## Fase 2 elemental — contenido piloto Ash/Miasma (INITIAL TUNING, sin balance final).
const ASHFALL_REAVER: EquipmentData = preload("res://data/equipment/weapons/ashfall_reaver.tres")
const MIASMA_FANG: EquipmentData = preload("res://data/equipment/weapons/miasma_fang.tres")
const WORN_ASHMAIL: EquipmentData = preload("res://data/equipment/armor/worn_ashmail.tres")
const EMBERGUARD_ARMOR: EquipmentData = preload("res://data/equipment/armor/emberguard_armor.tres")
const WARDEN_PLATE: EquipmentData = preload("res://data/equipment/armor/warden_plate.tres")
const CINDER_CARAPACE: EquipmentData = preload("res://data/equipment/armor/cinder_carapace.tres")
const MIRE_VEST: EquipmentData = preload("res://data/equipment/armor/mire_vest.tres")
const LAST_GUARD: EquipmentData = preload("res://data/equipment/armor/last_guard.tres")
const BLOODWOVEN_MANTLE: EquipmentData = preload("res://data/equipment/armor/bloodwoven_mantle.tres")
const MIREWARD_HARNESS: EquipmentData = preload("res://data/equipment/armor/mireward_harness.tres")

## Equipment 2.0 Fase 1 — contenido piloto de los 4 slots nuevos (CHEST ya
## existía como ARMOR; se agregan piezas nuevas de CHEST también para no
## dejar ese slot con menos variedad que los otros). 12 ítems, 1 por
## rareza/slot. INITIAL TUNING, sin balance final.
const ASHEN_VESTMENT: EquipmentData = preload("res://data/equipment/chest/ashen_vestment.tres")
const TEMPERED_EMBER_MANTLE: EquipmentData = preload("res://data/equipment/chest/tempered_ember_mantle.tres")
const JUDGMENT_CARAPACE: EquipmentData = preload("res://data/equipment/chest/judgment_carapace.tres")
const WEATHERED_HOOD: EquipmentData = preload("res://data/equipment/head/weathered_hood.tres")
const VIGIL_HELM: EquipmentData = preload("res://data/equipment/head/vigil_helm.tres")
const CROWN_OF_ASHES: EquipmentData = preload("res://data/equipment/head/crown_of_ashes.tres")
const FRAYED_CLOAK: EquipmentData = preload("res://data/equipment/cape/frayed_cloak.tres")
const WANDERERS_MANTLE: EquipmentData = preload("res://data/equipment/cape/wanderers_mantle.tres")
const FALLEN_GUARDIANS_SHROUD: EquipmentData = preload("res://data/equipment/cape/fallen_guardians_shroud.tres")
const DULL_AMULET: EquipmentData = preload("res://data/equipment/relic/dull_amulet.tres")
const ASHEN_SEAL: EquipmentData = preload("res://data/equipment/relic/ashen_seal.tres")
const WARDENS_CORE: EquipmentData = preload("res://data/equipment/relic/wardens_core.tres")

const DEFEAT_COMMON_CHANCE: float = 0.30
const DEFEAT_RARE_CHANCE: float = 0.10
const VICTORY_COMMON_CHANCE: float = 0.55
const VICTORY_RARE_CHANCE: float = 0.35

static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func get_all() -> Array[EquipmentData]:
	return [
		ASHEN_BLADE, CINDER_KNIFE, VIGIL_NEEDLE, EMBER_FANG, RUNIC_EDGE, SUNDER_PIKE, WARDENS_EDGE, BLOOD_CLEAVER,
		ASHFALL_REAVER, MIASMA_FANG,
		WORN_ASHMAIL, CINDER_CARAPACE, EMBERGUARD_ARMOR, MIRE_VEST, MIREWARD_HARNESS, WARDEN_PLATE, LAST_GUARD, BLOODWOVEN_MANTLE,
		ASHEN_VESTMENT, TEMPERED_EMBER_MANTLE, JUDGMENT_CARAPACE,
		WEATHERED_HOOD, VIGIL_HELM, CROWN_OF_ASHES,
		FRAYED_CLOAK, WANDERERS_MANTLE, FALLEN_GUARDIANS_SHROUD,
		DULL_AMULET, ASHEN_SEAL, WARDENS_CORE,
	]


static func get_by_id(equipment_id: String) -> EquipmentData:
	for item in get_all():
		if item.id == equipment_id:
			return item
	return null


static func get_item(equipment_id: String) -> EquipmentData:
	return get_by_id(equipment_id)


static func get_for_slot(slot: EquipmentData.Slot) -> Array[EquipmentData]:
	var result: Array[EquipmentData] = []
	for item in get_all():
		if item.slot == slot:
			result.append(item)
	return result


static func get_weapons() -> Array[EquipmentData]:
	return get_for_slot(EquipmentData.Slot.WEAPON)


## Alias retrocompatible: "armor" ahora es el slot CHEST.
static func get_armors() -> Array[EquipmentData]:
	return get_for_slot(EquipmentData.Slot.CHEST)


static func get_chests() -> Array[EquipmentData]:
	return get_for_slot(EquipmentData.Slot.CHEST)


static func get_heads() -> Array[EquipmentData]:
	return get_for_slot(EquipmentData.Slot.HEAD)


static func get_capes() -> Array[EquipmentData]:
	return get_for_slot(EquipmentData.Slot.CAPE)


static func get_relics() -> Array[EquipmentData]:
	return get_for_slot(EquipmentData.Slot.RELIC)


## Equipment 2.0 Fase 1 — cuántos ítems del catálogo pertenecen a este set,
## para el contador "X/Y" del badge de set (Y = tamaño real del set en el
## catálogo, no un total fijo de una fase futura).
static func get_set_size(set_id: StringName) -> int:
	if set_id.is_empty():
		return 0
	var count: int = 0
	for item: EquipmentData in get_all():
		if item.set_id == set_id:
			count += 1
	return count


## Equipment 2.0 Fase 1 — cuántas piezas de este set están equipadas AHORA
## MISMO en profile (0..get_set_size). Recorre los 5 slots activos.
static func get_equipped_set_piece_count(profile: ProfileData, set_id: StringName) -> int:
	if set_id.is_empty():
		return 0
	var count: int = 0
	for slot: EquipmentData.Slot in EquipmentData.get_phase1_slots():
		var equipped_id: String = get_equipped_id_for_slot(profile, slot)
		if equipped_id.is_empty():
			continue
		var equipped_item: EquipmentData = get_by_id(equipped_id)
		if equipped_item != null and equipped_item.set_id == set_id:
			count += 1
	return count


static func get_items_by_rarity(rarity: EquipmentData.Rarity) -> Array[EquipmentData]:
	var result: Array[EquipmentData] = []
	for item: EquipmentData in get_all():
		if item.rarity == rarity:
			result.append(item)
	return result


static func get_items_for_biome(biome_id: StringName) -> Array[EquipmentData]:
	var result: Array[EquipmentData] = []
	for item: EquipmentData in get_all():
		if item.biome_tags.is_empty() or biome_id in item.biome_tags:
			result.append(item)
	return result


static func roll_run_loot(
	is_victory: bool,
	minimum_rarity: EquipmentData.Rarity = EquipmentData.Rarity.COMMON,
	rarity_upgrades: int = 0,
	excluded_ids: Array[String] = [],
	biome_id: StringName = &"",
) -> EquipmentData:
	var rarity: int = EquipmentData.Rarity.COMMON
	var roll: float = _rng.randf()
	if is_victory:
		if roll >= VICTORY_COMMON_CHANCE + VICTORY_RARE_CHANCE:
			rarity = EquipmentData.Rarity.EPIC
		elif roll >= VICTORY_COMMON_CHANCE:
			rarity = EquipmentData.Rarity.RARE
	else:
		if roll >= DEFEAT_COMMON_CHANCE + DEFEAT_RARE_CHANCE:
			return null
		if roll >= DEFEAT_COMMON_CHANCE:
			rarity = EquipmentData.Rarity.RARE

	rarity = maxi(rarity, minimum_rarity)
	rarity = mini(EquipmentData.Rarity.EPIC, rarity + maxi(0, rarity_upgrades))
	var candidates: Array[EquipmentData] = []
	var source_pool: Array[EquipmentData] = get_items_for_biome(biome_id) if not biome_id.is_empty() else get_all()
	for item: EquipmentData in source_pool:
		if item.rarity == rarity:
			candidates.append(item)
	if candidates.is_empty():
		candidates = get_items_by_rarity(rarity)
	var unseen_candidates: Array[EquipmentData] = []
	for item: EquipmentData in candidates:
		if String(item.id) not in excluded_ids:
			unseen_candidates.append(item)
	if not unseen_candidates.is_empty():
		candidates = unseen_candidates
	if candidates.is_empty():
		return null
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


## Equipment 2.0 Fase 1 — resuelve "qué equipment_id está equipado en este
## slot" para cualquier ProfileData (no solo SaveManager.profile). WEAPON y
## CHEST viven en campos dedicados (compat con ~15 call-sites existentes);
## HEAD/CAPE/RELIC (y Fase 2 cuando exista) viven en el diccionario
## genérico equipped_slots. Único lugar que hace esta distinción.
static func get_equipped_id_for_slot(profile: ProfileData, slot: EquipmentData.Slot) -> String:
	match slot:
		EquipmentData.Slot.WEAPON:
			return profile.equipped_weapon_id
		EquipmentData.Slot.CHEST:
			return profile.equipped_armor_id
		_:
			return String(profile.equipped_slots.get(EquipmentData.get_slot_name(slot).to_lower(), ""))


## Equipment 2.0 Fase 1 — nombre en español del slot, único lugar que UI
## debería usar para no repetir el mapeo en cada pantalla.
static func get_slot_label(slot: EquipmentData.Slot) -> String:
	match slot:
		EquipmentData.Slot.WEAPON:
			return "ARMA"
		EquipmentData.Slot.CHEST:
			return "PECHERA"
		EquipmentData.Slot.HEAD:
			return "CABEZA"
		EquipmentData.Slot.CAPE:
			return "CAPA"
		EquipmentData.Slot.RELIC:
			return "RELIQUIA"
		_:
			return "ÍTEM"


static func get_rarity_name(rarity: EquipmentData.Rarity) -> String:
	return ["Común", "Raro", "Épico"][rarity]


static func get_rarity_color(rarity: EquipmentData.Rarity) -> Color:
	return [Color(0.78, 0.76, 0.72), Color(0.32, 0.66, 0.95), Color(0.72, 0.4, 0.95)][rarity]


static func get_duplicate_salvage_ash(item: EquipmentData) -> int:
	if item == null:
		return 0
	return [10, 20, 35][item.rarity]


static func get_stats_text(item: EquipmentData) -> String:
	var parts: Array[String] = []
	if item.attack_bonus > 0:
		parts.append("+%d de Ataque" % item.attack_bonus)
	if item.defense_bonus > 0:
		parts.append("+%d de Defensa" % item.defense_bonus)
	if item.max_health_bonus > 0:
		parts.append("+%d de Vida máxima" % item.max_health_bonus)
	parts.append_array(_get_secondary_parts(item))
	return "  |  ".join(parts)


static func get_secondary_stats_text(item: EquipmentData) -> String:
	return "  |  ".join(_get_secondary_parts(item))


static func _get_secondary_parts(item: EquipmentData) -> Array[String]:
	var parts: Array[String] = []
	if item.crit_chance > 0.0:
		parts.append("Crítico +%d%%" % roundi(item.crit_chance * 100.0))
	if item.crit_damage_bonus > 0.0:
		parts.append("Daño crítico +%d%%" % roundi(item.crit_damage_bonus * 100.0))
	if item.ember_gain_bonus > 0.0:
		parts.append("Brasa +%d%%" % roundi(item.ember_gain_bonus * 100.0))
	if item.healing_power_bonus > 0.0:
		parts.append("Curación +%d%%" % roundi(item.healing_power_bonus * 100.0))
	if item.skill_damage_bonus > 0.0:
		parts.append("Daño de skill +%d%%" % roundi(item.skill_damage_bonus * 100.0))
	return parts


static func get_passive_text(item: EquipmentData) -> String:
	if item == null or item.passive_effect_id.is_empty():
		return ""
	return "%s · %s" % [
		EquipmentEffectResolver.get_passive_name(item.passive_effect_id),
		EquipmentEffectResolver.get_passive_description(item.passive_effect_id),
	]


## Nombre a mostrar del elemento de Fase 1 (ver EquipmentData.element_type).
## Reusa AffinityResolver.get_type_label() — misma fuente de verdad que usan
## los enemigos — sin duplicar la lista de nombres acá.
static func get_element_type_label(item: EquipmentData) -> String:
	return AffinityResolver.get_type_label(item.element_type) if item != null else AffinityResolver.get_type_label(AffinityResolver.PHYSICAL)


static func get_affinity_name(affinity: EquipmentData.Affinity) -> String:
	match affinity:
		EquipmentData.Affinity.ASH:
			return "CENIZA"
		EquipmentData.Affinity.EMBER:
			return "BRASA"
		EquipmentData.Affinity.MIRE:
			return "CIÉNAGA"
		EquipmentData.Affinity.WARDEN:
			return "WARDEN"
		_:
			return "NEUTRAL"

class_name EquipmentVisualCatalog
extends RefCounted

const ASHEN_BLADE: EquipmentVisualData = preload("res://data/equipment_visuals/weapons/ashen_blade_visual.tres")
const CINDER_KNIFE: EquipmentVisualData = preload("res://data/equipment_visuals/weapons/cinder_knife_visual.tres")
const EMBER_FANG: EquipmentVisualData = preload("res://data/equipment_visuals/weapons/ember_fang_visual.tres")
const RUNIC_EDGE: EquipmentVisualData = preload("res://data/equipment_visuals/weapons/runic_edge_visual.tres")
const WARDENS_EDGE: EquipmentVisualData = preload("res://data/equipment_visuals/weapons/wardens_edge_visual.tres")
const BLOOD_CLEAVER: EquipmentVisualData = preload("res://data/equipment_visuals/weapons/blood_cleaver_visual.tres")
const SUNDER_PIKE: EquipmentVisualData = preload("res://data/equipment_visuals/weapons/sunder_pike_visual.tres")
const VIGIL_NEEDLE: EquipmentVisualData = preload("res://data/equipment_visuals/weapons/vigil_needle_visual.tres")
const WORN_ASHMAIL: EquipmentVisualData = preload("res://data/equipment_visuals/armor/worn_ashmail_visual.tres")
const CINDER_CARAPACE: EquipmentVisualData = preload("res://data/equipment_visuals/armor/cinder_carapace_visual.tres")
const EMBERGUARD_ARMOR: EquipmentVisualData = preload("res://data/equipment_visuals/armor/emberguard_armor_visual.tres")
const MIRE_VEST: EquipmentVisualData = preload("res://data/equipment_visuals/armor/mire_vest_visual.tres")
const WARDEN_PLATE: EquipmentVisualData = preload("res://data/equipment_visuals/armor/warden_plate_visual.tres")
const LAST_GUARD: EquipmentVisualData = preload("res://data/equipment_visuals/armor/last_guard_visual.tres")
const BLOODWOVEN_MANTLE: EquipmentVisualData = preload("res://data/equipment_visuals/armor/bloodwoven_mantle_visual.tres")
const MIREWARD_HARNESS: EquipmentVisualData = preload("res://data/equipment_visuals/armor/mireward_harness_visual.tres")
## Fase 2 elemental — reusan silueta procedural existente (BLOOD_CLEAVER/RUNIC_EDGE)
## con acento de color propio, mismo patrón que SUNDER_PIKE/VIGIL_NEEDLE. FINAL ART PENDING.
const ASHFALL_REAVER: EquipmentVisualData = preload("res://data/equipment_visuals/weapons/ashfall_reaver_visual.tres")
const MIASMA_FANG: EquipmentVisualData = preload("res://data/equipment_visuals/weapons/miasma_fang_visual.tres")

## Equipment 2.0 Fase 1 — placeholders del contenido piloto de slots nuevos.
## display_mode=NONE/procedural_style=NONE deliberado: sin arte final, cae
## al fallback de presencia del personaje (mismo mecanismo ya confirmado
## para enemigos sin arte). RELIC no tiene entradas acá — es "no visual"
## por diseño (ver EquipmentData.slot_is_visual). FINAL ART PENDING.
const ASHEN_VESTMENT: EquipmentVisualData = preload("res://data/equipment_visuals/chest/ashen_vestment_visual.tres")
const TEMPERED_EMBER_MANTLE: EquipmentVisualData = preload("res://data/equipment_visuals/chest/tempered_ember_mantle_visual.tres")
const JUDGMENT_CARAPACE: EquipmentVisualData = preload("res://data/equipment_visuals/chest/judgment_carapace_visual.tres")
const WEATHERED_HOOD: EquipmentVisualData = preload("res://data/equipment_visuals/head/weathered_hood_visual.tres")
const VIGIL_HELM: EquipmentVisualData = preload("res://data/equipment_visuals/head/vigil_helm_visual.tres")
const CROWN_OF_ASHES: EquipmentVisualData = preload("res://data/equipment_visuals/head/crown_of_ashes_visual.tres")
const FRAYED_CLOAK: EquipmentVisualData = preload("res://data/equipment_visuals/cape/frayed_cloak_visual.tres")
const WANDERERS_MANTLE: EquipmentVisualData = preload("res://data/equipment_visuals/cape/wanderers_mantle_visual.tres")
const FALLEN_GUARDIANS_SHROUD: EquipmentVisualData = preload("res://data/equipment_visuals/cape/fallen_guardians_shroud_visual.tres")

const ALL: Array[EquipmentVisualData] = [
	ASHEN_BLADE,
	CINDER_KNIFE,
	EMBER_FANG,
	RUNIC_EDGE,
	WARDENS_EDGE,
	BLOOD_CLEAVER,
	SUNDER_PIKE,
	VIGIL_NEEDLE,
	WORN_ASHMAIL,
	CINDER_CARAPACE,
	EMBERGUARD_ARMOR,
	MIRE_VEST,
	WARDEN_PLATE,
	LAST_GUARD,
	BLOODWOVEN_MANTLE,
	MIREWARD_HARNESS,
	ASHFALL_REAVER,
	MIASMA_FANG,
	ASHEN_VESTMENT,
	TEMPERED_EMBER_MANTLE,
	JUDGMENT_CARAPACE,
	WEATHERED_HOOD,
	VIGIL_HELM,
	CROWN_OF_ASHES,
	FRAYED_CLOAK,
	WANDERERS_MANTLE,
	FALLEN_GUARDIANS_SHROUD,
]


static func get_all() -> Array[EquipmentVisualData]:
	return ALL.duplicate()


static func get_by_id(visual_id: StringName) -> EquipmentVisualData:
	if visual_id.is_empty():
		return null
	for visual: EquipmentVisualData in ALL:
		if visual.visual_id == visual_id:
			return visual
	return null


static func get_for_item(item: EquipmentData) -> EquipmentVisualData:
	if item == null:
		return null
	var visual: EquipmentVisualData = get_by_id(item.visual_id)
	if visual == null or visual.slot != item.slot:
		return null
	return visual


static func get_visual_label(item: EquipmentData) -> String:
	var visual: EquipmentVisualData = get_for_item(item)
	return "SIN CAPA VISUAL" if visual == null else visual.display_name.to_upper()


static func validate_catalog() -> Array[String]:
	var errors: Array[String] = []
	var visual_ids: Array[StringName] = []
	for visual: EquipmentVisualData in ALL:
		if visual == null or visual.visual_id.is_empty():
			errors.append("Visual nulo o sin ID")
			continue
		if visual.visual_id in visual_ids:
			errors.append("Visual ID duplicado: %s" % visual.visual_id)
		visual_ids.append(visual.visual_id)
	for item: EquipmentData in EquipmentCatalog.get_all():
		if not EquipmentData.slot_is_visual(item.slot):
			continue
		var resolved: EquipmentVisualData = get_for_item(item)
		if resolved == null:
			errors.append("Visual faltante o incompatible: %s" % item.id)
	return errors

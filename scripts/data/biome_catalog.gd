class_name BiomeCatalog
extends RefCounted

const DEFAULT_BIOME_ID := &"ashen_wastes"
const ASHEN_WASTES: BiomeData = preload("res://data/biomes/ashen_wastes.tres")
const EMBER_MARSH: BiomeData = preload("res://data/biomes/ember_marsh.tres")
const BIOMES: Array[BiomeData] = [ASHEN_WASTES, EMBER_MARSH]


static func get_all() -> Array[BiomeData]:
	var result: Array[BiomeData] = BIOMES.duplicate()
	result.sort_custom(func(a: BiomeData, b: BiomeData) -> bool: return a.progression_order < b.progression_order)
	return result


static func get_by_id(biome_id: StringName) -> BiomeData:
	for biome: BiomeData in BIOMES:
		if biome.id == biome_id:
			return biome
	return null


static func get_or_default(biome_id: StringName) -> BiomeData:
	var biome: BiomeData = get_by_id(biome_id)
	return biome if biome != null else ASHEN_WASTES


static func sanitize_id(biome_id: StringName) -> StringName:
	return biome_id if get_by_id(biome_id) != null else DEFAULT_BIOME_ID


static func is_unlocked(biome: BiomeData, completed_milestone_ids: Array[String]) -> bool:
	return biome != null and (
		biome.required_milestone_id.is_empty()
		or String(biome.required_milestone_id) in completed_milestone_ids
	)


static func get_available_or_default(biome_id: StringName, completed_milestone_ids: Array[String]) -> BiomeData:
	var biome: BiomeData = get_by_id(biome_id)
	if is_unlocked(biome, completed_milestone_ids):
		return biome
	return ASHEN_WASTES

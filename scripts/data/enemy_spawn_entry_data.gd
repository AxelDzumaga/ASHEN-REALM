class_name EnemySpawnEntryData
extends Resource

enum Category { NATIVE, COMMON_GLOBAL, ROAMING, RARE, BIOME_LOCKED }

@export var enemy: EnemyData
@export var category: Category = Category.NATIVE
@export_range(1, 100, 1) var weight: int = 10
@export var native_biomes: Array[StringName] = []
@export var possible_biomes: Array[StringName] = []
@export var blocked_biomes: Array[StringName] = []


func is_allowed_in(biome_id: StringName) -> bool:
	if enemy == null or biome_id in blocked_biomes:
		return false
	if category == Category.BIOME_LOCKED:
		return biome_id in native_biomes
	if category == Category.COMMON_GLOBAL:
		return true
	return biome_id in native_biomes or biome_id in possible_biomes


func effective_weight(biome_id: StringName) -> int:
	if not is_allowed_in(biome_id):
		return 0
	var result: int = weight
	if biome_id in native_biomes and category == Category.NATIVE:
		result *= 3
	elif biome_id in native_biomes:
		result *= 2
	if category == Category.RARE:
		result = maxi(1, result / 3)
	return maxi(1, result)

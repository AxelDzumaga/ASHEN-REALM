class_name EnemySpawnResolver
extends RefCounted


static func get_pool(biome: BiomeData) -> Array[EnemyData]:
	if biome == null:
		return []
	if biome.normal_spawn_entries.is_empty():
		return biome.normal_enemy_pool.duplicate()
	var result: Array[EnemyData] = []
	for entry: EnemySpawnEntryData in biome.normal_spawn_entries:
		if entry != null and entry.is_allowed_in(biome.id) and entry.enemy not in result:
			result.append(entry.enemy)
	return result if not result.is_empty() else biome.normal_enemy_pool.duplicate()


static func get_enemy_weight(biome: BiomeData, enemy: EnemyData) -> int:
	if biome == null or enemy == null or biome.normal_spawn_entries.is_empty():
		return 1
	for entry: EnemySpawnEntryData in biome.normal_spawn_entries:
		if entry != null and entry.enemy == enemy:
			return entry.effective_weight(biome.id)
	return 1


static func pick_enemy(biome: BiomeData, seed: int) -> EnemyData:
	var pool: Array[EnemyData] = get_pool(biome)
	if pool.is_empty():
		return null
	var total: int = 0
	for enemy: EnemyData in pool:
		total += get_enemy_weight(biome, enemy)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var roll: int = rng.randi_range(1, maxi(1, total))
	for enemy: EnemyData in pool:
		roll -= get_enemy_weight(biome, enemy)
		if roll <= 0:
			return enemy
	return pool.back()

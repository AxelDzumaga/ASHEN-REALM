class_name ChestResolver
extends RefCounted


static func resolve(chest: ChestData, profile: ProfileData, seed_value: int) -> Dictionary:
	if chest == null or profile == null or not chest.is_valid():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pity_before: int = int(profile.chest_pity.get(String(chest.pity_key), 0)) if not chest.pity_key.is_empty() else 0
	var force_epic: bool = chest.epic_pity_limit > 0 and pity_before + 1 >= chest.epic_pity_limit
	var count: int = rng.randi_range(chest.min_rewards, chest.max_rewards)
	var item_ids: Array[String] = []
	var contains_epic := false
	for index: int in count:
		var rarity: EquipmentData.Rarity = _roll_rarity(chest, rng, force_epic and index == 0)
		var item: EquipmentData = _roll_item(chest, rarity, profile, rng)
		if item == null:
			return {}
		item_ids.append(String(item.id))
		contains_epic = contains_epic or item.rarity == EquipmentData.Rarity.EPIC
	return {
		"chest_id": String(chest.id),
		"items": item_ids,
		"ash": rng.randi_range(chest.ash_min, chest.ash_max),
		"forge_shards": rng.randi_range(chest.forge_shards_min, chest.forge_shards_max),
		"pity_key": String(chest.pity_key),
		"pity_after": 0 if contains_epic else pity_before + 1,
		"pity_triggered": force_epic,
		"contains_epic": contains_epic,
	}


static func _roll_rarity(chest: ChestData, rng: RandomNumberGenerator, force_epic: bool) -> EquipmentData.Rarity:
	if force_epic:
		return EquipmentData.Rarity.EPIC
	var total: float = 0.0
	for weight: float in chest.rarity_weights:
		total += maxf(0.0, weight)
	var roll: float = rng.randf() * maxf(total, 0.001)
	var accumulated := 0.0
	for rarity: int in 3:
		accumulated += maxf(0.0, chest.rarity_weights[rarity])
		if roll <= accumulated:
			return maxi(chest.minimum_rarity, rarity) as EquipmentData.Rarity
	return EquipmentData.Rarity.EPIC


static func _roll_item(chest: ChestData, rarity: EquipmentData.Rarity, profile: ProfileData, rng: RandomNumberGenerator) -> EquipmentData:
	var candidates: Array[EquipmentData] = EquipmentCatalog.get_items_by_rarity(rarity)
	if candidates.is_empty():
		return null
	if not chest.boss_set_id.is_empty() and rng.randf() < 0.35:
		var set_candidates: Array[EquipmentData] = []
		for item: EquipmentData in candidates:
			if item.set_id == chest.boss_set_id:
				set_candidates.append(item)
		if not set_candidates.is_empty():
			var missing: Array[EquipmentData] = []
			for item: EquipmentData in set_candidates:
				if int(profile.owned_equipment.get(String(item.id), 0)) <= 0:
					missing.append(item)
			candidates = missing if not missing.is_empty() else set_candidates
	return candidates[rng.randi_range(0, candidates.size() - 1)]


class_name ChestCatalog
extends RefCounted

const ASH_CACHE := &"ash_cache"
const RARE_RELIQUARY := &"rare_reliquary"
const EPIC_VAULT := &"epic_vault"
const ANCIENT_VAULT := &"ancient_vault"
const WARDEN_RELIQUARY := &"warden_reliquary"
const SUNKEN_RELIQUARY := &"sunken_reliquary"

static var _all: Array[ChestData] = []


static func get_all() -> Array[ChestData]:
	if _all.is_empty():
		_all = [
			_make(ASH_CACHE, "Arcón de Ceniza", ChestData.Tier.ASH, 1, 1, EquipmentData.Rarity.COMMON, [0.80, 0.18, 0.02], 10, 20, 0, 0, 0, &"", &"ash_chest"),
			_make(RARE_RELIQUARY, "Relicario Raro", ChestData.Tier.RARE, 1, 1, EquipmentData.Rarity.RARE, [0.0, 0.82, 0.18], 15, 30, 0, 1, 5, &"rare_epic", &"rare_chest"),
			_make(EPIC_VAULT, "Cámara Épica", ChestData.Tier.EPIC, 1, 2, EquipmentData.Rarity.RARE, [0.0, 0.55, 0.45], 25, 45, 1, 2, 3, &"epic_epic", &"epic_chest"),
			_make(ANCIENT_VAULT, "Bóveda Ancestral", ChestData.Tier.ANCIENT, 2, 2, EquipmentData.Rarity.RARE, [0.0, 0.35, 0.65], 40, 70, 2, 3, 2, &"ancient_epic", &"ancient_chest"),
			_make(WARDEN_RELIQUARY, "Relicario del Guardián", ChestData.Tier.BOSS, 1, 2, EquipmentData.Rarity.RARE, [0.0, 0.70, 0.30], 25, 45, 1, 2, 4, &"warden_epic", &"warden_chest", &"ashen_warden_set"),
			_make(SUNKEN_RELIQUARY, "Relicario de la Pira", ChestData.Tier.BOSS, 1, 2, EquipmentData.Rarity.RARE, [0.0, 0.50, 0.50], 35, 60, 1, 2, 3, &"sunken_epic", &"sunken_chest"),
		]
	return _all


static func get_by_id(chest_id: StringName) -> ChestData:
	for chest: ChestData in get_all():
		if chest.id == chest_id:
			return chest
	return null


static func _make(
	id: StringName, name: String, tier: ChestData.Tier, min_rewards: int, max_rewards: int,
	minimum_rarity: EquipmentData.Rarity, weights: Array, ash_min: int, ash_max: int,
	shards_min: int, shards_max: int, pity_limit: int, pity_key: StringName,
	visual_id: StringName, boss_set_id: StringName = &"",
) -> ChestData:
	var chest := ChestData.new()
	chest.id = id
	chest.display_name = name
	chest.tier = tier
	chest.min_rewards = min_rewards
	chest.max_rewards = max_rewards
	chest.minimum_rarity = minimum_rarity
	chest.rarity_weights = PackedFloat32Array(weights)
	chest.ash_min = ash_min
	chest.ash_max = ash_max
	chest.forge_shards_min = shards_min
	chest.forge_shards_max = shards_max
	chest.epic_pity_limit = pity_limit
	chest.pity_key = pity_key
	chest.visual_id = visual_id
	chest.boss_set_id = boss_set_id
	return chest


class_name ChestData
extends Resource

enum Tier { ASH, RARE, EPIC, ANCIENT, BOSS }

@export var id: StringName
@export var display_name: String
@export var tier: Tier = Tier.ASH
@export_range(1, 5, 1) var min_rewards: int = 1
@export_range(1, 5, 1) var max_rewards: int = 1
@export var minimum_rarity: EquipmentData.Rarity = EquipmentData.Rarity.COMMON
@export var rarity_weights: PackedFloat32Array = PackedFloat32Array([1.0, 0.0, 0.0])
@export_range(0, 999, 1) var ash_min: int = 0
@export_range(0, 999, 1) var ash_max: int = 0
@export_range(0, 99, 1) var forge_shards_min: int = 0
@export_range(0, 99, 1) var forge_shards_max: int = 0
@export_range(0, 20, 1) var epic_pity_limit: int = 0
@export var pity_key: StringName = &""
@export var boss_set_id: StringName = &""
@export var visual_id: StringName = &"chest"


func is_valid() -> bool:
	return not id.is_empty() and min_rewards > 0 and max_rewards >= min_rewards and rarity_weights.size() == 3


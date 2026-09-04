class_name ShopOfferData
extends Resource

enum RewardType { CHEST, EQUIPMENT, FORGE_SHARD }

@export var offer_id: StringName
@export var display_name: String
@export var section: StringName = &"chests"
@export var reward_type: RewardType = RewardType.CHEST
@export var reward_id: StringName
@export var quantity: int = 1
@export var currency: EconomyConfig.Currency = EconomyConfig.Currency.ASH
@export var price: int = 1
@export var required_level: int = 1
@export var required_boss_id: StringName = &""
@export var rotation_group: StringName = &""
@export var stock_per_rotation: int = 0
@export var icon_id: StringName = &"shop"


class_name UpgradeData
extends Resource

enum Category {
	STAT,
	PASSIVE,
}

enum Affinity {
	NONE,
	OFFENSE,
	DEFENSE,
	SUSTAIN,
}

enum UpgradeRarity {
	COMMON,
	RARE,
	EPIC,
}

enum EffectType {
	MAX_HEALTH_AND_HEAL,
	ATTACK,
	DEFENSE,
	HEAL,
	ATTACK_AND_HEALTH_COST,
}

@export var id: StringName
@export var display_name: String = "Mejora"
@export_multiline var description: String = ""
@export var category: Category = Category.STAT
@export var affinity: Affinity = Affinity.NONE
@export var rarity: UpgradeRarity = UpgradeRarity.COMMON
@export var effect_type: EffectType
@export var primary_value: int
@export var secondary_value: int
@export var tags: Array[StringName] = []
@export_range(1, 10, 1) var max_stacks: int = 3

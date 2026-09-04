class_name BiomeModifierData
extends Resource

enum Category {
	BENEFIT,
	RISK,
	NEUTRAL,
}

enum EffectType {
	ENERGY_GAIN_MULTIPLIER,
	HEALING_MULTIPLIER,
	STATUS_MAGNITUDE_MULTIPLIER,
	COMBAT_XP_MULTIPLIER,
	TREASURE_BIAS,
}

@export var modifier_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon_id: StringName
@export var category: Category = Category.NEUTRAL
@export var effect_type: EffectType
@export_range(0.1, 3.0, 0.01) var value: float = 1.0
@export var tags: Array[StringName] = []

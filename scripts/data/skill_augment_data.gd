class_name SkillAugmentData
extends Resource

enum EffectType {
	DAMAGE_MULTIPLIER,
	ENERGY_COST,
	EXECUTION_DAMAGE,
	GUARD_REDUCTION,
	GUARD_ENERGY,
	GUARD_COUNTER,
	HEAL_PERCENT,
	HEAL_ENERGY_COST,
	HEAL_DEFENSE,
}

@export var id: StringName
@export var display_name: String = "Aumento de habilidad"
@export_multiline var description: String = ""
@export var category: String = "UTILIDAD"
@export var skill_id: StringName
@export var effect_type: EffectType
@export_range(1, 99, 1) var max_stacks: int = 1
@export var value: float = 0.0
@export var secondary_value: float = 0.0
@export var tags: Array[StringName] = []

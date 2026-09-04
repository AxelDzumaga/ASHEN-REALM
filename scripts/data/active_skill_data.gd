class_name ActiveSkillData
extends Resource

enum SkillType {
	DAMAGE,
	DEFENSE,
	HEAL,
}

enum TargetType {
	SELF,
	SINGLE_ENEMY,
	ALL_ENEMIES,
	SINGLE_ALLY,
	ALL_ALLIES,
}

enum PresentationType {
	MELEE,
	SELF,
	RANGED,
}

enum CooldownType {
	BASIC_ATTACKS,
	ONCE_PER_COMBAT,
}

@export var id: StringName
@export var display_name: String = "Habilidad activa"
@export_multiline var description: String = ""
@export var icon_id: StringName = &"skill"
@export var skill_type: SkillType = SkillType.DAMAGE
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var presentation_type: PresentationType = PresentationType.MELEE
@export var cooldown_type: CooldownType = CooldownType.BASIC_ATTACKS
@export var enabled: bool = true
@export var tags: Array[StringName] = []
@export var effect_summary: String = ""
@export_range(0, 1000, 1) var energy_cost: int = 100
@export_range(0, 99, 1) var cooldown_turns: int = 3
@export_range(0.1, 10.0, 0.1) var damage_multiplier: float = 2.0
@export_range(0.0, 1.0, 0.01) var heal_percent: float = 0.0
@export_range(0.0, 1.0, 0.01) var damage_reduction: float = 0.0

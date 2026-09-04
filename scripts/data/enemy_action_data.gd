class_name EnemyActionData
extends Resource

@export var action_id: StringName
@export var display_name: String = "Ataque"
@export var action_type: EnemyAIEnums.ActionType = EnemyAIEnums.ActionType.ATTACK
@export var override_target_policy: bool = false
@export var target_policy: EnemyAIEnums.TargetPolicy = EnemyAIEnums.TargetPolicy.PRIMARY_PLAYER
@export_range(0.1, 4.0, 0.05) var power_multiplier: float = 1.0
@export var status_id: StringName
@export_range(0, 9) var status_stacks: int = 0
@export_range(-1, 9) var status_duration: int = -1
@export_range(0, 9) var cooldown: int = 0
@export_range(1, 1000) var weight: int = 100
@export var presentation_type: EnemyAIEnums.PresentationType = EnemyAIEnums.PresentationType.MELEE
@export_range(0, 99) var defense_bonus: int = 0
@export var enabled: bool = true


func is_special() -> bool:
	return action_id != &"basic_attack"

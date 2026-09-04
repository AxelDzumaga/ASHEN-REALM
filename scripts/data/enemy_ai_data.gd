class_name EnemyAIData
extends Resource

@export var ai_id: StringName
@export var display_name: String = "Enemigo"
@export var role: EnemyAIEnums.Role = EnemyAIEnums.Role.ASSAULT
@export var default_target_policy: EnemyAIEnums.TargetPolicy = EnemyAIEnums.TargetPolicy.PRIMARY_PLAYER
@export var actions: Array[EnemyActionData] = []
@export var tags: Array[StringName] = []


func get_role_name() -> String:
	return EnemyAIEnums.get_role_name(role)


func get_action_names() -> Array[String]:
	var names: Array[String] = []
	for action: EnemyActionData in actions:
		if action != null and action.enabled and action.display_name not in names:
			names.append(action.display_name)
	return names

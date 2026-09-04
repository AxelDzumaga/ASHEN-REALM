class_name EnemyAIRuntimeState
extends RefCounted

var action_cooldowns: Dictionary[StringName, int] = {}
var turn_count: int = 0
var last_action_id: StringName
var guard_stance_active: bool = false
var guard_defense_bonus: int = 0


func begin_turn() -> void:
	guard_stance_active = false
	guard_defense_bonus = 0


func is_action_ready(action: EnemyActionData) -> bool:
	return action != null and action.enabled and int(action_cooldowns.get(action.action_id, 0)) <= 0


func can_use_action(action: EnemyActionData) -> bool:
	if not is_action_ready(action):
		return false
	if action.action_type == EnemyAIEnums.ActionType.SELF_BUFF and guard_stance_active:
		return false
	return true


func can_plan_action(action: EnemyActionData) -> bool:
	# La postura sigue protegiendo durante el turno del jugador y se limpia al
	# comenzar el próximo turno enemigo. Planificar no debe mutarla antes.
	return is_action_ready(action)


func record_action(action: EnemyActionData) -> void:
	for action_id: StringName in action_cooldowns.keys():
		var remaining: int = int(action_cooldowns.get(action_id, 0))
		action_cooldowns[action_id] = maxi(0, remaining - 1)
	if action != null and action.cooldown > 0:
		action_cooldowns[action.action_id] = action.cooldown
	last_action_id = action.action_id if action != null else &""
	turn_count += 1


func activate_guard_stance(defense_bonus: int) -> void:
	guard_stance_active = defense_bonus > 0
	guard_defense_bonus = maxi(0, defense_bonus)


func get_defense_bonus() -> int:
	return guard_defense_bonus if guard_stance_active else 0

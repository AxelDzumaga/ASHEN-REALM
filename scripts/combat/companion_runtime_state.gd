class_name CompanionRuntimeState
extends RefCounted

var actions_completed: int = 0


func is_ability_ready(companion: CompanionData) -> bool:
	if companion == null:
		return false
	var interval: int = maxi(1, companion.ability_every_actions)
	return (actions_completed + 1) % interval == 0


func record_action() -> void:
	actions_completed += 1


func actions_until_ability(companion: CompanionData) -> int:
	if companion == null:
		return 0
	var interval: int = maxi(1, companion.ability_every_actions)
	var completed_in_cycle: int = actions_completed % interval
	return interval - completed_in_cycle

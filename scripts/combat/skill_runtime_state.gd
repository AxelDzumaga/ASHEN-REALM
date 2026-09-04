class_name SkillRuntimeState
extends RefCounted

var skill_id: StringName
var cooldown_remaining: int = 0
var used_this_combat: bool = false
var ready_announced: bool = false


func _init(runtime_skill_id: StringName) -> void:
	skill_id = runtime_skill_id


func reset() -> void:
	cooldown_remaining = 0
	used_this_combat = false
	ready_announced = false


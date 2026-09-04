class_name StatusEffectInstance
extends RefCounted

var data: StatusEffectData
var source_actor_id: StringName
var source_actor_ref: WeakRef
var stacks: int = 1
var remaining_duration: int = 0
var active: bool = true
var processed_this_turn: bool = false


func _init(
	status_data: StatusEffectData,
	source_id: StringName,
	source: RefCounted,
	initial_stacks: int,
	duration_override: int = -1,
) -> void:
	data = status_data
	source_actor_id = source_id
	source_actor_ref = weakref(source) if source != null else null
	stacks = clampi(initial_stacks, 1, data.max_stacks)
	remaining_duration = data.base_duration if duration_override < 0 else maxi(0, duration_override)
	active = data.duration_type == StatusEffectData.DurationType.PERMANENT_COMBAT or remaining_duration > 0


func apply_again(extra_stacks: int, duration: int, source_id: StringName, source: RefCounted) -> void:
	var safe_duration: int = data.base_duration if duration < 0 else maxi(0, duration)
	match data.stack_mode:
		StatusEffectData.StackMode.NONE:
			pass
		StatusEffectData.StackMode.REFRESH_DURATION:
			remaining_duration = maxi(remaining_duration, safe_duration)
		StatusEffectData.StackMode.ADD_STACK:
			stacks = clampi(stacks + maxi(1, extra_stacks), 1, data.max_stacks)
			remaining_duration = maxi(remaining_duration, safe_duration)
		StatusEffectData.StackMode.ADD_DURATION:
			remaining_duration += safe_duration
	active = true
	if data.stack_mode != StatusEffectData.StackMode.NONE:
		source_actor_id = source_id
		source_actor_ref = weakref(source) if source != null else null


func consume_duration(amount: int = 1) -> void:
	if data.duration_type == StatusEffectData.DurationType.PERMANENT_COMBAT:
		return
	remaining_duration = maxi(0, remaining_duration - maxi(0, amount))
	if remaining_duration == 0:
		active = false


func get_source_actor() -> RefCounted:
	if source_actor_ref == null:
		return null
	return source_actor_ref.get_ref() as RefCounted

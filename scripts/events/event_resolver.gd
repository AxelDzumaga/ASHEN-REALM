class_name EventResolver
extends RefCounted


static func select_for_run(pool: Array[EventData], run: RunState) -> EventData:
	if run == null:
		return null
	var eligible: Array[EventData] = []
	for event: EventData in pool:
		if event == null or not _flags_allow(event.required_flag_ids, event.excluded_flag_ids, run):
			continue
		if not event.repeatable and event.id in run.seen_event_ids:
			continue
		eligible.append(event)
	if eligible.is_empty():
		return null
	var highest_priority: int = -2147483648
	for event: EventData in eligible:
		highest_priority = maxi(highest_priority, event.selection_priority)
	var candidates: Array[EventData] = []
	for event: EventData in eligible:
		if event.selection_priority == highest_priority:
			candidates.append(event)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(run.board_seed ^ ((run.board_position + 1) * 104729) ^ ((run.events_resolved + 1) * 65537) ^ 0x68E7)
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func can_choose(event: EventData, option_a: bool, run: RunState) -> bool:
	if event == null or run == null:
		return false
	var required: Array[StringName] = event.option_a_required_flag_ids if option_a else event.option_b_required_flag_ids
	for flag_id: StringName in required:
		if not run.has_event_flag(flag_id):
			return false
	var health_delta: int = event.option_a_health_delta if option_a else event.option_b_health_delta
	return health_delta >= 0 or run.current_health + health_delta >= 1


static func _flags_allow(required: Array[StringName], excluded: Array[StringName], run: RunState) -> bool:
	for flag_id: StringName in required:
		if not run.has_event_flag(flag_id):
			return false
	for flag_id: StringName in excluded:
		if run.has_event_flag(flag_id):
			return false
	return true

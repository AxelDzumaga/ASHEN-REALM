extends Node

signal tutorial_presented(data: TutorialData)
signal tutorial_finished(id: StringName)
signal tutorial_cancelled(id: StringName)
signal tutorial_closed(id: StringName, result: FinishResult)
signal queue_empty

enum FinishResult {
	COMPLETED,
	SKIPPED,
	CANCELLED,
	RESET,
}

const CONTEXT_MAIN_MENU := &"main_menu"
const CONTEXT_LOBBY := &"lobby"
const CONTEXT_REGION := &"region"
const CONTEXT_BOARD := &"board"
const CONTEXT_COMBAT := &"combat"
const CONTEXT_RESULTS := &"results"
const CONTEXT_UPGRADE := &"upgrade"
const CONTEXT_SKILL_AUGMENT := &"skill_augment"
const CONTEXT_BOSS_REWARD := &"boss_reward"
const CONTEXT_EQUIPMENT := &"equipment"
const CONTEXT_COMPANION := &"companion"
const CONTEXT_PERMANENT_UPGRADES := &"permanent_upgrades"
const CONTEXT_CODEX := &"codex"
const CONTEXT_OTHER := &"other"

var _queue: Array[Dictionary] = []
var _current_id: StringName = &""
var _current_context: StringName = &""
var _current_owner: WeakRef
var _active_context: StringName = CONTEXT_MAIN_MENU
var _active_owner: WeakRef
var _presentation_blocked: bool = false
var _presentation_guard_generation: int = 0
var _trace_enabled: bool = false


func set_trace_enabled(enabled: bool) -> void:
	_trace_enabled = enabled
	_trace(&"TRACE_ENABLED")


func set_context(context_id: StringName, owner: Node = null) -> void:
	_active_context = context_id
	_active_owner = weakref(owner) if owner != null else null
	_discard_stale_requests()
	_present_next()


func request(id: StringName, context_id: StringName = &"", owner: Node = null) -> bool:
	_trace(&"SHOW_REQUEST", id, context_id)
	if not TutorialCatalog.is_valid_id(id) or is_completed(id) or id == _current_id or _queue_has(id):
		return false
	var request_data: Dictionary = _make_request(id, context_id, owner)
	if not _is_request_valid(request_data):
		return false
	_enqueue_by_priority(request_data)
	_present_next()
	return true


func request_and_wait(id: StringName, context_id: StringName = &"", owner: Node = null) -> bool:
	if DebugConfig.is_visual_slice_enabled():
		return true
	if is_completed(id):
		return true
	var accepted: bool = request(id, context_id, owner)
	if not accepted and not _has_pending_or_current(id):
		return false
	while not is_completed(id) and _has_pending_or_current(id):
		var finished_value: Variant = await tutorial_finished
		if StringName(finished_value) == id or is_completed(id):
			return is_completed(id)
	return is_completed(id)


func complete_current() -> void:
	_trace(&"UNDERSTOOD_MANAGER_ENTER", _current_id, _current_context)
	if _current_id.is_empty():
		return
	var completed_id: StringName = _finish_active_tutorial(FinishResult.COMPLETED, true)
	SaveManager.save_profile()
	if not completed_id.is_empty():
		tutorial_finished.emit(completed_id)


func skip_all() -> void:
	_trace(&"SKIP_MANAGER_ENTER", _current_id, _current_context)
	var active_id: StringName = _finish_active_tutorial(FinishResult.SKIPPED)
	_queue.clear()
	for id: StringName in TutorialCatalog.ALL_IDS:
		_mark_completed(id, false)
	SaveManager.save_profile()
	if not active_id.is_empty():
		tutorial_finished.emit(active_id)
	queue_empty.emit()


func reset_all() -> void:
	var active_id: StringName = _finish_active_tutorial(FinishResult.RESET)
	var queued_ids: Array[StringName] = _queued_ids()
	_queue.clear()
	SaveManager.profile.completed_tutorials.clear()
	SaveManager.save_profile()
	if not active_id.is_empty():
		tutorial_finished.emit(active_id)
	for id: StringName in queued_ids:
		tutorial_finished.emit(id)
	queue_empty.emit()


func complete_all_debug() -> void:
	if DebugConfig.DEBUG_TOOLS_ENABLED:
		skip_all()


func is_completed(id: StringName) -> bool:
	if DebugConfig.is_visual_slice_enabled():
		return true
	return SaveManager.profile.completed_tutorials.has(String(id))


func complete_without_presenting(id: StringName) -> bool:
	if not TutorialCatalog.is_valid_id(id) or is_completed(id) or id == _current_id:
		return false
	_remove_queued(id)
	return _mark_completed(id)


func sanitize_profile(profile: ProfileData, migrate_from_v5: bool) -> void:
	var sanitized: Array[String] = []
	for value: String in profile.completed_tutorials:
		var id: StringName = StringName(value)
		if TutorialCatalog.is_valid_id(id) and not sanitized.has(value):
			sanitized.append(value)
	if migrate_from_v5:
		for id: StringName in TutorialCatalog.MIGRATED_V5_COMPLETED:
			var value: String = String(id)
			if not sanitized.has(value):
				sanitized.append(value)
	if (sanitized.has(String(TutorialCatalog.FIRST_DEFEAT))
		or sanitized.has(String(TutorialCatalog.FIRST_VICTORY))
	) and not sanitized.has(String(TutorialCatalog.RUN_RESULTS)):
		sanitized.append(String(TutorialCatalog.RUN_RESULTS))
	profile.completed_tutorials = sanitized


func _make_request(id: StringName, context_id: StringName, owner: Node) -> Dictionary:
	return {
		"id": id,
		"context": context_id,
		"owner": weakref(owner) if owner != null else null,
	}


func _enqueue_by_priority(request_data: Dictionary) -> void:
	var id: StringName = StringName(request_data.get("id", &""))
	var data: TutorialData = TutorialCatalog.get_by_id(id)
	if data == null:
		return
	for index: int in _queue.size():
		var queued_id: StringName = StringName(_queue[index].get("id", &""))
		var queued_data: TutorialData = TutorialCatalog.get_by_id(queued_id)
		if queued_data != null and data.priority > queued_data.priority:
			_queue.insert(index, request_data)
			return
	_queue.append(request_data)


func _mark_completed(id: StringName, save_now: bool = true) -> bool:
	if is_completed(id):
		return false
	SaveManager.profile.completed_tutorials.append(String(id))
	if save_now:
		SaveManager.save_profile()
	return true


func _present_next() -> void:
	if _presentation_blocked or not _current_id.is_empty():
		return
	while not _queue.is_empty():
		var request_data: Dictionary = _queue.pop_front()
		var id: StringName = StringName(request_data.get("id", &""))
		if is_completed(id):
			continue
		if not _is_request_valid(request_data):
			tutorial_finished.emit(id)
			continue
		var data: TutorialData = TutorialCatalog.get_by_id(id)
		if data == null:
			continue
		_current_id = id
		_current_context = StringName(request_data.get("context", &""))
		_current_owner = request_data.get("owner") as WeakRef
		_trace(&"NEXT_REQUEST", id, _current_context)
		AudioManager.play_sfx(AudioManager.Sfx.TUTORIAL_OPEN, 1.0, -5.0)
		tutorial_presented.emit(data)
		return
	queue_empty.emit()


func _discard_stale_requests() -> void:
	if not _current_id.is_empty() and not _is_current_valid():
		var cancelled_id: StringName = _finish_active_tutorial(FinishResult.CANCELLED)
		tutorial_cancelled.emit(cancelled_id)
		tutorial_finished.emit(cancelled_id)

	var retained: Array[Dictionary] = []
	var discarded: Array[StringName] = []
	for request_data: Dictionary in _queue:
		if _is_request_valid(request_data):
			retained.append(request_data)
		else:
			discarded.append(StringName(request_data.get("id", &"")))
	_queue = retained
	for id: StringName in discarded:
		tutorial_finished.emit(id)


func _is_request_valid(request_data: Dictionary) -> bool:
	var context_id: StringName = StringName(request_data.get("context", &""))
	if not context_id.is_empty() and context_id != _active_context:
		return false
	var owner_ref: WeakRef = request_data.get("owner") as WeakRef
	return _is_owner_valid(owner_ref)


func _is_current_valid() -> bool:
	if not _current_context.is_empty() and _current_context != _active_context:
		return false
	return _is_owner_valid(_current_owner)


func _is_owner_valid(owner_ref: WeakRef) -> bool:
	if owner_ref == null:
		return true
	var owner: Node = owner_ref.get_ref() as Node
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		return false
	if _active_owner == null:
		return true
	var active_owner: Node = _active_owner.get_ref() as Node
	return is_instance_valid(active_owner) and owner == active_owner


func _queue_has(id: StringName) -> bool:
	for request_data: Dictionary in _queue:
		if StringName(request_data.get("id", &"")) == id:
			return true
	return false


func _has_pending_or_current(id: StringName) -> bool:
	return id == _current_id or _queue_has(id)


func _remove_queued(id: StringName) -> void:
	for index: int in range(_queue.size() - 1, -1, -1):
		if StringName(_queue[index].get("id", &"")) == id:
			_queue.remove_at(index)


func _queued_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for request_data: Dictionary in _queue:
		ids.append(StringName(request_data.get("id", &"")))
	return ids


func _finish_active_tutorial(result: FinishResult, mark_completed: bool = false) -> StringName:
	_trace(&"FINISH_ENTER", _current_id, _current_context, {"result": result})
	if _current_id.is_empty():
		return &""
	var finished_id: StringName = _current_id
	_clear_current()
	_trace(&"FINISH_STATE_CLEARED", finished_id)
	if mark_completed:
		_mark_completed(finished_id, false)
	_block_presentations_for_input_guard()
	_trace(&"CLOSE_SIGNAL_EMIT", finished_id, &"", {"result": result})
	tutorial_closed.emit(finished_id, result)
	return finished_id


func _block_presentations_for_input_guard() -> void:
	_presentation_blocked = true
	_presentation_guard_generation += 1
	var generation: int = _presentation_guard_generation
	get_tree().process_frame.connect(_on_first_guard_frame.bind(generation), CONNECT_ONE_SHOT)


func _on_first_guard_frame(generation: int) -> void:
	if generation != _presentation_guard_generation:
		return
	get_tree().process_frame.connect(_release_presentation_guard.bind(generation), CONNECT_ONE_SHOT)


func _release_presentation_guard(generation: int) -> void:
	if generation != _presentation_guard_generation:
		return
	_presentation_blocked = false
	_present_next()


func _clear_current() -> void:
	_current_id = &""
	_current_context = &""
	_current_owner = null


func _trace(
	event: StringName,
	tutorial_id: StringName = &"",
	context_id: StringName = &"",
	extra: Dictionary = {},
) -> void:
	if not _trace_enabled:
		return
	var details: Dictionary = {
		"manager_instance_id": get_instance_id(),
		"tutorial_id": String(tutorial_id),
		"context_id": String(context_id if not context_id.is_empty() else _active_context),
		"active_request": String(_current_id),
		"queue_size": _queue.size(),
	}
	details.merge(extra, true)
	print("[TUTORIAL_TRACE] %s %s" % [event, JSON.stringify(details)])

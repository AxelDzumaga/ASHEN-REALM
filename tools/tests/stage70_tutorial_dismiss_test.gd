extends Node

const GAME_SCENE := preload("res://scenes/core/game.tscn")

var _failures: Array[String] = []
var _game: Control
var _overlay: TutorialOverlay
var _guard: Control


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"stage70_tutorial_dismiss")
	TutorialManager.set_trace_enabled(true)
	SettingsManager.reduce_motion = false
	SaveManager.profile.completed_tutorials.clear()
	_game = GAME_SCENE.instantiate()
	add_child(_game)
	await _frames(2)
	var overlays := get_tree().get_nodes_in_group(&"tutorial_overlays")
	_check(overlays.size() == 1, "single overlay instance")
	if overlays.size() != 1:
		_finish()
		return
	_overlay = overlays[0] as TutorialOverlay
	_overlay.set_trace_enabled(true)
	_guard = _game.get_node("TutorialInputGuard") as Control
	_check(_visible_overlay_count() == 0, "before active overlay count 0")

	await _test_understood_with_pointer()
	await _test_skip_with_pointer()
	await _test_region_and_no_reopen()
	await _test_back_and_next_tutorial()
	_finish()


func _test_understood_with_pointer() -> void:
	await _reset_and_show(TutorialManager.CONTEXT_LOBBY, TutorialCatalog.LOBBY_INTRO)
	_check(_visible_overlay_count() == 1, "understood before visible count 1")
	await _click(_overlay.got_it_button)
	_check(not _overlay.visible, "understood immediate hidden")
	_check(TutorialManager.is_completed(TutorialCatalog.LOBBY_INTRO), "understood state completed")
	await _assert_stays_closed("understood")


func _test_skip_with_pointer() -> void:
	await _reset_and_show(TutorialManager.CONTEXT_LOBBY, TutorialCatalog.LOBBY_INTRO)
	await _click(_overlay.skip_button)
	_check(_overlay.confirmation.visible, "skip confirmation visible")
	var confirmation_position := _overlay.confirm_yes_button.get_global_rect().get_center()
	var screen_before_double_tap: Control = _game.current_screen
	await _click(_overlay.confirm_yes_button)
	_check(not _overlay.visible, "skip immediate hidden")
	_check(TutorialManager.is_completed(TutorialCatalog.BIOME_RULES), "skip state completed all")
	await _tap_at(confirmation_position)
	_check(_game.current_screen == screen_before_double_tap, "skip double tap blocked from underlying screen")
	_check(not _overlay.visible, "skip double tap harmless")
	await _assert_stays_closed("skip")


func _test_region_and_no_reopen() -> void:
	TutorialManager.reset_all()
	_game.show_region_selection()
	await _frames(2)
	_check(_overlay.visible, "region tutorial visible")
	_check(String(TutorialManager.get("_current_id")) == String(TutorialCatalog.BIOME_RULES), "region tutorial active id")
	await _touch(_overlay.got_it_button)
	_check(not _overlay.visible, "region immediate hidden")
	_check(TutorialManager.is_completed(TutorialCatalog.BIOME_RULES), "region state completed")
	await _assert_stays_closed("region")


func _test_back_and_next_tutorial() -> void:
	TutorialManager.reset_all()
	_game.show_region_selection()
	await _frames(2)
	var back := InputEventAction.new()
	back.action = &"ui_cancel"
	back.pressed = true
	_game._unhandled_input(back)
	await _frames(2)
	_check(_visible_overlay_count() <= 1, "back never duplicates overlay")
	TutorialManager.reset_all()
	TutorialManager.set_context(TutorialManager.CONTEXT_BOARD, _game.current_screen)
	TutorialManager.request(TutorialCatalog.BOARD_INTRO, TutorialManager.CONTEXT_BOARD, _game.current_screen)
	await _frames(2)
	_check(_overlay.visible, "next tutorial can show")
	await _click(_overlay.got_it_button)
	await _assert_stays_closed("next tutorial")


func _reset_and_show(context: StringName, tutorial_id: StringName) -> void:
	TutorialManager.reset_all()
	TutorialManager.set_context(context, self)
	TutorialManager.request(tutorial_id, context, self)
	await _frames(2)


func _click(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	_check(get_viewport().gui_get_hovered_control() == control, "mouse hit target %s" % control.name)
	await _tap_at(position)


func _tap_at(position: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.position = position
	down.global_position = position
	down.pressed = true
	get_viewport().push_input(down, true)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = position
	up.global_position = position
	up.pressed = false
	get_viewport().push_input(up, true)
	await get_tree().process_frame


func _touch(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = position
	down.pressed = true
	get_viewport().push_input(down, true)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = position
	up.pressed = false
	get_viewport().push_input(up, true)
	await get_tree().process_frame


func _assert_stays_closed(label: String) -> void:
	_check(_visible_overlay_count() == 0, "%s active count immediate 0" % label)
	await _frames(1)
	_check(not _overlay.visible, "%s hidden +1" % label)
	await _frames(1)
	_check(not _overlay.visible, "%s hidden +2" % label)
	await _frames(3)
	_check(not _overlay.visible, "%s hidden +5" % label)
	_check(not _guard.visible, "%s input guard released" % label)
	_check(_visible_overlay_count() == 0, "%s active count after 0" % label)


func _visible_overlay_count() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"tutorial_overlays"):
		if node is CanvasItem and (node as CanvasItem).visible:
			count += 1
	return count


func _frames(count: int) -> void:
	for _index: int in count:
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	print("[STAGE70_TUTORIAL] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


func _finish() -> void:
	print(JSON.stringify({"schema": 1, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)

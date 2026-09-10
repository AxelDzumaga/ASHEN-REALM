extends Control

const OVERLAY_SCENE := preload("res://scenes/ui/tutorial_overlay.tscn")

var overlay: TutorialOverlay
var failures: Array[String] = []


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"tutorial_overlay_runtime")
	TutorialManager.set_trace_enabled(true)
	overlay = OVERLAY_SCENE.instantiate()
	overlay.set_trace_enabled(true)
	add_child(overlay)
	print("[TUTORIAL_TRACE] OVERLAY_COUNT %d" % get_tree().get_nodes_in_group(&"tutorial_overlays").size())
	await _test_understood()
	await _test_skip()
	await _test_two_tutorials()
	await _test_stale()
	print("[TUTORIAL_TEST] failures=%s" % JSON.stringify(failures))
	get_tree().quit(1 if not failures.is_empty() else 0)


func _prepare(context: StringName) -> void:
	TutorialManager.reset_all()
	TutorialManager.set_context(context, self)
	await get_tree().process_frame
	await get_tree().process_frame


func _test_understood() -> void:
	await _prepare(TutorialManager.CONTEXT_LOBBY)
	TutorialManager.request(TutorialCatalog.LOBBY_INTRO, TutorialManager.CONTEXT_LOBBY, self)
	_check(overlay.visible, "ENTENDIDO show")
	overlay.got_it_button.pressed.emit()
	_check(not overlay.visible, "ENTENDIDO immediate hidden")
	_check(String(TutorialManager.get("_current_id")).is_empty(), "ENTENDIDO active cleared")
	await get_tree().process_frame
	_check(not overlay.visible, "ENTENDIDO +1 hidden")
	await get_tree().process_frame
	_check(not overlay.visible, "ENTENDIDO +2 hidden")


func _test_skip() -> void:
	await _prepare(TutorialManager.CONTEXT_LOBBY)
	TutorialManager.request(TutorialCatalog.LOBBY_INTRO, TutorialManager.CONTEXT_LOBBY, self)
	overlay.skip_button.pressed.emit()
	_check(overlay.confirmation.visible, "SKIP confirmation visible")
	overlay.confirm_yes_button.pressed.emit()
	_check(not overlay.visible, "SKIP immediate hidden")
	_check(String(TutorialManager.get("_current_id")).is_empty(), "SKIP active cleared")
	_check((TutorialManager.get("_queue") as Array).is_empty(), "SKIP queue cleared")
	await get_tree().process_frame
	_check(not overlay.visible, "SKIP +1 hidden")
	await get_tree().process_frame
	_check(not overlay.visible, "SKIP +2 hidden")


func _test_two_tutorials() -> void:
	await _prepare(TutorialManager.CONTEXT_BOARD)
	TutorialManager.request(TutorialCatalog.BOARD_INTRO, TutorialManager.CONTEXT_BOARD, self)
	TutorialManager.request(TutorialCatalog.TILE_COMBAT, TutorialManager.CONTEXT_BOARD, self)
	overlay.got_it_button.pressed.emit()
	_check(not overlay.visible, "QUEUE A immediate hidden")
	await get_tree().process_frame
	_check(not overlay.visible, "QUEUE B hidden during guard")
	await get_tree().process_frame
	_check(overlay.visible, "QUEUE B visible after guard")
	_check(String(TutorialManager.get("_current_id")) == String(TutorialCatalog.TILE_COMBAT), "QUEUE B active")
	overlay.got_it_button.pressed.emit()
	_check(not overlay.visible, "QUEUE B close hidden")


func _test_stale() -> void:
	await _prepare(TutorialManager.CONTEXT_LOBBY)
	TutorialManager.request(TutorialCatalog.LOBBY_INTRO, TutorialManager.CONTEXT_LOBBY, self)
	TutorialManager.set_context(TutorialManager.CONTEXT_REGION, self)
	_check(not overlay.visible, "STALE immediate hidden")
	_check(not TutorialManager.is_completed(TutorialCatalog.LOBBY_INTRO), "STALE not completed")
	await get_tree().process_frame
	_check(not overlay.visible, "STALE +1 hidden")
	await get_tree().process_frame
	_check(not overlay.visible, "STALE +2 hidden")


func _check(condition: bool, label: String) -> void:
	print("[TUTORIAL_TEST] %s=%s" % [label, condition])
	if not condition:
		failures.append(label)

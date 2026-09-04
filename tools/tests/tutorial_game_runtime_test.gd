extends Node

const GAME_SCENE := preload("res://scenes/core/game.tscn")

var failures: Array[String] = []


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"tutorial_game_runtime")
	TutorialManager.set_trace_enabled(true)
	var game: Control = GAME_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	var overlays: Array[Node] = get_tree().get_nodes_in_group(&"tutorial_overlays")
	_check(overlays.size() == 1, "GAME overlay count one")
	if overlays.is_empty():
		_finish()
		return
	var overlay := overlays[0] as TutorialOverlay
	overlay.set_trace_enabled(true)
	var guard: Control = game.get_node("TutorialInputGuard") as Control
	print("[TUTORIAL_TRACE] GAME_TREE %s" % JSON.stringify({
		"game_instance_id": game.get_instance_id(),
		"overlay_count": overlays.size(),
		"overlay_instance_id": overlay.get_instance_id(),
		"overlay_path": String(overlay.get_path()),
		"overlay_parent": String(overlay.get_parent().get_path()),
		"overlay_children": overlay.get_child_count(),
		"guard_instance_id": guard.get_instance_id(),
		"guard_path": String(guard.get_path()),
		"guard_children": guard.get_child_count(),
		"guard_class": guard.get_class(),
	}))
	TutorialManager.reset_all()
	game.show_lobby()
	await get_tree().process_frame
	_check(overlay.visible, "GAME lobby overlay shown")
	overlay.got_it_button.pressed.emit()
	_check(not overlay.visible, "GAME ENTENDIDO immediate hidden")
	_check(guard.visible, "GAME input guard active")
	await get_tree().process_frame
	_check(not overlay.visible, "GAME ENTENDIDO +1 hidden")
	await get_tree().process_frame
	_check(not overlay.visible, "GAME ENTENDIDO +2 hidden")
	_check(not guard.visible, "GAME input guard released")
	_finish()


func _check(condition: bool, label: String) -> void:
	print("[TUTORIAL_TEST] %s=%s" % [label, condition])
	if not condition:
		failures.append(label)


func _finish() -> void:
	print("[TUTORIAL_TEST] failures=%s" % JSON.stringify(failures))
	get_tree().quit(1 if not failures.is_empty() else 0)

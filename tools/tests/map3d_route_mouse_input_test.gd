extends Node

const MAP_SCENE := preload("res://scenes/board3d/ashen_wastes_map_3d.tscn")

var _failures: Array[String] = []
var _diagnostics: Array[Dictionary] = []


func _ready() -> void:
	await _test_pointer_choice("mouse_a", 0, false)
	await _test_pointer_choice("mouse_b", 1, false)
	await _test_pointer_choice("touch_b", 1, true)
	await _test_direct_unhandled_raycast()
	await _test_invalid_pointer_targets()
	await _test_controller_moving_blocks_input()
	await _test_single_commit()
	await _test_keyboard_choice(KEY_A, 0, "keyboard_a")
	await _test_keyboard_choice(KEY_B, 1, "keyboard_b")
	await _test_actual_turn_moves_after_mouse()
	print(JSON.stringify({"failures": _failures, "diagnostics": _diagnostics}))
	RunManager.current_run = null
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_pointer_choice(key: String, option: int, touch: bool) -> void:
	var context: Dictionary = await _create_route_context()
	var map: Control = context["map"]
	var destinations: Array[int] = context["destinations"]
	var selected: Array[int] = []
	map.route_destination_selected.connect(func(destination: int) -> void: selected.append(destination))
	_send_pointer(map, destinations[option], touch)
	await get_tree().process_frame
	_check(key, selected == [destinations[option]])
	_destroy_context(map)


func _test_invalid_pointer_targets() -> void:
	var context: Dictionary = await _create_route_context()
	var map: Control = context["map"]
	var selected: Array[int] = []
	map.route_destination_selected.connect(func(destination: int) -> void: selected.append(destination))
	_send_mouse(Vector2(4.0, 4.0))
	await get_tree().process_frame
	_check("click_outside_ignored", selected.is_empty())
	_send_pointer(map, 1, false)
	await get_tree().process_frame
	_check("non_destination_tile_ignored", selected.is_empty())
	_destroy_context(map)


func _test_direct_unhandled_raycast() -> void:
	var context: Dictionary = await _create_route_context()
	var map: Control = context["map"]
	var destinations: Array[int] = context["destinations"]
	var selected: Array[int] = []
	map.route_destination_selected.connect(func(destination: int) -> void: selected.append(destination))
	var tiles: Array = map.get("_tiles")
	var camera: Camera3D = map.get_node("%Camera3D")
	var screen_position: Vector2 = camera.unproject_position(tiles[destinations[0]].global_position + Vector3(0.0, 0.25, 0.0))
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = screen_position
	event.global_position = screen_position
	map.call("_unhandled_input", event)
	_check("direct_unhandled_raycast", selected == [destinations[0]])
	_destroy_context(map)


func _test_controller_moving_blocks_input() -> void:
	var context: Dictionary = await _create_route_context()
	var map: Control = context["map"]
	var destinations: Array[int] = context["destinations"]
	var controller: RefCounted = context["controller"]
	var selected: Array[int] = []
	map.route_destination_selected.connect(func(destination: int) -> void: selected.append(destination))
	_check("controller_enters_moving", controller.choose_destination(destinations[0]))
	_send_pointer(map, destinations[1], false)
	await get_tree().process_frame
	_check("moving_input_blocked", selected.is_empty())
	_destroy_context(map)


func _test_single_commit() -> void:
	var context: Dictionary = await _create_route_context()
	var map: Control = context["map"]
	var destinations: Array[int] = context["destinations"]
	var selected: Array[int] = []
	map.route_destination_selected.connect(func(destination: int) -> void: selected.append(destination))
	_send_pointer(map, destinations[0], false)
	_send_pointer(map, destinations[0], false)
	await get_tree().process_frame
	_check("single_selection_only", selected == [destinations[0]])
	_destroy_context(map)


func _test_keyboard_choice(keycode: Key, option: int, key: String) -> void:
	var context: Dictionary = await _create_route_context()
	var map: Control = context["map"]
	var destinations: Array[int] = context["destinations"]
	var selected: Array[int] = []
	map.route_destination_selected.connect(func(destination: int) -> void: selected.append(destination))
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.physical_keycode = keycode
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	_check(key, selected == [destinations[option]])
	_destroy_context(map)


func _test_actual_turn_moves_after_mouse() -> void:
	RunManager.current_run = null
	var map: Control = MAP_SCENE.instantiate()
	add_child(map)
	await get_tree().process_frame
	map.set("_forced_dice_result", 4)
	map.call("_on_roll_pressed")
	for _frame: int in 90:
		if (map.get("_pending_route_destinations") as Array).size() == 2:
			break
		await get_tree().process_frame
	var destinations: Array[int] = []
	destinations.assign(map.get("_pending_route_destinations"))
	_check("actual_flow_waits_for_route", destinations.size() == 2)
	if destinations.size() == 2:
		_send_pointer(map, destinations[0], false)
		for _frame: int in 240:
			if not bool(map.get("_is_moving")):
				break
			await get_tree().process_frame
		var run: RunState = map.get("_run")
		var controller: RefCounted = map.get("_turn_controller")
		_check("movement_begins_after_selection", run.board_position == destinations[0])
		_check("turn_completes_after_selection", int(controller.get("state")) == 0 and not bool(map.get("_is_moving")))
	_destroy_context(map)


func _create_route_context() -> Dictionary:
	RunManager.current_run = null
	var map: Control = MAP_SCENE.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().physics_frame
	var controller: RefCounted = map.get("_turn_controller")
	var plan: Dictionary = controller.request_roll(4)
	var destinations: Array[int] = []
	destinations.assign(plan.get("destinations", []))
	_check("two_destinations", destinations.size() == 2)
	if destinations.size() != 2:
		return {"map": map, "controller": controller, "destinations": destinations}
	map.set("_pending_route_destinations", destinations.duplicate())
	var tiles: Array = map.get("_tiles")
	var positions: Array[Vector3] = map.get("_positions")
	for option: int in destinations.size():
		var destination: int = destinations[option]
		var tile: StaticBody3D = tiles[destination]
		tile.call("set_route_marker", "A" if option == 0 else "B")
		var collider: CollisionShape3D = tile.get_node("TouchTarget")
		var size := Vector3.ZERO
		if collider.shape is BoxShape3D:
			size = (collider.shape as BoxShape3D).size
		_diagnostics.append({
			"destination": destination,
			"world_position": tile.position,
			"collider_global_position": collider.global_position,
			"collider_size": size,
			"collider_disabled": collider.disabled,
			"collision_layer": tile.collision_layer,
		})
		_check("collider_%d" % destination, not collider.disabled and size.x >= 3.59 and tile.collision_layer == 1)
	map.get_node("%CameraRig").call("focus_route", destinations, positions)
	await get_tree().create_timer(0.4).timeout
	await get_tree().physics_frame
	return {"map": map, "controller": controller, "destinations": destinations}


func _send_pointer(map: Control, tile_index: int, touch: bool) -> void:
	var tiles: Array = map.get("_tiles")
	var camera: Camera3D = map.get_node("%Camera3D")
	var screen_position: Vector2 = camera.unproject_position(tiles[tile_index].global_position + Vector3(0.0, 0.25, 0.0))
	if touch:
		var event := InputEventScreenTouch.new()
		event.pressed = true
		event.position = screen_position
		get_viewport().push_input(event, true)
	else:
		_send_mouse(screen_position)


func _send_mouse(screen_position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = screen_position
	event.global_position = screen_position
	get_viewport().push_input(event, true)


func _destroy_context(map: Control) -> void:
	map.queue_free()
	RunManager.current_run = null
	await get_tree().process_frame


func _check(key: String, condition: bool) -> void:
	if not condition:
		_failures.append(key)

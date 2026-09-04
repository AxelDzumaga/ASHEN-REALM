extends Node

const MAP_SCENE := preload("res://scenes/board3d/ashen_wastes_map_3d.tscn")


func _ready() -> void:
	var failures: Array[String] = []
	RunManager.current_run = null
	var map: Control = MAP_SCENE.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	var run: RunState = map.get("_run") as RunState
	var positions: Array[Vector3] = map.get("_positions")
	var tiles: Array = map.get("_tiles")
	_check(failures, "sandbox_run", run != null and bool(map.get("_sandbox_mode")))
	_check(failures, "board_30", run != null and run.board_tile_sequence.size() == 30)
	_check(failures, "layout_30", positions.size() == 30)
	_check(failures, "tiles_30", tiles.size() == 30)
	_check(failures, "start_index", run.board_position == 0)
	_check(failures, "boss_index", run.board_tile_sequence[29] == BoardTileData.TileType.BOSS)
	var marker: Node3D = map.get_node("%PlayerMarker3D")
	_check(failures, "marker_at_start", marker.position.is_equal_approx(positions[0] + Vector3(0.0, 1.05, 0.0)))
	var camera: Camera3D = map.get_node("%Camera3D")
	_check(failures, "orthographic_camera", camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	var mesh_count: int = map.find_children("*", "MeshInstance3D", true, false).size()
	_check(failures, "mesh_budget", mesh_count < 100)
	var multimesh_count: int = map.find_children("*", "MultiMeshInstance3D", true, false).size()
	_check(failures, "multimesh_used", multimesh_count >= 2)
	var touch_targets_large := true
	for tile: StaticBody3D in tiles:
		var touch_target: CollisionShape3D = tile.get_node("TouchTarget") as CollisionShape3D
		if not (touch_target.shape is BoxShape3D) or (touch_target.shape as BoxShape3D).size.x < 3.59:
			touch_targets_large = false
	_check(failures, "touch_targets_mobile_sized", touch_targets_large)

	var controller: RefCounted = map.get("_turn_controller")
	var plan: Dictionary = controller.request_roll(4)
	var destinations: Array = plan.get("destinations", [])
	var destination: int = int(destinations[0])
	if destinations.size() == 2:
		_check(failures, "route_choice_accepted", controller.choose_destination(destination))
	var visited: Array[int] = []
	controller.logical_step_emitted.connect(func(_from: int, to: int) -> void: visited.append(to))
	var resolution_state := {"seen": false}
	controller.tile_resolution_requested.connect(func(_type: int, _position: int) -> void: resolution_state["seen"] = true)
	await map.call("_move_player_to", destination)
	_check(failures, "movement_steps", visited == range(1, destination + 1))
	_check(failures, "movement_destination", run.board_position == destination)
	_check(failures, "resolution_not_early", not bool(resolution_state["seen"]))
	var resolution: Dictionary = controller.request_tile_resolution()
	_check(failures, "resolution_after_animation", bool(resolution_state["seen"]) and int(resolution.get("position", -1)) == destination)
	_check(failures, "marker_at_destination", marker.position.is_equal_approx(positions[destination] + Vector3(0.0, 1.05, 0.0)))
	_check(failures, "visited_tile_dimmed", (tiles[0] as MapTile3D).is_visually_dimmed())
	_check(failures, "current_tile_emphasized", tiles[destination].scale.x > 1.08)
	controller.complete_resolution()
	print(JSON.stringify({
		"failures": failures,
		"positions": positions.size(),
		"tiles": tiles.size(),
		"mesh_instances": mesh_count,
		"multimeshes": multimesh_count,
		"destination": destination,
		"visited": visited,
		"sandbox": true,
		"profile_written_by_test": false,
	}))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(failures: Array[String], key: String, passed: bool) -> void:
	if not passed:
		failures.append(key)

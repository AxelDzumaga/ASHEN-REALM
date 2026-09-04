extends Node

const MAP_SCENE := preload("res://scenes/board3d/ashen_wastes_map_3d.tscn")

const CAPTURES := [
	["start", "02_start.png"],
	["full", "01_full_map.png"],
	["route", "03_route_choice.png"],
	["movement", "04_movement.png"],
	["combat", "05_combat_tile.png"],
	["event", "06_event_tile.png"],
	["elite", "07_elite.png"],
	["boss", "08_boss_area.png"],
]


func _ready() -> void:
	RunManager.current_run = null
	var map: Control = MAP_SCENE.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	var output_directory: String = ProjectSettings.globalize_path("res://build/map3d_prototype/visual")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var errors: Array[Dictionary] = []
	for capture: Array in CAPTURES:
		_prepare(map, String(capture[0]))
		await get_tree().create_timer(0.45).timeout
		var image: Image = get_viewport().get_texture().get_image()
		var output_path: String = output_directory.path_join(String(capture[1]))
		var error: Error = image.save_png(output_path)
		if error != OK:
			errors.append({"file": capture[1], "error": error})
		print("MAP3D_CAPTURE path=%s error=%d size=%s" % [output_path, error, image.get_size()])
	var draw_calls: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print(JSON.stringify({
		"captures": CAPTURES.size(),
		"errors": errors,
		"draw_calls_last_frame": draw_calls,
		"primitives_last_frame": primitives,
		"renderer": RenderingServer.get_current_rendering_method(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
	}))
	map.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if errors.is_empty() else 1)


func _prepare(map: Control, mode: String) -> void:
	var positions: Array[Vector3] = map.get("_positions")
	var tiles: Array = map.get("_tiles")
	var run: RunState = map.get("_run") as RunState
	var rig: Node3D = map.get_node("%CameraRig")
	var marker: Node3D = map.get_node("%PlayerMarker3D")
	var message: Label = map.get("_event_label") as Label
	for tile: StaticBody3D in tiles:
		tile.call("set_route_marker", "")
	match mode:
		"full":
			rig.call("focus_full_map", positions, 0.0)
			message.text = "RECORRIDO COMPLETO · 30 POSICIONES"
		"start":
			map.call("_place_player_immediately", 0)
			rig.call("focus_navigation", 0, positions, 0.0)
			message.text = "INICIO · POSICIÓN 1 / 30"
		"route":
			tiles[4].call("set_route_marker", "A")
			tiles[5].call("set_route_marker", "B")
			var route_destinations: Array[int] = [4, 5]
			rig.call("focus_route", route_destinations, positions)
			message.text = "ELEGÍ TU DESTINO · A / B"
		"movement":
			marker.position = positions[3].lerp(positions[4], 0.5) + Vector3(0.0, 1.55, 0.0)
			rig.call("follow_step", 3, 4, positions, 0.0)
			message.text = "MOVIMIENTO · 4 → 5"
		"combat":
			_focus_type(map, BoardTileData.TileType.COMBAT, "COMBAT · FLUJO 2D EXISTENTE")
		"event":
			_focus_type(map, BoardTileData.TileType.EVENT, "EVENT · DECISIÓN EXISTENTE")
		"elite":
			_focus_type(map, BoardTileData.TileType.ELITE, "ÉLITE · ENCUENTRO EXISTENTE")
		"boss":
			map.call("_place_player_immediately", 29)
			rig.call("focus_navigation", 29, positions, 0.0)
			message.text = "BOSS · ASHEN WARDEN · 30 / 30"


func _focus_type(map: Control, tile_type: int, label_text: String) -> void:
	var run: RunState = map.get("_run") as RunState
	var positions: Array[Vector3] = map.get("_positions")
	var index: int = run.board_tile_sequence.find(tile_type)
	if index < 0:
		index = 0
	map.call("_place_player_immediately", index)
	map.get_node("%CameraRig").call("focus_navigation", index, positions, 0.0)
	(map.get("_event_label") as Label).text = label_text

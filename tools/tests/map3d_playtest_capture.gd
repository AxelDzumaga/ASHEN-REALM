extends Node

const GAME_SCENE := preload("res://scenes/core/game.tscn")

const CAPTURES := [
	["start", "01_start.png"],
	["navigation", "02_navigation.png"],
	["route", "03_route_choice.png"],
	["mid", "04_mid_run.png"],
	["combat_return", "05_combat_return.png"],
	["event_return", "06_event_return.png"],
	["elite", "07_elite_area.png"],
	["boss_approach", "08_boss_approach.png"],
	["boss", "09_boss_area.png"],
	["full", "10_full_map.png"],
]


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"map3d_playtest_capture")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	var game: Control = GAME_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.call("_launch_map3d_prototype")
	await get_tree().process_frame
	await get_tree().process_frame
	var map: Control = game.get("board_screen") as Control
	# La sesión de captura representa el estado estable posterior a la transición.
	# Evita que un ColorRect transparente todavía presente ensucie el readback GPU.
	(game.get("transition_overlay") as ColorRect).visible = false
	var output_directory := ProjectSettings.globalize_path("res://build/map3d_playtest/visual")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var errors: Array[Dictionary] = []
	for capture: Array in CAPTURES:
		_prepare(map, String(capture[0]))
		await get_tree().create_timer(0.5).timeout
		var image: Image = get_viewport().get_texture().get_image()
		var path: String = output_directory.path_join(String(capture[1]))
		var error: Error = image.save_png(path)
		if error != OK:
			errors.append({"file": capture[1], "error": error})
		print("MAP3D_PLAYTEST_CAPTURE path=%s error=%d size=%s" % [path, error, image.get_size()])
	var draw_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print(JSON.stringify({
		"captures": CAPTURES.size(), "errors": errors,
		"draw_calls_last_frame": draw_calls, "primitives_last_frame": primitives,
		"fps": Engine.get_frames_per_second(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
	}))
	game.queue_free()
	RunManager.current_run = null
	await get_tree().process_frame
	get_tree().quit(0 if errors.is_empty() else 1)


func _prepare(map: Control, mode: String) -> void:
	var run: RunState = map.get("_run") as RunState
	var positions: Array[Vector3] = map.get("_positions")
	var tiles: Array = map.get("_tiles")
	var rig: Node3D = map.get_node("%CameraRig")
	var marker: Node3D = map.get_node("%PlayerMarker3D")
	for tile: StaticBody3D in tiles:
		tile.call("set_route_marker", "")
	match mode:
		"start":
			_focus_index(map, 0, "INICIO · TIRÁ EL D4 PARA AVANZAR")
		"navigation":
			_focus_index(map, 4, "NAVEGACIÓN · PRÓXIMAS CASILLAS VISIBLES")
		"route":
			_focus_index(map, 7, "ELEGÍ TU DESTINO · TOCÁ A O B")
			var route_destinations: Array[int] = [8, 9]
			tiles[8].call("set_route_marker", "A")
			tiles[9].call("set_route_marker", "B")
			rig.call("focus_route", route_destinations, positions)
		"mid":
			_focus_index(map, 14, "MITAD DE LA RUN · VISITADAS ATENUADAS")
		"combat_return":
			_focus_index(map, _find_type(run, BoardTileData.TileType.COMBAT), "¡VICTORIA! · RETORNO AL MISMO MAPA")
		"event_return":
			_focus_index(map, _find_type(run, BoardTileData.TileType.EVENT), "EVENTO RESUELTO · SEGUÍ ADELANTE")
		"elite":
			_focus_index(map, _find_type(run, BoardTileData.TileType.ELITE), "ÁREA ÉLITE · ENCUENTRO 2D EXISTENTE")
		"boss_approach":
			_focus_index(map, 26, "APROXIMACIÓN AL ASHEN WARDEN")
		"boss":
			_focus_index(map, 29, "BOSS · ASHEN WARDEN · 30 / 30")
		"full":
			run.board_position = 0
			map.call("_place_player_immediately", 0)
			map.call("_update_hud")
			rig.call("focus_full_map", positions, 0.0)
			(map.get("_event_label") as Label).text = "RECORRIDO COMPLETO · 30 POSICIONES"
	if mode == "navigation":
		marker.scale = Vector3.ONE


func _focus_index(map: Control, index: int, message: String) -> void:
	var run: RunState = map.get("_run") as RunState
	var positions: Array[Vector3] = map.get("_positions")
	run.board_position = index
	map.call("_place_player_immediately", index)
	map.call("_update_hud")
	map.get_node("%CameraRig").call("focus_navigation", index, positions, 0.0)
	(map.get("_event_label") as Label).text = message


func _find_type(run: RunState, type: int) -> int:
	return maxi(0, run.board_tile_sequence.find(type))

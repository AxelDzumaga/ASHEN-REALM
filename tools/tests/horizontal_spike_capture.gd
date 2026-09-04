extends Node

## SPIKE horizontal (backlog punto 2) — prototipo aislado de solo lectura.
## No modifica project.godot ni ninguna escena productiva. La resolución
## horizontal se fuerza por línea de comandos (--resolution 1280x720) al
## lanzar este script, nunca tocando window/handheld/orientation ni
## window/size en el proyecto real. Las capturas van a una carpeta propia
## para no pisar las referencias portrait existentes en visual/.

const GAME_SCENE := preload("res://scenes/core/game.tscn")

const CAPTURES := [
	["navigation", "h01_navigation.png"],
	["route", "h02_route_choice.png"],
	["full", "h03_full_map.png"],
	["closeup", "h04_equipment_closeup.png"],
	["dimtest", "h05_visited_dim_check.png"],
]


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"horizontal_spike_capture")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	var game: Control = GAME_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.call("_launch_map3d_prototype")
	await get_tree().process_frame
	await get_tree().process_frame
	var map: Control = game.get("board_screen") as Control
	(game.get("transition_overlay") as ColorRect).visible = false
	var output_directory := ProjectSettings.globalize_path("res://build/map3d_playtest/visual_horizontal_spike")
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
		print("HORIZONTAL_SPIKE_CAPTURE path=%s error=%d size=%s" % [path, error, image.get_size()])
	print(JSON.stringify({
		"captures": CAPTURES.size(),
		"errors": errors,
		"viewport_size": get_viewport().get_visible_rect().size,
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
	for tile: StaticBody3D in tiles:
		tile.call("set_route_marker", "")
	match mode:
		"dimtest":
			run.board_position = 10
			map.call("_place_player_immediately", 10)
			map.call("_update_hud")
			(map.get("_event_label") as Label).text = "DIM CHECK · TILE 02 SHOULD BE VISITED"
			rig.position = positions[2]
			rig.get_node("Camera3D").size = 5.0
		"closeup":
			var index := 4
			run.board_position = index
			map.call("_place_player_immediately", index)
			map.call("_update_hud")
			(map.get("_event_label") as Label).text = "EQUIPMENT CLOSEUP CHECK"
			rig.position = positions[index]
			rig.get_node("Camera3D").size = 4.0
		"navigation":
			_focus_index(map, 4, "NAVEGACIÓN · HORIZONTAL SPIKE")
		"route":
			_focus_index(map, 7, "ELEGÍ TU DESTINO · TOCÁ A O B")
			var route_destinations: Array[int] = [8, 9]
			tiles[8].call("set_route_marker", "A")
			tiles[9].call("set_route_marker", "B")
			rig.call("focus_route", route_destinations, positions)
		"full":
			run.board_position = 0
			map.call("_place_player_immediately", 0)
			map.call("_update_hud")
			rig.call("focus_full_map", positions, 0.0)
			(map.get("_event_label") as Label).text = "RECORRIDO COMPLETO · HORIZONTAL SPIKE"


func _focus_index(map: Control, index: int, message: String) -> void:
	var run: RunState = map.get("_run") as RunState
	var positions: Array[Vector3] = map.get("_positions")
	run.board_position = index
	map.call("_place_player_immediately", index)
	map.call("_update_hud")
	map.get_node("%CameraRig").call("focus_navigation", index, positions, 0.0)
	(map.get("_event_label") as Label).text = message

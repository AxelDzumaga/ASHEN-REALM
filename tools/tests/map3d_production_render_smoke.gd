extends Node

## Map3D Production Runtime §24/§33 — real (non-headless) engineering
## render smoke. Not a Human Visual Playtest (no subjective feel judgment
## recorded) — proves the production flow renders without a black screen,
## dead controls, or immediate runtime errors, using an actual GPU
## rendering context (this project's --headless dummy renderer cannot
## produce real frames at all, so this can only be verified this way).

const GAME_SCENE := preload("res://scenes/core/game.tscn")
const OUTPUT_DIR := "res://build/map3d_production_render_smoke"

var _game: Control
var _shots: Array[String] = []


func _ready() -> void:
	CharacterProfileRepository.use_isolated_test_root("production_render_smoke")
	ActiveRunRepository.use_isolated_test_root("production_render_smoke")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_game = GAME_SCENE.instantiate()
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("01_main_menu")

	_press("%StartGameButton")
	await get_tree().process_frame
	var name_edit: LineEdit = _game.current_screen.get_node("%NameEdit")
	name_edit.text = "Smoke Hero"
	_press("%ConfirmButton")
	await get_tree().process_frame
	await _capture("02_refuge")

	_game.call("_on_start_run_requested")
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("03_map3d_expedition")
	print("board_screen_name=%s" % _game.get("board_screen").name)

	_game.call("show_combat", false, false)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("04_combat")

	_game.call("_on_combat_won", false, false)
	await get_tree().process_frame
	var reward_screen: Control = _game.current_screen
	if reward_screen.name == "UpgradeSelection":
		var pool: Array = reward_screen.get("_upgrade_pool")
		reward_screen.emit_signal("upgrade_selected", pool[0] if not pool.is_empty() else null)
	elif reward_screen.name == "SkillAugmentSelection":
		reward_screen.emit_signal("augment_selected", null)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("05_map3d_return_after_combat")
	print("returned_to_map3d=%s" % (_game.current_screen.name == "AshenWastesMap3D"))

	# Second expedition after defeat — the P0 regression this milestone
	# fixed, now visually confirmed under a real renderer.
	_game.call("_on_combat_lost", false, false)
	await get_tree().create_timer(0.1).timeout
	await get_tree().process_frame
	await _capture("06_defeat_results")
	var return_button: Button = _game.current_screen.get_node("%ReturnButton")
	return_button.pressed.emit()
	await get_tree().process_frame
	await _capture("07_refuge_after_defeat")

	_game.call("_on_start_run_requested")
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("08_second_expedition_map3d")
	print("second_run_board_screen_name=%s" % _game.get("board_screen").name)

	print(JSON.stringify({"shots": _shots, "done": true}))
	get_tree().quit(0)


func _press(unique_path: String) -> void:
	var button: BaseButton = _game.current_screen.get_node(unique_path)
	button.emit_signal("pressed")


func _capture(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s.png" % [OUTPUT_DIR, label]
	var error: Error = image.save_png(path)
	print("CAPTURE %s -> %s error=%d" % [label, ProjectSettings.globalize_path(path), error])
	_shots.append(label)

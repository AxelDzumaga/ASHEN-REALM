extends Node

const BOARD_2D_SCENE := preload("res://scenes/board/board.tscn")
const MAP_3D_SCENE := preload("res://scenes/board3d/ashen_wastes_map_3d.tscn")
const SandboxSource = preload("res://scripts/board3d/map_sandbox_context.gd")
const ControllerSource = preload("res://scripts/board/board_turn_controller.gd")
const FeatureFlagsSource = preload("res://scripts/core/feature_flags.gd")


func _ready() -> void:
	var failures: Array[String] = []
	var shared_run: RunState = SandboxSource.create_run()
	RunManager.current_run = shared_run
	var board_2d: Control = BOARD_2D_SCENE.instantiate()
	add_child(board_2d)
	await get_tree().process_frame
	var map_3d: Control = MAP_3D_SCENE.instantiate()
	add_child(map_3d)
	await get_tree().process_frame
	await get_tree().process_frame

	var board_2d_types: Array[int] = board_2d.get("_tile_types")
	var map_3d_run: RunState = map_3d.get("_run") as RunState
	var map_3d_tiles: Array = map_3d.get("_tiles")
	_check(failures, "same_run_instance", map_3d_run == shared_run)
	_check(failures, "same_seed", map_3d_run.board_seed == shared_run.board_seed)
	_check(failures, "same_board_sequence", board_2d_types == map_3d_run.board_tile_sequence)
	_check(failures, "both_render_30", board_2d.get("_tile_controls").size() == 30 and map_3d_tiles.size() == 30)
	_check(failures, "same_start", shared_run.board_position == 0)
	_check(failures, "same_boss", board_2d_types[29] == BoardTileData.TileType.BOSS)

	var run_2d: RunState = SandboxSource.create_run()
	var run_3d: RunState = SandboxSource.create_run()
	var controller_2d: RefCounted = ControllerSource.new(run_2d, run_2d.board_tile_sequence, DiceRoller.new())
	var controller_3d: RefCounted = ControllerSource.new(run_3d, run_3d.board_tile_sequence, DiceRoller.new())
	var plan_2d: Dictionary = controller_2d.request_roll(4)
	var plan_3d: Dictionary = controller_3d.request_roll(4)
	_check(failures, "same_roll", plan_2d.get("roll") == plan_3d.get("roll"))
	_check(failures, "same_destinations", plan_2d.get("destinations") == plan_3d.get("destinations"))
	var destinations: Array = plan_2d.get("destinations", [])
	var destination: int = int(destinations[0])
	if destinations.size() == 2:
		controller_2d.choose_destination(destination)
		controller_3d.choose_destination(destination)
	while controller_2d.has_pending_steps():
		controller_2d.advance_one_step()
		controller_3d.advance_one_step()
	var resolution_2d: Dictionary = controller_2d.request_tile_resolution()
	var resolution_3d: Dictionary = controller_3d.request_tile_resolution()
	_check(failures, "same_final_position", run_2d.board_position == run_3d.board_position)
	_check(failures, "same_resolution_request", resolution_2d == resolution_3d)
	# Map3D Production Runtime §2: Map3D is now the production default.
	_check(failures, "feature_flag_production_default", FeatureFlagsSource.USE_3D_BOARD)

	print(JSON.stringify({
		"failures": failures,
		"seed": shared_run.board_seed,
		"positions": board_2d_types.size(),
		"roll": plan_2d.get("roll"),
		"destinations": destinations,
		"final_position": run_2d.board_position,
		"resolution": resolution_2d,
		"same_domain_controller": true,
	}))
	board_2d.queue_free()
	map_3d.queue_free()
	RunManager.current_run = null
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(failures: Array[String], key: String, passed: bool) -> void:
	if not passed:
		failures.append(key)

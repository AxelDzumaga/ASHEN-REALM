extends Node

## Map3D Production Runtime §12/§13 — Active Run resume must land in
## production Map3D specifically (not just "some board"), with the exact
## checkpointed state (run_id, board_position, HP, biome) intact, and a
## resumed ROUTE_DECISION_PENDING checkpoint must reopen the same fork
## through Map3D's own _handle_fork_pause() — the same shared
## BoardTurnController mechanism Board2D uses, not a duplicate.

const GAME_SCENE := preload("res://scenes/core/game.tscn")
const BoardTurnControllerSource = preload("res://scripts/board/board_turn_controller.gd")
const RouteBranchDataSource = preload("res://scripts/board/route_branch_data.gd")

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	await _test_on_board_resume_opens_map3d_with_matching_state()
	await _test_route_decision_resume_opens_map3d_with_same_fork()
	await _test_a_b_characters_resume_independently_into_map3d()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _boot_game() -> Control:
	var game: Control = GAME_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	return game


func _press(game: Control, unique_path: String) -> void:
	var button: BaseButton = game.current_screen.get_node(unique_path)
	button.emit_signal("pressed")


func _create_character(game: Control, name: String) -> void:
	_press(game, "%StartGameButton")
	await get_tree().process_frame
	var name_edit: LineEdit = game.current_screen.get_node("%NameEdit")
	name_edit.text = name
	_press(game, "%ConfirmButton")
	await get_tree().process_frame


func _test_on_board_resume_opens_map3d_with_matching_state() -> void:
	CharacterProfileRepository.use_isolated_test_root("production_resume_on_board")
	ActiveRunRepository.use_isolated_test_root("production_resume_on_board")
	var game_a: Control = await _boot_game()
	await _create_character(game_a, "OnBoard Hero")
	game_a.call("_on_start_run_requested")
	await get_tree().process_frame
	_check("on_board_first_opens_map3d", game_a.current_screen.name == "AshenWastesMap3D")

	var run: RunState = RunManager.current_run
	var character_id: String = CharacterProfileRepository.selected_character_id
	run.board_position = mini(run.board_position + 3, run.board_tile_sequence.size() - 2)
	run.current_health = maxi(1, run.current_health - 17)
	ActiveRunRepository.checkpoint(character_id, run, ActiveRunRepository.PHASE_ON_BOARD, "test_advance")
	var checkpointed_run_id: String = run.run_id
	var checkpointed_position: int = run.board_position
	var checkpointed_health: int = run.current_health
	var checkpointed_biome: StringName = run.biome_id
	game_a.queue_free()
	await get_tree().process_frame

	var game_b: Control = await _boot_game()
	var start_button: Button = game_b.current_screen.get_node("%StartGameButton")
	_check("on_board_shows_continue_expedition", start_button.text == "CONTINUAR EXPEDICIÓN")
	start_button.emit_signal("pressed")
	await get_tree().process_frame
	_check("on_board_resume_opens_map3d", game_b.current_screen.name == "AshenWastesMap3D")
	var board: Control = game_b.get("board_screen")
	_check("on_board_resume_not_sandbox", not bool(board.get("_sandbox_mode")))
	var resumed_run: RunState = RunManager.current_run
	_check("on_board_run_id_matches", resumed_run.run_id == checkpointed_run_id)
	_check("on_board_position_matches", resumed_run.board_position == checkpointed_position)
	_check("on_board_health_matches", resumed_run.current_health == checkpointed_health)
	_check("on_board_biome_matches", resumed_run.biome_id == checkpointed_biome)
	_check("on_board_map3d_run_identity_matches", board.get("_run") == resumed_run)

	game_b.queue_free()
	await get_tree().process_frame


func _test_route_decision_resume_opens_map3d_with_same_fork() -> void:
	CharacterProfileRepository.use_isolated_test_root("production_resume_route_decision")
	ActiveRunRepository.use_isolated_test_root("production_resume_route_decision")
	var game_a: Control = await _boot_game()
	await _create_character(game_a, "Fork Hero")
	game_a.call("_on_start_run_requested")
	await get_tree().process_frame

	var run: RunState = RunManager.current_run
	var character_id: String = CharacterProfileRepository.selected_character_id
	var fork_index: int = 4
	var route_a: Array[int] = [BoardTileData.TileType.COMBAT, BoardTileData.TileType.COMBAT, BoardTileData.TileType.TREASURE, BoardTileData.TileType.HEAL, BoardTileData.TileType.EMPTY, BoardTileData.TileType.EMPTY]
	var route_b: Array[int] = [BoardTileData.TileType.EVENT, BoardTileData.TileType.HEAL, BoardTileData.TileType.EMPTY, BoardTileData.TileType.TREASURE, BoardTileData.TileType.EMPTY, BoardTileData.TileType.EMPTY]
	# Clear any fork(s) real board generation happened to place elsewhere
	# on this seed — this test wants exactly one, deterministic fork.
	run.route_branches.clear()
	run.route_branches[fork_index] = RouteBranchDataSource.new(fork_index, route_a, route_b, &"combat", &"recovery")
	# _detect_resumed_fork_pause() (shared BoardTurnController resume logic)
	# requires the spine's own tile type at this position to genuinely be
	# FORK — route_branches alone isn't enough, matching what a real
	# generated board looks like at a fork.
	run.board_tile_sequence[fork_index] = BoardTileData.TileType.FORK
	run.board_position = fork_index
	run.active_branch = RouteBranchDataSource.NONE
	ActiveRunRepository.checkpoint(character_id, run, ActiveRunRepository.PHASE_ROUTE_DECISION_PENDING, "test_fork_reached")
	var checkpointed_run_id: String = run.run_id
	game_a.queue_free()
	await get_tree().process_frame

	var game_b: Control = await _boot_game()
	var start_button: Button = game_b.current_screen.get_node("%StartGameButton")
	start_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("route_decision_resume_opens_map3d", game_b.current_screen.name == "AshenWastesMap3D")
	var board: Control = game_b.get("board_screen")
	var controller: RefCounted = board.get("_turn_controller")
	_check("route_decision_controller_reopened_same_fork", int(controller.get("state")) == BoardTurnControllerSource.State.ROUTE_DECISION)
	_check("route_decision_pending_fork_index_matches", int(controller.get("_pending_fork_index")) == fork_index)
	_check("route_decision_run_id_matches", RunManager.current_run.run_id == checkpointed_run_id)

	# Resolve the reopened choice through the real UI signal, proving the
	# resumed pause isn't just internally flagged but actually answers.
	var hud_layer: CanvasLayer = board.get_node("HUDLayer")
	var branch_overlay: Node = hud_layer.get_node_or_null("BranchChoiceOverlay")
	_check("route_decision_choice_overlay_visible", branch_overlay != null)
	board.emit_signal("branch_choice_selected", RouteBranchDataSource.ROUTE_A)
	await get_tree().process_frame
	_check("route_decision_resolves_active_branch", RunManager.current_run.active_branch == RouteBranchDataSource.ROUTE_A)

	game_b.queue_free()
	await get_tree().process_frame


## §16 — two characters, each with an independent checkpointed active run,
## must each resume into production Map3D showing ITS OWN state, never the
## sibling's. active_run_multi_character_test.gd already proves this at the
## repository layer; this proves it through the real presentation.
func _test_a_b_characters_resume_independently_into_map3d() -> void:
	CharacterProfileRepository.use_isolated_test_root("production_resume_multi")
	ActiveRunRepository.use_isolated_test_root("production_resume_multi")
	var game: Control = await _boot_game()
	await _create_character(game, "Hero A")
	game.call("_on_start_run_requested")
	await get_tree().process_frame
	var character_a: String = CharacterProfileRepository.selected_character_id
	var run_a: RunState = RunManager.current_run
	run_a.board_position = 5
	ActiveRunRepository.checkpoint(character_a, run_a, ActiveRunRepository.PHASE_ON_BOARD, "test_a_advance")
	var run_a_id: String = run_a.run_id

	game.call("show_main_menu")
	await get_tree().process_frame
	game.call("show_character_create")
	await get_tree().process_frame
	var name_edit: LineEdit = game.current_screen.get_node("%NameEdit")
	name_edit.text = "Hero B"
	_press(game, "%ConfirmButton")
	await get_tree().process_frame
	var character_b: String = CharacterProfileRepository.selected_character_id
	_check("multi_characters_distinct_ids", character_a != character_b)
	game.call("_on_start_run_requested")
	await get_tree().process_frame
	var run_b: RunState = RunManager.current_run
	run_b.board_position = 11
	ActiveRunRepository.checkpoint(character_b, run_b, ActiveRunRepository.PHASE_ON_BOARD, "test_b_advance")
	var run_b_id: String = run_b.run_id
	_check("multi_run_ids_distinct", run_a_id != run_b_id)
	game.queue_free()
	await get_tree().process_frame

	# Resume A: fresh instance, explicit selection.
	var game_a: Control = await _boot_game()
	game_a.call("_enter_character", character_a)
	await get_tree().process_frame
	_check("multi_a_resumes_map3d", game_a.current_screen.name == "AshenWastesMap3D")
	_check("multi_a_run_id_matches", RunManager.current_run.run_id == run_a_id)
	_check("multi_a_position_matches", RunManager.current_run.board_position == 5)
	game_a.queue_free()
	await get_tree().process_frame

	# Resume B: separate fresh instance, must show ITS OWN state, not A's.
	var game_b: Control = await _boot_game()
	game_b.call("_enter_character", character_b)
	await get_tree().process_frame
	_check("multi_b_resumes_map3d", game_b.current_screen.name == "AshenWastesMap3D")
	_check("multi_b_run_id_matches", RunManager.current_run.run_id == run_b_id)
	_check("multi_b_position_matches", RunManager.current_run.board_position == 11)
	_check("multi_b_did_not_inherit_a_state", RunManager.current_run.run_id != run_a_id)
	game_b.queue_free()
	await get_tree().process_frame

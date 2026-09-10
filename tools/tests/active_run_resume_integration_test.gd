extends Node

## End-to-end Active Run Persistence resume, driven through the REAL
## game.tscn (not just the domain layer in isolation) — catches wiring
## mistakes a unit test can't. Simulates "app restart" by instantiating a
## brand new game.tscn tree against the same isolated on-disk state,
## never by re-reading the same in-memory objects.

const GAME_SCENE := preload("res://scenes/core/game.tscn")

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	CharacterProfileRepository.use_isolated_test_root("resume_integration")
	ActiveRunRepository.use_isolated_test_root("resume_integration")
	await _test_board_resume_shows_continue_expedition()
	await _test_terminal_resume_shows_results()
	await _test_abandon_deletes_active_run()
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


func _test_board_resume_shows_continue_expedition() -> void:
	var game_a: Control = await _boot_game()
	_press(game_a, "%StartGameButton")  # 0 characters -> character creation
	await get_tree().process_frame
	var name_edit: LineEdit = game_a.current_screen.get_node("%NameEdit")
	name_edit.text = "Resume Hero"
	_press(game_a, "%ConfirmButton")
	await get_tree().process_frame
	_check("create_enters_lobby", game_a.current_screen.name == "Lobby")

	game_a.call("_on_start_run_requested")
	await get_tree().process_frame
	_check("starting_run_shows_board", game_a.current_screen.name in ["Board", "AshenWastesMap3D"])
	var character_id: String = CharacterProfileRepository.selected_character_id
	_check("active_run_exists_after_start", ActiveRunRepository.has_active_run(character_id))

	# Move a few tiles so board_position advances past 0 — proves the
	# resumed state reflects real checkpointed progress, not just the
	# CREATE checkpoint's initial position.
	var run: RunState = RunManager.current_run
	var original_position: int = run.board_position
	run.board_position = mini(run.board_position + 3, run.board_tile_sequence.size() - 2)
	ActiveRunRepository.checkpoint(character_id, run, ActiveRunRepository.PHASE_ON_BOARD, "test_advance")
	_check("checkpoint_after_manual_advance_differs_from_start", run.board_position != original_position)

	game_a.queue_free()
	await get_tree().process_frame

	# "App restart": a brand new game.tscn instance, same on-disk isolated
	# state, same character.
	var game_b: Control = await _boot_game()
	_check("boots_to_main_menu_again", game_b.current_screen.name == "MainMenu")
	var start_button: Button = game_b.current_screen.get_node("%StartGameButton")
	_check("main_menu_shows_continue_expedition", start_button.text == "CONTINUAR EXPEDICIÓN")
	start_button.emit_signal("pressed")
	await get_tree().process_frame
	_check("resumed_shows_board", game_b.current_screen.name in ["Board", "AshenWastesMap3D"])
	_check("resumed_board_position_matches_checkpoint", RunManager.current_run.board_position == run.board_position)
	_check("resumed_run_id_matches", RunManager.current_run.run_id == run.run_id)

	game_b.queue_free()
	await get_tree().process_frame


func _test_terminal_resume_shows_results() -> void:
	CharacterProfileRepository.use_isolated_test_root("resume_integration_terminal")
	ActiveRunRepository.use_isolated_test_root("resume_integration_terminal")
	var game_a: Control = await _boot_game()
	_press(game_a, "%StartGameButton")
	await get_tree().process_frame
	var name_edit: LineEdit = game_a.current_screen.get_node("%NameEdit")
	name_edit.text = "Terminal Hero"
	_press(game_a, "%ConfirmButton")
	await get_tree().process_frame
	game_a.call("_on_start_run_requested")
	await get_tree().process_frame
	var character_id: String = CharacterProfileRepository.selected_character_id
	var run: RunState = RunManager.current_run
	run.run_completed = true
	run.loot_rolled = true
	run.boss_reward_applied = true
	ActiveRunRepository.checkpoint(character_id, run, ActiveRunRepository.PHASE_RUN_COMPLETE_PENDING_DEPOSIT, "test_terminal", true)
	game_a.queue_free()
	await get_tree().process_frame

	var game_b: Control = await _boot_game()
	var start_button: Button = game_b.current_screen.get_node("%StartGameButton")
	start_button.emit_signal("pressed")
	await get_tree().process_frame
	_check("terminal_resume_shows_run_result", game_b.current_screen.name == "RunResult")
	_check("terminal_resume_deposits_reward", SaveManager.profile.total_ash > 0 or SaveManager.profile.total_victories > 0)
	_check("terminal_resume_run_id_matches_deposit_marker", SaveManager.profile.last_deposited_run_id == run.run_id)
	game_b.queue_free()
	await get_tree().process_frame


func _test_abandon_deletes_active_run() -> void:
	CharacterProfileRepository.use_isolated_test_root("resume_integration_abandon")
	ActiveRunRepository.use_isolated_test_root("resume_integration_abandon")
	var game_a: Control = await _boot_game()
	_press(game_a, "%StartGameButton")
	await get_tree().process_frame
	var name_edit: LineEdit = game_a.current_screen.get_node("%NameEdit")
	name_edit.text = "Abandon Hero"
	_press(game_a, "%ConfirmButton")
	await get_tree().process_frame
	game_a.call("_on_start_run_requested")
	await get_tree().process_frame
	var character_id: String = CharacterProfileRepository.selected_character_id
	_check("abandon_test_has_active_run_before", ActiveRunRepository.has_active_run(character_id))

	game_a.call("_confirm_abandon")
	await get_tree().process_frame
	_check("abandon_deletes_active_run", not ActiveRunRepository.has_active_run(character_id))
	_check("abandon_returns_to_lobby", game_a.current_screen.name == "Lobby")
	_check("abandon_did_not_touch_permanent_profile", SaveManager.profile.total_ash == 0)
	game_a.queue_free()
	await get_tree().process_frame

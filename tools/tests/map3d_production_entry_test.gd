extends Node

## Map3D Production Runtime §10/§11/§28/§29 — the P0 regression lock.
##
## Drives the REAL production flow (character creation -> Refuge -> Start
## Expedition), never --map3d-prototype, and proves:
##  - a fresh expedition opens Map3D (not Board2D);
##  - Map3D consumes RunManager.current_run, never MapSandboxContext;
##  - a SECOND expedition, started after either a defeat or a boss
##    victory sends the player back through Refuge, ALSO opens Map3D.
##
## This last point is the exact reproduction of the previously-observed
## bug: show_board()'s selector used to OR in the ephemeral
## _map3d_prototype_mode flag, which show_lobby()/show_main_menu() clear on
## every menu transition — a defeat's "Refuge -> start again" sequence
## could silently fall back to Board2D. The fix (show_board() now reads
## FeatureFlags.USE_3D_BOARD alone) is regression-locked here.

const GAME_SCENE := preload("res://scenes/core/game.tscn")

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	await _test_fresh_expedition_opens_map3d_with_real_run()
	await _test_second_expedition_after_defeat_opens_map3d()
	await _test_second_expedition_after_boss_victory_opens_map3d()
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


func _create_character_and_reach_lobby(game: Control, name: String) -> void:
	_press(game, "%StartGameButton")
	await get_tree().process_frame
	var name_edit: LineEdit = game.current_screen.get_node("%NameEdit")
	name_edit.text = name
	_press(game, "%ConfirmButton")
	await get_tree().process_frame


func _test_fresh_expedition_opens_map3d_with_real_run() -> void:
	CharacterProfileRepository.use_isolated_test_root("production_entry_fresh")
	ActiveRunRepository.use_isolated_test_root("production_entry_fresh")
	var game: Control = await _boot_game()
	await _create_character_and_reach_lobby(game, "Fresh Hero")
	_check("fresh_no_prototype_arg_needed", not ("--map3d-prototype" in OS.get_cmdline_user_args()))

	game.call("_on_start_run_requested")
	await get_tree().process_frame
	_check("fresh_run_opens_map3d", game.current_screen.name == "AshenWastesMap3D")
	var board: Control = game.get("board_screen")
	var run_on_screen: RunState = board.get("_run")
	_check("fresh_map3d_uses_run_manager_current_run", run_on_screen == RunManager.current_run)
	_check("fresh_run_not_sandbox_context", not bool(board.get("_sandbox_mode")))
	_check("fresh_active_run_checkpointed", ActiveRunRepository.has_active_run(CharacterProfileRepository.selected_character_id))

	game.queue_free()
	await get_tree().process_frame


func _test_second_expedition_after_defeat_opens_map3d() -> void:
	CharacterProfileRepository.use_isolated_test_root("production_entry_second_defeat")
	ActiveRunRepository.use_isolated_test_root("production_entry_second_defeat")
	var game: Control = await _boot_game()
	await _create_character_and_reach_lobby(game, "Defeat Hero")

	game.call("_on_start_run_requested")
	await get_tree().process_frame
	_check("defeat_first_run_opens_map3d", game.current_screen.name == "AshenWastesMap3D")
	var first_run: RunState = RunManager.current_run

	game.call("_on_combat_lost", false, false)
	await get_tree().create_timer(0.1).timeout
	await get_tree().process_frame
	_check("defeat_reaches_results", game.current_screen.name == "RunResult")

	# "Return to Refuge" via the real RETURN button — this is exactly the
	# menu transition that used to silently disarm Map3D selection.
	# RunResult._on_return_button_pressed() (not game.gd's downstream
	# handler) is what deletes the active run, letting the next
	# start_new_run() checkpoint cleanly.
	var return_button: Button = game.current_screen.get_node("%ReturnButton")
	return_button.pressed.emit()
	await get_tree().process_frame
	_check("defeat_returns_to_lobby", game.current_screen.name == "Lobby")

	game.call("_on_start_run_requested")
	await get_tree().process_frame
	_check("defeat_second_run_opens_map3d", game.current_screen.name == "AshenWastesMap3D")
	_check("defeat_second_run_is_new_run_instance", RunManager.current_run != first_run)
	var second_board: Control = game.get("board_screen")
	_check("defeat_second_map3d_uses_real_run", second_board.get("_run") == RunManager.current_run and not bool(second_board.get("_sandbox_mode")))

	game.queue_free()
	await get_tree().process_frame


func _test_second_expedition_after_boss_victory_opens_map3d() -> void:
	CharacterProfileRepository.use_isolated_test_root("production_entry_second_victory")
	ActiveRunRepository.use_isolated_test_root("production_entry_second_victory")
	var game: Control = await _boot_game()
	await _create_character_and_reach_lobby(game, "Victory Hero")

	game.call("_on_start_run_requested")
	await get_tree().process_frame
	_check("victory_first_run_opens_map3d", game.current_screen.name == "AshenWastesMap3D")

	game.call("show_combat", true, false)
	await get_tree().process_frame
	game.call("_on_combat_won", true, false)
	await get_tree().process_frame
	_check("victory_reaches_boss_reward", game.current_screen.name == "BossReward")
	# Press the real reward button (BossRewardCatalog.apply() is what sets
	# boss_reward_applied — calling _on_boss_reward_selected() directly
	# with a null reward skips that and RunResult's _ready() then rejects
	# the run as invalid).
	var reward_buttons: Array = game.current_screen.get("_buttons")
	(reward_buttons[0] as Button).pressed.emit()
	await get_tree().create_timer(0.85).timeout
	await get_tree().process_frame
	_check("victory_reaches_results", game.current_screen.name == "RunResult")

	# Press the real RETURN button — RunResult._on_return_button_pressed()
	# is what deletes the active run before emitting
	# return_to_lobby_requested; calling game.gd's downstream handler
	# directly (as this test previously did) skipped that deletion and
	# left the next start_new_run() unable to checkpoint.
	var return_button: Button = game.current_screen.get_node("%ReturnButton")
	return_button.pressed.emit()
	await get_tree().process_frame
	_check("victory_returns_to_lobby", game.current_screen.name == "Lobby")

	game.call("_on_start_run_requested")
	await get_tree().process_frame
	_check("victory_second_run_opens_map3d", game.current_screen.name == "AshenWastesMap3D")

	game.queue_free()
	await get_tree().process_frame

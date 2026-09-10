extends Node

## §4 of the merge-gate hardening pass: an explicit, dedicated assertion
## (not just an inference from the previous report's reasoning) that
## RUN_COMPLETE_PENDING_DEPOSIT has no reachable ABANDONAR PARTIDA route,
## and that resuming that phase goes to deposit/Results, never a
## gameplay replay.

const GAME_SCENE := preload("res://scenes/core/game.tscn")

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	await _test_terminal_screen_has_no_pause_route()
	await _test_resume_terminal_goes_to_results_not_gameplay()
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


func _test_terminal_screen_has_no_pause_route() -> void:
	CharacterProfileRepository.use_isolated_test_root("terminal_abandon")
	ActiveRunRepository.use_isolated_test_root("terminal_abandon")
	var game: Control = await _boot_game()
	_press(game, "%StartGameButton")
	await get_tree().process_frame
	var name_edit: LineEdit = game.current_screen.get_node("%NameEdit")
	name_edit.text = "Terminal Abandon Hero"
	_press(game, "%ConfirmButton")
	await get_tree().process_frame
	game.call("_on_start_run_requested")
	await get_tree().process_frame

	# Reach RUN_COMPLETE_PENDING_DEPOSIT the same way a real defeat does.
	game.call("_on_combat_lost", false, false)
	await get_tree().process_frame

	_check("terminal_screen_is_run_result", game.current_screen.name == "RunResult")
	# _open_pause() (which alone can reach _show_abandon_confirmation() /
	# _confirm_abandon()) is only ever invoked via a board screen's
	# pause_requested signal (_connect_board_screen()). RunResult defines
	# no such signal at all — structurally, nothing on this screen can
	# open the pause menu, let alone abandon.
	_check("run_result_has_no_pause_requested_signal", not game.current_screen.has_signal("pause_requested"))
	# game.gd's own pause overlay must not be visible/active while on
	# this screen either.
	var pause_overlay: Control = game.get("pause_overlay")
	var pause_overlay_visible: bool = pause_overlay != null and pause_overlay.visible
	_check("pause_overlay_not_visible_on_terminal_screen", not pause_overlay_visible)

	var character_id: String = CharacterProfileRepository.selected_character_id
	var loaded: Dictionary = ActiveRunRepository.load_active_run(character_id)
	_check("checkpoint_still_pending_deposit_phase", String(loaded.get("phase", "")) == ActiveRunRepository.PHASE_RUN_COMPLETE_PENDING_DEPOSIT)
	game.queue_free()
	await get_tree().process_frame


func _test_resume_terminal_goes_to_results_not_gameplay() -> void:
	CharacterProfileRepository.use_isolated_test_root("terminal_abandon_resume")
	ActiveRunRepository.use_isolated_test_root("terminal_abandon_resume")
	var game_a: Control = await _boot_game()
	_press(game_a, "%StartGameButton")
	await get_tree().process_frame
	var name_edit: LineEdit = game_a.current_screen.get_node("%NameEdit")
	name_edit.text = "Terminal Resume Hero"
	_press(game_a, "%ConfirmButton")
	await get_tree().process_frame
	game_a.call("_on_start_run_requested")
	await get_tree().process_frame
	game_a.call("_on_combat_lost", false, false)
	await get_tree().process_frame
	game_a.queue_free()
	await get_tree().process_frame

	var game_b: Control = await _boot_game()
	var start_button: Button = game_b.current_screen.get_node("%StartGameButton")
	start_button.emit_signal("pressed")
	await get_tree().process_frame
	_check("resume_goes_to_results_not_board", game_b.current_screen.name == "RunResult")
	_check("resume_deposits_not_replays", RunManager.current_run.rewards_deposited)
	game_b.queue_free()
	await get_tree().process_frame

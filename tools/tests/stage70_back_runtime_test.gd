extends Node

const GAME_SCENE := preload("res://scenes/core/game.tscn")


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"stage70_back_runtime")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	var game := GAME_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame

	var ash_before: int = SaveManager.profile.total_ash
	RunManager.current_run = RunState.new()
	RunManager.current_run.run_ash = 99
	RunManager.current_run.rewards_deposited = true
	game.current_screen.name = "RunResult"

	var back := InputEventAction.new()
	back.action = &"ui_cancel"
	back.pressed = true
	game._unhandled_input(back)
	await get_tree().process_frame
	await get_tree().process_frame

	var checks := {
		"results_back_returns_to_lobby": is_instance_valid(game.current_screen) and game.current_screen.name == "Lobby",
		"results_back_ends_finished_run": not RunManager.has_active_run(),
		"results_back_does_not_deposit_again": SaveManager.profile.total_ash == ash_before,
		"pause_overlay_not_open": not game.pause_overlay.visible,
	}
	var failures: Array[String] = []
	for check_name: String in checks:
		if not bool(checks[check_name]):
			failures.append(check_name)
	print(JSON.stringify({"schema": 1, "checks": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)

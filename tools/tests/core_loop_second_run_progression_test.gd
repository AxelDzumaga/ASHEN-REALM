extends Node

## Core Loop / Final Reward §35 — Run #1 defeats the Warden (unlocking
## Ember Marsh, depositing permanent progression), Run #2 starts fresh:
## proves run-scoped state (run_id, run_level, boons/augments) does not
## leak between runs, permanent ProfileData progression from Run #1 IS
## used by Run #2, and both regions are selectable afterward.

const GAME_SCENE := preload("res://scenes/core/game.tscn")

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	await _test_second_run_progression()
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


func _test_second_run_progression() -> void:
	CharacterProfileRepository.use_isolated_test_root("core_loop_second_run")
	ActiveRunRepository.use_isolated_test_root("core_loop_second_run")
	var game: Control = await _boot_game()
	_press(game, "%StartGameButton")
	await get_tree().process_frame
	var name_edit: LineEdit = game.current_screen.get_node("%NameEdit")
	name_edit.text = "Progression Hero"
	_press(game, "%ConfirmButton")
	await get_tree().process_frame
	game.call("_on_start_run_requested")
	await get_tree().process_frame

	var run_1: RunState = RunManager.current_run
	var run_1_id: String = run_1.run_id
	# Contaminate Run #1's temporary state on purpose, so leakage into
	# Run #2 (if it happened) would be unmistakable rather than merely
	# "coincidentally still at defaults".
	run_1.active_boons[&"burning_strike"] = 5
	run_1.skill_augments[&"ember_overload"] = 2
	run_1.run_level = 7
	run_1.current_xp = 999
	run_1.upgrade_rerolls = 0
	run_1.run_completed = true
	var player_level_before_run_1: int = SaveManager.profile.player_level
	var total_ash_before_run_1: int = SaveManager.profile.total_ash

	game.call("show_combat", true, false)
	await get_tree().process_frame
	game.call("_on_combat_won", true, false)
	await get_tree().process_frame
	var reward_buttons: Array = game.current_screen.get("_buttons")
	(reward_buttons[0] as Button).pressed.emit()
	await get_tree().create_timer(0.85).timeout
	await get_tree().process_frame
	_check("run_1_reaches_result", game.current_screen.name == "RunResult")
	_check("run_1_deposited", run_1.rewards_deposited)
	_check("ember_marsh_unlocked_after_run_1", BiomeCatalog.is_unlocked(BiomeCatalog.EMBER_MARSH, SaveManager.profile.completed_milestone_ids))
	_check("permanent_ash_increased", SaveManager.profile.total_ash > total_ash_before_run_1)

	var return_button: Button = game.current_screen.get_node("%ReturnButton")
	return_button.pressed.emit()
	await get_tree().process_frame
	_check("returns_to_lobby", game.current_screen.name == "Lobby")

	game.call("_on_start_run_requested")
	await get_tree().process_frame
	var run_2: RunState = RunManager.current_run
	_check("run_2_is_new_instance", run_2 != run_1)
	_check("run_2_has_different_run_id", run_2.run_id != run_1_id)
	_check("run_2_run_level_reset", run_2.run_level == RunLevelConfig.START_LEVEL)
	_check("run_2_current_xp_reset", run_2.current_xp == 0)
	_check("run_2_no_leaked_boons", run_2.active_boons.is_empty())
	_check("run_2_no_leaked_augments", run_2.skill_augments.is_empty())
	_check("run_2_upgrade_rerolls_reset", run_2.upgrade_rerolls == 2)
	_check("run_2_not_completed", not run_2.run_completed)
	_check("run_2_rewards_not_deposited", not run_2.rewards_deposited)

	# Permanent progression from Run #1 IS reflected — apply_permanent_
	# upgrades() (inside start_new_run()) reads the just-updated profile,
	# not a stale snapshot from before Run #1 deposited.
	_check("run_2_reflects_updated_profile_level", SaveManager.profile.player_level >= player_level_before_run_1)

	# Both regions remain selectable — no lockout, no forced redirect.
	_check("ember_marsh_selectable_for_run_2", BiomeCatalog.is_unlocked(BiomeCatalog.EMBER_MARSH, SaveManager.profile.completed_milestone_ids))
	_check("ashen_wastes_selectable_for_run_2", BiomeCatalog.is_unlocked(BiomeCatalog.ASHEN_WASTES, SaveManager.profile.completed_milestone_ids))
	_check("run_2_opens_map3d", game.current_screen.name == "AshenWastesMap3D")

	game.queue_free()
	await get_tree().process_frame

extends Node

## Map3D Production Runtime §15/§16/§17/§18/§21/§22 — proves each return
## path lands back in the SAME production Map3D instance with matching
## RunState identity (not just "a screen named AshenWastesMap3D appeared"),
## and that terminal/abandon paths never produce an intermediate Board2D.

const GAME_SCENE := preload("res://scenes/core/game.tscn")

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	await _test_combat_event_treasure_return_to_same_map3d()
	await _test_elite_reward_return_preserves_tier_and_map3d()
	await _test_boss_victory_goes_to_results_not_board2d()
	await _test_defeat_goes_to_results_not_board2d()
	await _test_abandon_from_map3d_deletes_active_run()
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


## Reward-type (Upgrade vs SkillAugment) is seeded per-run, not fixed —
## resolve whichever one actually opened, exactly as a real player would.
func _resolve_reward_screen(screen: Control) -> void:
	if screen.name == "UpgradeSelection":
		var pool: Array = screen.get("_upgrade_pool")
		screen.emit_signal("upgrade_selected", pool[0] if not pool.is_empty() else null)
	elif screen.name == "SkillAugmentSelection":
		screen.emit_signal("augment_selected", null)


func _create_character_and_start_run(game: Control, name: String) -> void:
	_press(game, "%StartGameButton")
	await get_tree().process_frame
	var name_edit: LineEdit = game.current_screen.get_node("%NameEdit")
	name_edit.text = name
	_press(game, "%ConfirmButton")
	await get_tree().process_frame
	game.call("_on_start_run_requested")
	await get_tree().process_frame


func _test_combat_event_treasure_return_to_same_map3d() -> void:
	CharacterProfileRepository.use_isolated_test_root("production_return_flow")
	ActiveRunRepository.use_isolated_test_root("production_return_flow")
	var game: Control = await _boot_game()
	await _create_character_and_start_run(game, "Return Hero")
	_check("return_flow_starts_on_map3d", game.current_screen.name == "AshenWastesMap3D")
	var original_map: Control = game.get("board_screen")
	var run: RunState = RunManager.current_run
	run.run_level = RunLevelConfig.MAX_RUN_LEVEL

	game.call("show_combat", false, false)
	await get_tree().process_frame
	_check("combat_opens_combat2d", game.current_screen.name == "Combat")
	game.call("_on_combat_won", false, false)
	await get_tree().process_frame
	_resolve_reward_screen(game.current_screen)
	await get_tree().process_frame
	_check("combat_returns_to_same_map3d_instance", game.get("board_screen") == original_map and game.current_screen == original_map)
	_check("combat_return_run_identity_preserved", RunManager.current_run == run)

	game.call("show_event")
	await get_tree().process_frame
	_check("event_opens", game.current_screen.name == "EventScreen")
	game.call("_on_event_resolved")
	await get_tree().process_frame
	_check("event_returns_to_same_map3d_instance", game.get("board_screen") == original_map and game.current_screen == original_map)

	game.call("show_treasure")
	await get_tree().process_frame
	_check("treasure_opens", game.current_screen.name == "TreasureScreen")
	game.call("_on_treasure_continue_requested")
	await get_tree().process_frame
	_check("treasure_returns_to_same_map3d_instance", game.get("board_screen") == original_map and game.current_screen == original_map)
	_check("no_reward_deposit_mid_run", not run.rewards_deposited)

	game.queue_free()
	await get_tree().process_frame


func _test_elite_reward_return_preserves_tier_and_map3d() -> void:
	CharacterProfileRepository.use_isolated_test_root("production_return_elite")
	ActiveRunRepository.use_isolated_test_root("production_return_elite")
	var game: Control = await _boot_game()
	await _create_character_and_start_run(game, "Elite Hero")
	RunManager.current_run.run_level = RunLevelConfig.MAX_RUN_LEVEL
	var original_map: Control = game.get("board_screen")

	game.call("show_combat", false, true)
	await get_tree().process_frame
	game.call("_on_combat_won", false, true)
	await get_tree().process_frame
	_check("elite_pending_reward_marked_elite", RunManager.current_run.pending_reward_is_elite)
	_resolve_reward_screen(game.current_screen)
	await get_tree().process_frame
	_check("elite_reward_returns_to_same_map3d", game.get("board_screen") == original_map and game.current_screen == original_map)
	_check("elite_pending_flag_cleared", not RunManager.current_run.pending_reward_is_elite)

	game.queue_free()
	await get_tree().process_frame


func _test_boss_victory_goes_to_results_not_board2d() -> void:
	CharacterProfileRepository.use_isolated_test_root("production_return_boss")
	ActiveRunRepository.use_isolated_test_root("production_return_boss")
	var game: Control = await _boot_game()
	await _create_character_and_start_run(game, "Boss Hero")

	game.call("show_combat", true, false)
	await get_tree().process_frame
	game.call("_on_combat_won", true, false)
	await get_tree().process_frame
	_check("boss_reward_screen_opens", game.current_screen.name == "BossReward")
	# Press the real reward button — BossRewardCatalog.apply() (called from
	# boss_reward_screen.gd's own press handler) is what sets
	# boss_reward_applied, which RunResult._ready() requires.
	var reward_buttons: Array = game.current_screen.get("_buttons")
	(reward_buttons[0] as Button).pressed.emit()
	await get_tree().create_timer(0.85).timeout
	await get_tree().process_frame
	_check("boss_victory_reaches_results_not_map3d_or_board2d", game.current_screen.name == "RunResult")
	_check("boss_victory_result_is_real_run_result", game.current_screen.name != "Map3DPrototypeResult")

	game.queue_free()
	await get_tree().process_frame


func _test_defeat_goes_to_results_not_board2d() -> void:
	CharacterProfileRepository.use_isolated_test_root("production_return_defeat")
	ActiveRunRepository.use_isolated_test_root("production_return_defeat")
	var game: Control = await _boot_game()
	await _create_character_and_start_run(game, "Falling Hero")

	game.call("_on_combat_lost", false, false)
	await get_tree().create_timer(0.1).timeout
	await get_tree().process_frame
	_check("defeat_reaches_results_not_map3d_or_board2d", game.current_screen.name == "RunResult")
	_check("defeat_board_discarded", game.get("board_screen") == null)

	game.queue_free()
	await get_tree().process_frame


func _test_abandon_from_map3d_deletes_active_run() -> void:
	CharacterProfileRepository.use_isolated_test_root("production_return_abandon")
	ActiveRunRepository.use_isolated_test_root("production_return_abandon")
	var game: Control = await _boot_game()
	await _create_character_and_start_run(game, "Abandon Hero")
	_check("abandon_starts_on_map3d", game.current_screen.name == "AshenWastesMap3D")
	var character_id: String = CharacterProfileRepository.selected_character_id
	_check("abandon_has_active_run_before", ActiveRunRepository.has_active_run(character_id))

	game.call("_confirm_abandon")
	await get_tree().process_frame
	_check("abandon_deletes_active_run", not ActiveRunRepository.has_active_run(character_id))
	_check("abandon_returns_to_lobby", game.current_screen.name == "Lobby")
	_check("abandon_did_not_deposit_permanent_profile", SaveManager.profile.total_ash == 0)

	game.queue_free()
	await get_tree().process_frame

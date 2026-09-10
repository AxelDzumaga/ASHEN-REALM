extends Node

## Live reward-resume, driven through the REAL game.tscn (not a serializer
## round-trip): a combat win leaves a reward screen open, the active run
## is checkpointed, the game instance is destroyed and a new one boots
## against the same on-disk state, and the SAME reward screen — with the
## SAME options and the SAME Normal/Elite tier — must reopen. Fixes the
## P0 gap flagged in the previous report: pending_reward_is_elite is now
## a persisted RunState field, not a game.gd session variable a restart
## could never reconstruct.

const GAME_SCENE := preload("res://scenes/core/game.tscn")

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	await _test_normal_reward_resume()
	await _test_elite_reward_resume()
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


func _reward_screen_signature(screen: Control) -> String:
	if screen.name == "UpgradeSelection":
		return "upgrade:%s:%s" % [str(screen.get("_reward_context")), String(screen.get("_current_signature"))]
	if screen.name == "SkillAugmentSelection":
		# No exposed signature field here (skill augment options don't
		# depend on is_elite at all, per generate_augment_options()'s own
		# signature) — the button set itself is the comparable fingerprint.
		var buttons: Array = screen.get("_buttons")
		var texts: Array[String] = []
		for button: Button in buttons:
			texts.append(button.text)
		return "augment:%s" % ",".join(texts)
	return "unknown:%s" % screen.name


func _resolve_reward_screen(game: Control) -> void:
	# Real-render/live-flow selection: emit the same signal a real card
	# press eventually emits (bypassing only the cosmetic confirmation
	# delay timer), so game.gd's actual _on_upgrade_selected/
	# _on_skill_augment_selected handlers run for real.
	var screen: Control = game.current_screen
	if screen.name == "UpgradeSelection":
		var pool: Array = screen.get("_upgrade_pool")
		screen.emit_signal("upgrade_selected", pool[0] if not pool.is_empty() else null)
	elif screen.name == "SkillAugmentSelection":
		screen.emit_signal("augment_selected", null)


func _run_scenario(character_name: String, test_root: String, is_elite: bool, prefix: String) -> void:
	CharacterProfileRepository.use_isolated_test_root(test_root)
	ActiveRunRepository.use_isolated_test_root(test_root)

	var game_a: Control = await _boot_game()
	_press(game_a, "%StartGameButton")
	await get_tree().process_frame
	var name_edit: LineEdit = game_a.current_screen.get_node("%NameEdit")
	name_edit.text = character_name
	_press(game_a, "%ConfirmButton")
	await get_tree().process_frame
	game_a.call("_on_start_run_requested")
	await get_tree().process_frame

	# Pin the run level at its cap so add_run_xp() inside _on_combat_won()
	# cannot grant a level-up — that is a separate, already-tested resume
	# path (show_level_up_selection()); this test isolates specifically
	# the Normal/Elite build-reward tier, not the level-up cascade.
	RunManager.current_run.run_level = RunLevelConfig.MAX_RUN_LEVEL

	# Simulate "win" exactly as the real Combat scene's combat_won signal
	# would trigger it — the actual production handler, not a mock.
	game_a.call("_on_combat_won", false, is_elite)
	await get_tree().process_frame

	var screen_name_a: String = game_a.current_screen.name
	_check("%s_reward_screen_opened" % prefix, screen_name_a in ["UpgradeSelection", "SkillAugmentSelection"])
	var signature_a: String = _reward_screen_signature(game_a.current_screen)
	var run: RunState = RunManager.current_run
	_check("%s_pending_reward_is_elite_matches_combat" % prefix, run.pending_reward_is_elite == is_elite)
	var character_id: String = CharacterProfileRepository.selected_character_id
	_check("%s_active_run_checkpointed_reward_pending" % prefix, ActiveRunRepository.has_active_run(character_id))

	game_a.queue_free()
	await get_tree().process_frame

	# "App restart".
	var game_b: Control = await _boot_game()
	var start_button: Button = game_b.current_screen.get_node("%StartGameButton")
	_check("%s_shows_continue_expedition" % prefix, start_button.text == "CONTINUAR EXPEDICIÓN")
	start_button.emit_signal("pressed")
	await get_tree().process_frame

	var screen_name_b: String = game_b.current_screen.name
	_check("%s_resumed_same_screen" % prefix, screen_name_b == screen_name_a)
	var signature_b: String = _reward_screen_signature(game_b.current_screen)
	_check("%s_resumed_same_options_and_tier" % prefix, signature_b == signature_a)

	_resolve_reward_screen(game_b)
	await get_tree().process_frame
	_check("%s_selection_returns_to_board" % prefix, game_b.current_screen.name in ["Board", "AshenWastesMap3D"])
	_check("%s_pending_reward_flag_cleared_after_selection" % prefix, not RunManager.current_run.pending_reward_is_elite)

	game_b.queue_free()
	await get_tree().process_frame

	# Restart once more: with the reward already resolved, resume must
	# NOT reopen a reward screen a second time.
	var game_c: Control = await _boot_game()
	var start_button_c: Button = game_c.current_screen.get_node("%StartGameButton")
	start_button_c.emit_signal("pressed")
	await get_tree().process_frame
	_check("%s_second_restart_does_not_reopen_reward" % prefix, game_c.current_screen.name not in ["UpgradeSelection", "SkillAugmentSelection"])
	game_c.queue_free()
	await get_tree().process_frame


func _test_normal_reward_resume() -> void:
	await _run_scenario("Normal Hero", "reward_resume_normal", false, "normal")


func _test_elite_reward_resume() -> void:
	await _run_scenario("Elite Hero", "reward_resume_elite", true, "elite")

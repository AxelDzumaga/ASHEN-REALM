extends Node

const GAME_SCENE := preload("res://scenes/core/game.tscn")


func _ready() -> void:
	var failures: Array[String] = []
	var game: Control = GAME_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.call("_launch_map3d_prototype")
	# Map3D Production Runtime §6: _launch_map3d_prototype() now isolates
	# SaveManager.profile itself — set tutorial-skip state on the profile
	# it actually isolates to, after the call, not before.
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	await get_tree().process_frame
	await get_tree().process_frame
	var original_map: Control = game.get("board_screen") as Control
	var run: RunState = RunManager.current_run
	_check(failures, "map3d_launched", is_instance_valid(original_map) and original_map.name == "AshenWastesMap3D")
	game.call("_open_pause")
	_check(failures, "pause_hides_map_hud", not original_map.get_node("HUDLayer").visible and game.get("pause_overlay").visible)
	game.call("_close_pause")
	_check(failures, "pause_restores_map_hud", original_map.get_node("HUDLayer").visible and not game.get("pause_overlay").visible)

	game.call("show_combat", false, false)
	await get_tree().process_frame
	_check(failures, "combat2d_opened", game.get("current_screen").name == "Combat")
	_check(failures, "map_preserved_during_combat", is_instance_valid(original_map) and not original_map.visible)
	_check(failures, "map_hud_hidden_during_combat", not original_map.get_node("HUDLayer").visible)
	game.call("_on_combat_won", false, false)
	await get_tree().process_frame
	game.call("_on_upgrade_selected", null)
	await get_tree().process_frame
	_check(failures, "combat_same_map_instance", game.get("board_screen") == original_map and game.get("current_screen") == original_map)
	_check(failures, "combat_resumed", not bool(original_map.get("_interaction_pending")))
	_check(failures, "map_hud_restored_after_combat", original_map.get_node("HUDLayer").visible)

	game.call("show_event")
	await get_tree().process_frame
	_check(failures, "event_opened", game.get("current_screen").name == "EventScreen")
	game.call("_on_event_resolved")
	await get_tree().process_frame
	_check(failures, "event_same_map_instance", game.get("board_screen") == original_map and game.get("current_screen") == original_map)

	game.call("show_treasure")
	await get_tree().process_frame
	_check(failures, "treasure_opened", game.get("current_screen").name == "TreasureScreen")
	game.call("_on_treasure_continue_requested")
	await get_tree().process_frame
	_check(failures, "treasure_same_map_instance", game.get("board_screen") == original_map and game.get("current_screen") == original_map)
	_check(failures, "no_reward_deposit", not run.rewards_deposited)
	_check(failures, "run_instance_preserved", RunManager.current_run == run)

	game.call("show_combat", true, false)
	await get_tree().process_frame
	_check(failures, "boss_combat2d_opened", game.get("current_screen").name == "Combat")
	game.call("_on_combat_won", true, false)
	await get_tree().process_frame
	_check(failures, "boss_reward_existing_flow", game.get("current_screen").name == "BossReward")
	game.call("_on_boss_reward_selected", null)
	await get_tree().process_frame
	_check(failures, "boss_no_map_return", game.get("current_screen").name == "Map3DPrototypeResult")
	_check(failures, "boss_no_reward_deposit", not run.rewards_deposited)

	print(JSON.stringify({
		"failures": failures,
		"same_instance": game.get("board_screen") == original_map,
		"combat_2d": true,
		"event_return": true,
		"treasure_return": true,
		"boss_result_isolated": true,
		"rewards_deposited": run.rewards_deposited,
	}))
	game.queue_free()
	RunManager.current_run = null
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(failures: Array[String], key: String, passed: bool) -> void:
	if not passed:
		failures.append(key)

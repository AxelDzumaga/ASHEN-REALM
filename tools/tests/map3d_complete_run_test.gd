extends Node

const GAME_SCENE := preload("res://scenes/core/game.tscn")
const AdapterSource = preload("res://scripts/board/board_tile_resolution_adapter.gd")


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"map3d_complete_run")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	var failures: Array[String] = []
	var game: Control = GAME_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.call("_launch_map3d_prototype")
	await get_tree().process_frame
	await get_tree().process_frame
	var map: Control = game.get("board_screen") as Control
	var run: RunState = RunManager.current_run
	var controller: RefCounted = map.get("_turn_controller")
	var logical_steps: Array[int] = []
	var interaction_counts := {"combat": 0, "elite": 0, "event": 0, "treasure": 0, "heal": 0, "boss": 0}
	controller.logical_step_emitted.connect(func(_from: int, to: int) -> void: logical_steps.append(to))
	_check(failures, "starts_in_map3d", map.name == "AshenWastesMap3D" and run.board_position == 0)

	var turn_guard := 0
	while run.board_position < 29 and turn_guard < 30:
		turn_guard += 1
		var plan: Dictionary = controller.request_roll(4)
		if plan.is_empty():
			failures.append("turn_plan_empty_%d" % turn_guard)
			break
		var destinations: Array[int] = []
		destinations.assign(plan["destinations"])
		var destination: int = destinations[0]
		if destinations.size() == 2:
			_check(failures, "route_choice_%d" % turn_guard, controller.choose_destination(destination))
		await map.call("_move_player_to", destination)
		var resolution: Dictionary = controller.request_tile_resolution()
		var tile_type: int = int(resolution.get("tile_type", -1))
		await map.call("_resolve_current_tile", tile_type)
		controller.complete_resolution()
		map.call("_finish_input_cycle")
		await get_tree().process_frame
		var intent: int = AdapterSource.get_intent(tile_type)
		match intent:
			AdapterSource.Intent.COMBAT:
				interaction_counts["combat"] += 1
				_check(failures, "combat_screen_%d" % turn_guard, game.get("current_screen").name == "Combat")
				game.call("_on_upgrade_selected", null)
			AdapterSource.Intent.ELITE:
				interaction_counts["elite"] += 1
				_check(failures, "elite_combat_screen_%d" % turn_guard, game.get("current_screen").name == "Combat")
				game.call("_on_upgrade_selected", null)
			AdapterSource.Intent.EVENT:
				interaction_counts["event"] += 1
				_check(failures, "event_screen_%d" % turn_guard, game.get("current_screen").name == "EventScreen")
				game.call("_on_event_resolved")
			AdapterSource.Intent.TREASURE:
				interaction_counts["treasure"] += 1
				_check(failures, "treasure_screen_%d" % turn_guard, game.get("current_screen").name == "TreasureScreen")
				game.call("_on_treasure_continue_requested")
			AdapterSource.Intent.HEAL:
				interaction_counts["heal"] += 1
			AdapterSource.Intent.BOSS:
				interaction_counts["boss"] += 1
				_check(failures, "boss_combat_screen", game.get("current_screen").name == "Combat")
				game.call("_on_combat_won", true, false)
				await get_tree().process_frame
				_check(failures, "boss_reward_screen", game.get("current_screen").name == "BossReward")
				game.call("_on_boss_reward_selected", null)
		await get_tree().process_frame
		if intent != AdapterSource.Intent.BOSS:
			_check(failures, "same_map_%d" % turn_guard, game.get("board_screen") == map and game.get("current_screen") == map)
			_check(failures, "never_board2d_%d" % turn_guard, game.get("current_screen").name != "Board")

	_check(failures, "reached_boss_index", run.board_position == 29)
	_check(failures, "every_index_emitted", logical_steps == range(1, 30))
	_check(failures, "board_contains_all_tile_types", (
		BoardTileData.TileType.COMBAT in run.board_tile_sequence
		and BoardTileData.TileType.ELITE in run.board_tile_sequence
		and BoardTileData.TileType.EVENT in run.board_tile_sequence
		and BoardTileData.TileType.TREASURE in run.board_tile_sequence
		and BoardTileData.TileType.HEAL in run.board_tile_sequence
		and BoardTileData.TileType.BOSS in run.board_tile_sequence
	))
	_check(failures, "run_resolved_content_and_boss", interaction_counts["combat"] > 0 and interaction_counts["boss"] == 1)
	_check(failures, "prototype_result", game.get("current_screen").name == "Map3DPrototypeResult")
	_check(failures, "no_profile_deposit", not run.rewards_deposited)
	print(JSON.stringify({
		"failures": failures,
		"turns": turn_guard,
		"logical_steps": logical_steps.size(),
		"final_position": run.board_position,
		"interactions": interaction_counts,
		"same_map_instance": game.get("board_screen") == map,
		"board2d_used": false,
		"rewards_deposited": run.rewards_deposited,
	}))
	game.queue_free()
	RunManager.current_run = null
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(failures: Array[String], key: String, passed: bool) -> void:
	if not passed:
		failures.append(key)

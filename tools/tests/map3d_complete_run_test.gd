extends Node

const GAME_SCENE := preload("res://scenes/core/game.tscn")
const AdapterSource = preload("res://scripts/board/board_tile_resolution_adapter.gd")
const BoardTurnControllerSource = preload("res://scripts/board/board_turn_controller.gd")
const RouteBranchDataSource = preload("res://scripts/board/route_branch_data.gd")


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
	var map: Control = game.get("board_screen") as Control
	var run: RunState = RunManager.current_run
	var controller: RefCounted = map.get("_turn_controller")
	var logical_steps: Array[int] = []
	var interaction_counts := {"combat": 0, "elite": 0, "event": 0, "treasure": 0, "heal": 0, "boss": 0}
	var fork_choices := 0
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
		# True routing (MAP3D-HUMAN-004): MOVE puede pausar en un FORK
		# pre-generado. _move_player_to muestra el overlay real y espera
		# branch_choice_selected; acá se simula tocar "Ruta A" siempre, para
		# que la corrida completa siga siendo determinística.
		map.call("_move_player_to", destination)
		var move_guard := 0
		var choice_sent := false
		while move_guard < 600:
			move_guard += 1
			var state: int = int(controller.get("state"))
			if state != BoardTurnControllerSource.State.MOVING and state != BoardTurnControllerSource.State.ROUTE_DECISION:
				break
			# Esperar a que el overlay real exista (no sólo el state) antes de
			# emitir: _request_branch_choice recién queda escuchando
			# branch_choice_selected después de construirlo, y emitir antes
			# perdería la señal para siempre.
			if state == BoardTurnControllerSource.State.ROUTE_DECISION and not choice_sent:
				var overlay: Node = map.get_node_or_null("HUDLayer/BranchChoiceOverlay")
				if overlay != null:
					fork_choices += 1
					choice_sent = true
					map.emit_signal("branch_choice_selected", RouteBranchDataSource.ROUTE_A)
			elif state != BoardTurnControllerSource.State.ROUTE_DECISION:
				choice_sent = false
			await get_tree().process_frame
		_check(failures, "movement_completed_%d" % turn_guard, run.board_position == destination)
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
		"fork_choices": fork_choices,
	}))
	game.queue_free()
	RunManager.current_run = null
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(failures: Array[String], key: String, passed: bool) -> void:
	if not passed:
		failures.append(key)

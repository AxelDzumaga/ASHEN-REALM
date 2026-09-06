extends Node

## Regresión para el "black screen" reportado en el Human Playtest tras Boss
## Victory. Root cause real: _add_screen_backdrop() insertaba AshenBackdrop
## en mini(1, child_count-1), que para una screen armada con un solo hijo
## (Map3DPrototypeResult) lo dejaba DESPUÉS del contenido real — y
## AshenBackdrop pinta bandas opacas a pantalla completa, tapándolo. No
## relacionado con el dominio de routing (game.gd nunca fue tocado por esa
## feature); confirmado comparando con el commit base antes del fix.
##
## map3d_complete_run_test ya llega a este mismo punto y pasaba igual, porque
## sólo verifica current_screen.name — nunca el orden real de hijos/z-order,
## que es donde vivía el bug. Este test verifica exactamente eso.

const GAME_SCENE := preload("res://scenes/core/game.tscn")
const AdapterSource = preload("res://scripts/board/board_tile_resolution_adapter.gd")
const BoardTurnControllerSource = preload("res://scripts/board/board_turn_controller.gd")
const RouteBranchDataSource = preload("res://scripts/board/route_branch_data.gd")

var _failures: Array[String] = []


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"map3d_boss_result_visibility")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	var game: Control = GAME_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.call("_launch_map3d_prototype")
	await get_tree().process_frame
	await get_tree().process_frame
	var map: Control = game.get("board_screen") as Control
	var run: RunState = RunManager.current_run
	var controller: RefCounted = map.get("_turn_controller")

	var turn_guard := 0
	while run.board_position < 29 and turn_guard < 40:
		turn_guard += 1
		var plan: Dictionary = controller.request_roll(4)
		if plan.is_empty():
			_check("turn_plan_not_empty_%d" % turn_guard, false)
			break
		var destination: int = int(plan["destinations"][0])
		map.call("_move_player_to", destination)
		var move_guard := 0
		var choice_sent := false
		while move_guard < 600:
			move_guard += 1
			var state: int = int(controller.get("state"))
			if state != BoardTurnControllerSource.State.MOVING and state != BoardTurnControllerSource.State.ROUTE_DECISION:
				break
			if state == BoardTurnControllerSource.State.ROUTE_DECISION and not choice_sent:
				var overlay: Node = map.get_node_or_null("HUDLayer/BranchChoiceOverlay")
				if overlay != null:
					choice_sent = true
					map.emit_signal("branch_choice_selected", RouteBranchDataSource.ROUTE_A)
			elif state != BoardTurnControllerSource.State.ROUTE_DECISION:
				choice_sent = false
			await get_tree().process_frame
		var resolution: Dictionary = controller.request_tile_resolution()
		var tile_type: int = int(resolution.get("tile_type", -1))
		await map.call("_resolve_current_tile", tile_type)
		controller.complete_resolution()
		map.call("_finish_input_cycle")
		await get_tree().process_frame
		var intent: int = AdapterSource.get_intent(tile_type)
		match intent:
			AdapterSource.Intent.COMBAT, AdapterSource.Intent.ELITE:
				await get_tree().create_timer(0.2).timeout
				game.call("_on_upgrade_selected", null)
			AdapterSource.Intent.EVENT:
				game.call("_on_event_resolved")
			AdapterSource.Intent.TREASURE:
				game.call("_on_treasure_continue_requested")
			AdapterSource.Intent.BOSS:
				await get_tree().create_timer(0.2).timeout
				game.call("_on_combat_won", true, false)
				await get_tree().process_frame
				await get_tree().create_timer(0.4).timeout
				game.call("_on_boss_reward_selected", null)
				await get_tree().process_frame
				await get_tree().create_timer(0.4).timeout
		await get_tree().process_frame
		if intent == AdapterSource.Intent.BOSS:
			break

	var final_screen: Control = game.get("current_screen")
	_check("reached_prototype_result_screen", final_screen != null and final_screen.name == "Map3DPrototypeResult")
	_check("transition_overlay_not_stuck_opaque", (game.get("transition_overlay") as ColorRect).modulate.a < 0.05)
	if final_screen != null:
		var backdrop: Node = final_screen.find_child("AshenBackdrop", false, false)
		_check("result_screen_has_backdrop", backdrop != null)
		if backdrop != null:
			_check("backdrop_is_behind_all_content", backdrop.get_index() == 0)
		var centers: Array = final_screen.find_children("*", "CenterContainer", false, false)
		var center: Node = centers[0] if not centers.is_empty() else null
		_check("result_panel_exists", center != null)
		if center != null and backdrop != null:
			_check("result_panel_drawn_after_backdrop", center.get_index() > backdrop.get_index())
		var restart_button: Node = final_screen.find_children("*", "Button", true, false).front() if not final_screen.find_children("*", "Button", true, false).is_empty() else null
		_check("restart_button_exists_and_visible", restart_button != null and (restart_button as Button).visible)

	print(JSON.stringify({"failures": _failures}))
	game.queue_free()
	RunManager.current_run = null
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	if not condition:
		_failures.append(key)

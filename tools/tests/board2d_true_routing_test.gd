extends Node

## Board2D no tenía ningún test runtime dedicado (sólo board_turn_contract_test,
## que ejercita el dominio sin instanciar board.tscn, y
## board_presentations_contract_test, que sólo compara estructura). Este test
## cubre la misma paridad de dominio que Map3D para MAP3D-HUMAN-004: el fork
## real generado por BoardGenerator debe pausar el turno en board.gd y
## presentar el mismo overlay Ruta A/Ruta B.

const BOARD_2D_SCENE := preload("res://scenes/board/board.tscn")
const BoardTurnControllerSource = preload("res://scripts/board/board_turn_controller.gd")
const RouteBranchDataSource = preload("res://scripts/board/route_branch_data.gd")

var _failures: Array[String] = []


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"board2d_true_routing")
	RunManager.current_run = null
	RunManager.start_new_run()
	var run: RunState = RunManager.current_run
	_check("fork_exists_in_run", not run.route_branches.is_empty())
	var board: Control = BOARD_2D_SCENE.instantiate()
	add_child(board)
	await get_tree().process_frame
	await get_tree().process_frame
	var controller: RefCounted = board.get("_turn_controller")
	if run.route_branches.is_empty():
		print(JSON.stringify({"failures": _failures, "skipped": "no_fork_this_seed"}))
		get_tree().quit(0 if _failures.is_empty() else 1)
		return

	var pause: Dictionary = await _drive_to_first_fork_pause(board, controller, run)
	_check("overlay_appears", pause["overlay"] != null)
	var overlay: Node = pause["overlay"]
	_check("two_buttons", overlay != null and overlay.find_children("*", "Button", true, false).size() == 2)
	var destination_before_choice: int = int(pause["destination"])
	if overlay != null:
		var buttons: Array = overlay.find_children("*", "Button", true, false)
		(buttons[0] as Button).pressed.emit()
	var guard := 0
	while guard < 300 and bool(board.get("_is_moving")):
		guard += 1
		await get_tree().process_frame
	_check("active_branch_is_a", run.active_branch == RouteBranchDataSource.ROUTE_A)
	_check("no_extra_no_lost_movement", run.board_position == destination_before_choice)
	_check("turn_completes_after_choice", int(controller.get("state")) == BoardTurnControllerSource.State.IDLE)

	print(JSON.stringify({"failures": _failures, "final_position": run.board_position}))
	board.queue_free()
	RunManager.current_run = null
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _drive_to_first_fork_pause(board: Control, controller: RefCounted, run: RunState) -> Dictionary:
	board.set("_forced_dice_result", 4)
	for _turn: int in 10:
		if run.board_position >= run.board_tile_sequence.size() - 1:
			break
		board.call("_on_roll_button_pressed")
		var destination: int = int(controller.get("_selected_destination"))
		var guard := 0
		var overlay: Node = null
		while guard < 300:
			guard += 1
			overlay = board.get_node_or_null("RouteChoiceOverlay")
			if overlay != null:
				return {"overlay": overlay, "destination": destination}
			if not bool(board.get("_is_moving")):
				break
			await get_tree().process_frame
		guard = 0
		while guard < 300 and bool(board.get("_is_moving")):
			guard += 1
			await get_tree().process_frame
	return {"overlay": null, "destination": -1}


func _check(key: String, condition: bool) -> void:
	if not condition:
		_failures.append(key)

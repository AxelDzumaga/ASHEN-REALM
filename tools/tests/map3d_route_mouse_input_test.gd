extends Node

## Reemplaza el test anterior (tap/raycast sobre dos tiles A/B del spine),
## superado por MAP3D-HUMAN-004: la elección de ruta real ya no ofrece un
## segundo tile adyacente calculado al vuelo, sino un FORK pre-generado que
## pausa el movimiento y presenta un overlay 2D (RUTA A / RUTA B) con
## identidad/peligro/enfoque/primer nodo. Este test conduce el fork REAL que
## generó BoardGenerator para el seed de sandbox (no uno inyectado a mano,
## para no desincronizar la geometría ya construida de la lógica).

const MAP_SCENE := preload("res://scenes/board3d/ashen_wastes_map_3d.tscn")
const BoardTurnControllerSource = preload("res://scripts/board/board_turn_controller.gd")
const RouteBranchDataSource = preload("res://scripts/board/route_branch_data.gd")

var _failures: Array[String] = []
var _diagnostics: Array[Dictionary] = []


func _ready() -> void:
	await _test_pause_and_button_choice()
	await _test_single_commit_ignores_second_signal()
	print(JSON.stringify({"failures": _failures, "diagnostics": _diagnostics}))
	RunManager.current_run = null
	get_tree().quit(0 if _failures.is_empty() else 1)


## Conduce turnos con roll forzado 4 hasta que el fork real (generado por
## BoardGenerator para esta seed) pausa el movimiento; confirma que el
## overlay real tiene dos botones, que tocar "RUTA B" la fija como carril
## activo, y que el turno completa sin agregar/quitar movimiento del roll
## original que reveló el fork.
func _test_pause_and_button_choice() -> void:
	var context: Dictionary = await _create_map_context()
	var map: Control = context["map"]
	var controller: RefCounted = context["controller"]
	var run: RunState = context["run"]
	_check("fork_exists_in_sandbox_seed", not run.route_branches.is_empty())
	if run.route_branches.is_empty():
		_destroy_context(map)
		return
	var pause: Dictionary = await _drive_to_first_fork_pause(map, controller, run)
	_check("overlay_appears", pause["overlay"] != null)
	var overlay: Node = pause["overlay"]
	_check("two_buttons", overlay != null and overlay.find_children("*", "Button", true, false).size() == 2)
	_check("pauses_movement_state", pause["paused"])
	var destination_before_choice: int = int(pause["destination"])
	if overlay != null:
		var buttons: Array = overlay.find_children("*", "Button", true, false)
		(buttons[1] as Button).pressed.emit()
	var guard := 0
	while guard < 300 and bool(map.get("_is_moving")):
		guard += 1
		await get_tree().process_frame
	_check("active_branch_is_b", run.active_branch == RouteBranchDataSource.ROUTE_B)
	_check("no_extra_no_lost_movement", run.board_position == destination_before_choice)
	_check("turn_completes_after_choice", int(controller.get("state")) == BoardTurnControllerSource.State.IDLE)
	_destroy_context(map)


## Doble señal (doble tap simulado) no debe cambiar la ruta ya elegida.
func _test_single_commit_ignores_second_signal() -> void:
	var context: Dictionary = await _create_map_context()
	var map: Control = context["map"]
	var controller: RefCounted = context["controller"]
	var run: RunState = context["run"]
	if run.route_branches.is_empty():
		_destroy_context(map)
		return
	var pause: Dictionary = await _drive_to_first_fork_pause(map, controller, run)
	if pause["overlay"] == null:
		_check("single_commit_setup_reached_fork", false)
		_destroy_context(map)
		return
	map.emit_signal("branch_choice_selected", RouteBranchDataSource.ROUTE_A)
	map.emit_signal("branch_choice_selected", RouteBranchDataSource.ROUTE_B)
	var guard := 0
	while guard < 300 and bool(map.get("_is_moving")):
		guard += 1
		await get_tree().process_frame
	_check("single_commit_only", run.active_branch == RouteBranchDataSource.ROUTE_A)
	_destroy_context(map)


func _create_map_context() -> Dictionary:
	RunManager.current_run = null
	var map: Control = MAP_SCENE.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().physics_frame
	var run: RunState = map.get("_run") as RunState
	var controller: RefCounted = map.get("_turn_controller")
	return {"map": map, "controller": controller, "run": run}


## Tira D4=4 repetidamente (vía _on_roll_pressed real) hasta detectar la
## pausa real de un fork. Devuelve el overlay encontrado, si pausó, y el
## destino planeado de ese roll (para verificar que no cambia tras elegir).
func _drive_to_first_fork_pause(map: Control, controller: RefCounted, run: RunState) -> Dictionary:
	map.set("_forced_dice_result", 4)
	for _turn: int in 10:
		if run.board_position >= 29:
			break
		map.call("_on_roll_pressed")
		var destination: int = int(controller.get("_selected_destination"))
		var guard := 0
		var overlay: Node = null
		while guard < 300:
			guard += 1
			overlay = map.get_node_or_null("HUDLayer/BranchChoiceOverlay")
			if overlay != null:
				return {"overlay": overlay, "paused": true, "destination": destination}
			if not bool(map.get("_is_moving")):
				break
			await get_tree().process_frame
		# Este roll no encontró el fork: esperar a que termine el turno
		# (posible interacción externa) antes de tirar de nuevo.
		guard = 0
		while guard < 300 and bool(map.get("_is_moving")):
			guard += 1
			await get_tree().process_frame
	return {"overlay": null, "paused": false, "destination": -1}


func _destroy_context(map: Control) -> void:
	map.queue_free()
	RunManager.current_run = null
	await get_tree().process_frame


func _check(key: String, condition: bool) -> void:
	if not condition:
		_failures.append(key)

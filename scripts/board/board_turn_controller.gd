class_name BoardTurnController
extends RefCounted

## Coordinador lógico de un turno de tablero. No conoce Controls, Node3D,
## colores, cámara ni animaciones. La presentación decide cuándo pedir el
## siguiente paso y sólo puede solicitar la resolución tras completar el último.

signal roll_received(result: int, origin: int, destinations: Array[int])
signal route_choice_requested(destinations: Array[int], origin: int)
signal route_destination_accepted(destination: int)
signal logical_step_emitted(from_index: int, to_index: int)
signal movement_completed(destination: int)
signal tile_resolution_requested(tile_type: int, position: int)

enum State {
	IDLE,
	ROUTE_SELECTION,
	MOVING,
	AWAITING_RESOLUTION,
	RESOLVING,
}

var state: State = State.IDLE
var run: RunState
var sequence: Array[int] = []
var dice_roller: DiceRoller

var _origin: int = -1
var _destinations: Array[int] = []
var _selected_destination: int = -1
var _last_roll: int = 0


func _init(run_state: RunState, tile_sequence: Array[int], roller: DiceRoller = null) -> void:
	run = run_state
	sequence = tile_sequence
	dice_roller = roller if roller != null else DiceRoller.new()


func is_turn_locked() -> bool:
	return state != State.IDLE or run == null or run.board_locked


func request_roll(forced_result: int = 0) -> Dictionary:
	if is_turn_locked() or sequence.is_empty():
		return {}
	_origin = run.board_position
	_last_roll = dice_roller.roll(forced_result)
	var was_on_cooldown: bool = run.route_choice_cooldown
	_destinations = RouteChoiceResolver.get_destinations(
		sequence,
		_origin,
		_last_roll,
		run.board_seed,
		run.route_choice_count,
		was_on_cooldown,
	)
	if was_on_cooldown:
		run.route_choice_cooldown = false
	if _destinations.is_empty():
		_reset_turn()
		return {}
	if _destinations.size() == 2:
		run.route_option_a = _destinations[0]
		run.route_option_b = _destinations[1]
		run.route_choice_count += 1
		state = State.ROUTE_SELECTION
		route_choice_requested.emit(_destinations.duplicate(), _origin)
	else:
		_selected_destination = _destinations[0]
		state = State.MOVING
	roll_received.emit(_last_roll, _origin, _destinations.duplicate())
	return {
		"roll": _last_roll,
		"origin": _origin,
		"destinations": _destinations.duplicate(),
		"was_on_cooldown": was_on_cooldown,
	}


func choose_destination(destination: int) -> bool:
	if state != State.ROUTE_SELECTION or destination not in _destinations:
		return false
	if not RouteChoiceResolver.is_valid_destination(_origin, sequence.size(), destination):
		return false
	_selected_destination = destination
	run.chosen_destination = destination
	run.chosen_tile_type = sequence[destination]
	run.route_choice_cooldown = true
	state = State.MOVING
	route_destination_accepted.emit(destination)
	return true


func get_selected_destination() -> int:
	return _selected_destination


func advance_one_step() -> int:
	if state != State.MOVING or _selected_destination < 0:
		return -1
	if not RouteChoiceResolver.is_valid_destination(run.board_position, sequence.size(), _selected_destination):
		abort_turn()
		return -1
	var from_index: int = run.board_position
	run.board_position += 1
	var to_index: int = run.board_position
	logical_step_emitted.emit(from_index, to_index)
	if to_index == _selected_destination:
		state = State.AWAITING_RESOLUTION
		movement_completed.emit(to_index)
	return to_index


func has_pending_steps() -> bool:
	return state == State.MOVING and run != null and run.board_position < _selected_destination


func request_tile_resolution() -> Dictionary:
	if state != State.AWAITING_RESOLUTION or run.board_position != _selected_destination:
		return {}
	state = State.RESOLVING
	var tile_type: int = sequence[run.board_position]
	tile_resolution_requested.emit(tile_type, run.board_position)
	return {"tile_type": tile_type, "position": run.board_position}


func complete_resolution() -> void:
	if state == State.RESOLVING:
		_reset_turn()


func abort_turn() -> void:
	_reset_turn()


func _reset_turn() -> void:
	state = State.IDLE
	_origin = -1
	_destinations.clear()
	_selected_destination = -1
	_last_roll = 0


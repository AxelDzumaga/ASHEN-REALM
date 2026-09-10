class_name BoardTurnController
extends RefCounted

## Coordinador lógico de un turno de tablero. No conoce Controls, Node3D,
## colores, cámara ni animaciones. La presentación decide cuándo pedir el
## siguiente paso y sólo puede solicitar la resolución tras completar el último.
##
## ROLL -> MOVE N -> LAND -> RESOLVE se preserva siempre. Un FORK pre-generado
## puede pausar MOVE a mitad de camino (ROUTE_DECISION) para pedir Ruta A/B,
## pero no agrega, quita ni recalcula el N original del roll: sólo cambia de
## qué overlay sale el contenido de los índices que todavía faltan recorrer.

## preload (no class_name directo): mismo motivo documentado en RunState/
## BoardGenerator — RouteBranchData es un class_name nuevo en este mismo
## cambio, y este controller se instancia desde el arranque de una run.
const _RouteBranchData = preload("res://scripts/board/route_branch_data.gd")
const _BoardTileResolutionAdapter = preload("res://scripts/board/board_tile_resolution_adapter.gd")

## Active Run Persistence checkpoint phases. Plain string literals here
## (not a reference to ActiveRunRepository's own constants) so this
## presentation-independent domain controller stays decoupled from the
## save/persistence autoload — round_trip_phase_constants_match in
## active_run_checkpoint_wiring_test.gd proves these stay in sync.
const CHECKPOINT_PHASE_ON_BOARD := "ON_BOARD"
const CHECKPOINT_PHASE_ROUTE_DECISION_PENDING := "ROUTE_DECISION_PENDING"
const CHECKPOINT_PHASE_ENCOUNTER_PENDING := "ENCOUNTER_PENDING"

signal roll_received(result: int, origin: int, destinations: Array[int])
signal route_choice_requested(destinations: Array[int], origin: int)
signal route_destination_accepted(destination: int)
## Emitida cuando el movimiento alcanza un FORK sin carril elegido todavía.
## La presentación debe pausar su animación y llamar a choose_branch().
signal route_choice_required(fork_index: int, branch_data: RefCounted)
signal logical_step_emitted(from_index: int, to_index: int)
signal movement_completed(destination: int)
signal tile_resolution_requested(tile_type: int, position: int)

enum State {
	IDLE,
	ROUTE_SELECTION,
	MOVING,
	ROUTE_DECISION,
	AWAITING_RESOLUTION,
	RESOLVING,
}

var state: State = State.IDLE
var run: RunState
var sequence: Array[int] = []
var dice_roller: DiceRoller
## Active Run Persistence — optional hook, called as
## checkpoint_callback.call(run, phase, reason) at safe checkpoint
## boundaries (SAFE CHECKPOINTS ONLY, approved design — never per
## animation frame/per step). A no-op Callable by default so every
## existing caller/test that doesn't pass one is unaffected.
var checkpoint_callback: Callable = Callable()

var _origin: int = -1
var _destinations: Array[int] = []
var _selected_destination: int = -1
var _last_roll: int = 0
var _pending_fork_index: int = -1


func _init(run_state: RunState, tile_sequence: Array[int], roller: DiceRoller = null, checkpoint: Callable = Callable()) -> void:
	run = run_state
	sequence = tile_sequence
	dice_roller = roller if roller != null else DiceRoller.new()
	checkpoint_callback = checkpoint
	_detect_resumed_fork_pause()


## Active Run Persistence resume correctness: a fresh controller can be
## constructed (show_board() after a screen transition, or a genuine app
## restart) while `run` is sitting exactly on an unresolved FORK — its own
## board_position already advanced onto the fork tile (advance_one_step()
## sets it before pausing) but no branch chosen yet. Without this, the
## next roll would silently move past the fork without ever offering the
## A/B choice — the choice would just vanish. Re-enters ROUTE_DECISION
## directly from persisted state; genuinely mid-choice, this is never
## reachable during normal live play (the choice resolves synchronously
## within the same movement loop, never yielding back to a fresh
## show_board() call), so this only ever fires on a real interruption.
func _detect_resumed_fork_pause() -> void:
	if run == null or sequence.is_empty() or run.active_branch != _RouteBranchData.NONE:
		return
	var position: int = run.board_position
	if position < 0 or position >= sequence.size() or sequence[position] != BoardTileData.TileType.FORK:
		return
	var branch: RefCounted = run.route_branches.get(position)
	if branch == null:
		return
	_pending_fork_index = position
	_selected_destination = position
	state = State.ROUTE_DECISION
	route_choice_required.emit(position, branch)


func _checkpoint(phase: String, reason: String) -> void:
	if checkpoint_callback.is_valid():
		checkpoint_callback.call(run, phase, reason)


func is_turn_locked() -> bool:
	return state != State.IDLE or run == null or run.board_locked


func request_roll(forced_result: int = 0) -> Dictionary:
	if is_turn_locked() or sequence.is_empty():
		return {}
	_origin = run.board_position
	_last_roll = dice_roller.roll(forced_result)
	# El roll sigue siendo la única autoridad sobre el destino: los forks ya
	# no se calculan al vuelo (base+1 + gate probabilístico, superado por
	# MAP3D-HUMAN-004) — son tiles pre-generados que MOVE puede atravesar.
	_selected_destination = RouteChoiceResolver.get_base_destination(sequence.size(), _origin, _last_roll)
	_destinations = [_selected_destination]
	state = State.MOVING
	roll_received.emit(_last_roll, _origin, _destinations.duplicate())
	return {
		"roll": _last_roll,
		"origin": _origin,
		"destinations": _destinations.duplicate(),
	}


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
	_clear_active_branch_if_exited(to_index)
	logical_step_emitted.emit(from_index, to_index)
	var fork: RefCounted = _fork_at(to_index)
	if fork != null and run.active_branch == _RouteBranchData.NONE:
		# Intercepción obligatoria: MOVE se pausa exactamente en el fork,
		# sin importar si es el destino final del roll o un paso intermedio.
		# No consume ni agrega movimiento, y no resuelve contenido por sí sola.
		_pending_fork_index = to_index
		state = State.ROUTE_DECISION
		route_choice_required.emit(to_index, fork)
		_checkpoint(CHECKPOINT_PHASE_ROUTE_DECISION_PENDING, "fork_reached")
		return to_index
	if to_index == _selected_destination:
		state = State.AWAITING_RESOLUTION
		movement_completed.emit(to_index)
		_checkpoint(CHECKPOINT_PHASE_ON_BOARD, "movement_completed")
	return to_index


## Confirma Ruta A o Ruta B (RouteBranchData.ROUTE_A / ROUTE_B) tras una
## pausa por route_choice_required. No cambia _selected_destination: el roll
## ya sabía a qué índice iba a llegar, sólo cambia qué overlay se lee desde
## ahora. Una vez elegido, el carril no puede cambiarse dentro del mismo fork.
func choose_branch(branch: int) -> bool:
	if state != State.ROUTE_DECISION or _pending_fork_index < 0:
		return false
	if branch != _RouteBranchData.ROUTE_A and branch != _RouteBranchData.ROUTE_B:
		return false
	run.active_branch = branch
	run.active_fork_index = _pending_fork_index
	_pending_fork_index = -1
	_checkpoint(CHECKPOINT_PHASE_ON_BOARD, "route_choice_committed")
	if run.board_position == _selected_destination:
		# El fork era el destino final de este roll (remaining == 0): el
		# turno termina acá. El contenido de la ruta se resuelve en próximos
		# turnos, con rolls nuevos — nunca en este mismo roll.
		state = State.AWAITING_RESOLUTION
		movement_completed.emit(run.board_position)
	else:
		state = State.MOVING
	return true


func has_pending_steps() -> bool:
	return state == State.MOVING and run != null and run.board_position < _selected_destination


func request_tile_resolution() -> Dictionary:
	if state != State.AWAITING_RESOLUTION or run.board_position != _selected_destination:
		return {}
	state = State.RESOLVING
	var tile_type: int = _effective_tile_type(run.board_position)
	tile_resolution_requested.emit(tile_type, run.board_position)
	_checkpoint(_phase_for_tile_type(tile_type), "tile_landing_committed")
	return {"tile_type": tile_type, "position": run.board_position}


## EMPTY/HEAL/FORK resolve inline (BoardTileResolutionAdapter.resolve_inline())
## with no screen transition, so the checkpoint right after landing on one
## of them is already back to ON_BOARD. Everything else needs a screen —
## the checkpoint here marks ENCOUNTER_PENDING; the presentation layer
## marks IN_ENCOUNTER itself once that screen actually opens.
func _phase_for_tile_type(tile_type: int) -> String:
	var intent: int = _BoardTileResolutionAdapter.get_intent(tile_type)
	match intent:
		_BoardTileResolutionAdapter.Intent.EMPTY, _BoardTileResolutionAdapter.Intent.HEAL, _BoardTileResolutionAdapter.Intent.FORK:
			return CHECKPOINT_PHASE_ON_BOARD
		_:
			return CHECKPOINT_PHASE_ENCOUNTER_PENDING


func complete_resolution() -> void:
	if state == State.RESOLVING:
		_reset_turn()


func abort_turn() -> void:
	_reset_turn()


## Tipo de tile en `index` considerando el carril activo. Fuera del rango
## reservado de un fork (o sin carril elegido todavía) lee el spine normal,
## exactamente como antes de esta feature.
func _effective_tile_type(index: int) -> int:
	if run.active_branch != _RouteBranchData.NONE and run.active_fork_index >= 0:
		var branch: RefCounted = run.route_branches.get(run.active_fork_index)
		if branch != null and index > run.active_fork_index and index <= run.active_fork_index + _RouteBranchData.BRANCH_LENGTH:
			return branch.tile_type_for(run.active_branch, index)
	return sequence[index]


func _fork_at(index: int) -> RefCounted:
	if index < 0 or index >= sequence.size() or sequence[index] != BoardTileData.TileType.FORK:
		return null
	return run.route_branches.get(index)


func _clear_active_branch_if_exited(position: int) -> void:
	if run.active_branch == _RouteBranchData.NONE:
		return
	if position > run.active_fork_index + _RouteBranchData.BRANCH_LENGTH:
		run.active_branch = _RouteBranchData.NONE
		run.active_fork_index = -1


func _reset_turn() -> void:
	state = State.IDLE
	_origin = -1
	_destinations.clear()
	_selected_destination = -1
	_last_roll = 0
	_pending_fork_index = -1


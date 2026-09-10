extends Node

## Proves BoardTurnController's injected checkpoint callback actually
## fires with the right (phase, reason) at each of its four boundaries,
## and that its phase string literals match ActiveRunRepository's real
## constants (BoardTurnController deliberately does not import that
## autoload, so nothing else would catch the two drifting apart).

const BoardTurnControllerSource = preload("res://scripts/board/board_turn_controller.gd")
const RouteBranchDataSource = preload("res://scripts/board/route_branch_data.gd")

var _failures: Array[String] = []
var _checks: Dictionary = {}
var _calls: Array[Dictionary] = []


func _ready() -> void:
	_test_phase_constants_match_active_run_repository()
	_test_movement_completed_checkpoint_fires()
	_test_fork_reached_checkpoint_fires()
	_test_route_choice_committed_checkpoint_fires()
	_test_tile_landing_checkpoint_phase_for_combat()
	_test_tile_landing_checkpoint_phase_for_empty()
	_test_no_callback_does_not_crash()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _record_checkpoint(run: RunState, phase: String, reason: String) -> void:
	_calls.append({"phase": phase, "reason": reason, "board_position": run.board_position if run != null else -1})


func _test_phase_constants_match_active_run_repository() -> void:
	_check("on_board_matches", BoardTurnControllerSource.CHECKPOINT_PHASE_ON_BOARD == ActiveRunRepository.PHASE_ON_BOARD)
	_check("route_decision_pending_matches", BoardTurnControllerSource.CHECKPOINT_PHASE_ROUTE_DECISION_PENDING == ActiveRunRepository.PHASE_ROUTE_DECISION_PENDING)
	_check("encounter_pending_matches", BoardTurnControllerSource.CHECKPOINT_PHASE_ENCOUNTER_PENDING == ActiveRunRepository.PHASE_ENCOUNTER_PENDING)


func _make_run(length: int = 10) -> RunState:
	var run := RunState.new()
	var sequence: Array[int] = []
	for i in length:
		sequence.append(BoardTileData.TileType.EMPTY)
	sequence[0] = BoardTileData.TileType.EMPTY
	sequence[-1] = BoardTileData.TileType.BOSS
	run.board_tile_sequence = sequence
	return run


func _test_movement_completed_checkpoint_fires() -> void:
	_calls.clear()
	var run: RunState = _make_run()
	var controller := BoardTurnControllerSource.new(run, run.board_tile_sequence, null, _record_checkpoint)
	controller.request_roll(3)
	while controller.has_pending_steps():
		controller.advance_one_step()
	_check("movement_completed_checkpoint_recorded", _calls.size() >= 1)
	var last_call: Dictionary = _calls[-1] if not _calls.is_empty() else {}
	_check("movement_completed_reason_correct", String(last_call.get("reason", "")) == "movement_completed")
	_check("movement_completed_phase_on_board", String(last_call.get("phase", "")) == ActiveRunRepository.PHASE_ON_BOARD)


func _test_fork_reached_checkpoint_fires() -> void:
	_calls.clear()
	var run: RunState = _make_run(12)
	run.board_tile_sequence[3] = BoardTileData.TileType.FORK
	var route_a: Array[int] = [BoardTileData.TileType.EMPTY, BoardTileData.TileType.EMPTY, BoardTileData.TileType.EMPTY, BoardTileData.TileType.EMPTY, BoardTileData.TileType.EMPTY, BoardTileData.TileType.EMPTY]
	run.route_branches = {3: RouteBranchDataSource.new(3, route_a, route_a, &"balanced", &"balanced")}
	var controller := BoardTurnControllerSource.new(run, run.board_tile_sequence, null, _record_checkpoint)
	controller.request_roll(4)
	while controller.has_pending_steps():
		controller.advance_one_step()
	var fork_calls: Array = _calls.filter(func(c: Dictionary) -> bool: return String(c.get("reason", "")) == "fork_reached")
	_check("fork_reached_checkpoint_recorded", fork_calls.size() == 1)
	if not fork_calls.is_empty():
		_check("fork_reached_phase_route_decision_pending", String(fork_calls[0].get("phase", "")) == ActiveRunRepository.PHASE_ROUTE_DECISION_PENDING)


func _test_route_choice_committed_checkpoint_fires() -> void:
	_calls.clear()
	var run: RunState = _make_run(12)
	run.board_tile_sequence[3] = BoardTileData.TileType.FORK
	var route_a: Array[int] = [BoardTileData.TileType.EMPTY, BoardTileData.TileType.EMPTY, BoardTileData.TileType.EMPTY, BoardTileData.TileType.EMPTY, BoardTileData.TileType.EMPTY, BoardTileData.TileType.EMPTY]
	run.route_branches = {3: RouteBranchDataSource.new(3, route_a, route_a, &"balanced", &"balanced")}
	var controller := BoardTurnControllerSource.new(run, run.board_tile_sequence, null, _record_checkpoint)
	controller.request_roll(4)
	while controller.has_pending_steps():
		controller.advance_one_step()
	controller.choose_branch(RouteBranchDataSource.ROUTE_A)
	var committed_calls: Array = _calls.filter(func(c: Dictionary) -> bool: return String(c.get("reason", "")) == "route_choice_committed")
	_check("route_choice_committed_recorded", committed_calls.size() == 1)


func _test_tile_landing_checkpoint_phase_for_combat() -> void:
	_calls.clear()
	var run: RunState = _make_run()
	run.board_tile_sequence[3] = BoardTileData.TileType.COMBAT
	var controller := BoardTurnControllerSource.new(run, run.board_tile_sequence, null, _record_checkpoint)
	controller.request_roll(3)
	while controller.has_pending_steps():
		controller.advance_one_step()
	controller.request_tile_resolution()
	var landing_calls: Array = _calls.filter(func(c: Dictionary) -> bool: return String(c.get("reason", "")) == "tile_landing_committed")
	_check("combat_landing_checkpoint_recorded", landing_calls.size() == 1)
	if not landing_calls.is_empty():
		_check("combat_landing_phase_encounter_pending", String(landing_calls[0].get("phase", "")) == ActiveRunRepository.PHASE_ENCOUNTER_PENDING)


func _test_tile_landing_checkpoint_phase_for_empty() -> void:
	_calls.clear()
	var run: RunState = _make_run()
	var controller := BoardTurnControllerSource.new(run, run.board_tile_sequence, null, _record_checkpoint)
	controller.request_roll(3)
	while controller.has_pending_steps():
		controller.advance_one_step()
	controller.request_tile_resolution()
	var landing_calls: Array = _calls.filter(func(c: Dictionary) -> bool: return String(c.get("reason", "")) == "tile_landing_committed")
	_check("empty_landing_checkpoint_recorded", landing_calls.size() == 1)
	if not landing_calls.is_empty():
		_check("empty_landing_phase_on_board", String(landing_calls[0].get("phase", "")) == ActiveRunRepository.PHASE_ON_BOARD)


func _test_no_callback_does_not_crash() -> void:
	var run: RunState = _make_run()
	var controller := BoardTurnControllerSource.new(run, run.board_tile_sequence)
	controller.request_roll(3)
	while controller.has_pending_steps():
		controller.advance_one_step()
	var resolved: Dictionary = controller.request_tile_resolution()
	_check("no_callback_still_resolves_normally", not resolved.is_empty())

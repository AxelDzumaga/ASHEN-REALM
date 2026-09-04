extends Node

## Congela el contrato lógico vigente del turno del Board antes de compartirlo
## con otras presentaciones. No usa SaveManager ni escribe el perfil.

const BoardTurnControllerSource = preload("res://scripts/board/board_turn_controller.gd")
const BoardTileResolutionAdapterSource = preload("res://scripts/board/board_tile_resolution_adapter.gd")

var _checks: Dictionary = {}
var _failures: Array[String] = []


func _ready() -> void:
	_test_dice_contract()
	_test_routing_contract()
	_test_movement_contract()
	_test_tile_resolution_contract()
	_test_shared_controller_contract()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures, "save_or_profile_written": false}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_dice_contract() -> void:
	var roller := DiceRoller.new()
	_check("dice_min_1", DiceRoller.MIN_RESULT == 1)
	_check("dice_max_4", DiceRoller.MAX_RESULT == 4)
	for expected: int in range(DiceRoller.MIN_RESULT, DiceRoller.MAX_RESULT + 1):
		_check("forced_roll_%d" % expected, roller.roll(expected) == expected)


func _test_routing_contract() -> void:
	var sequence: Array[int] = [
		BoardTileData.TileType.EMPTY,
		BoardTileData.TileType.COMBAT,
		BoardTileData.TileType.HEAL,
		BoardTileData.TileType.EVENT,
		BoardTileData.TileType.BOSS,
	]
	var two_options := RouteChoiceResolver.get_destinations(sequence, 0, 1, 67, 0, false, 100)
	var cooldown := RouteChoiceResolver.get_destinations(sequence, 0, 1, 67, 0, true, 100)
	var boss := RouteChoiceResolver.get_destinations(sequence, 2, 4, 67, 0, false, 100)
	_check("route_two_options", two_options == [1, 2])
	_check("route_maximum_two", two_options.size() <= 2)
	_check("route_cooldown_one_destination", cooldown == [1])
	_check("route_boss_clamped", boss == [4])
	_check("route_no_overshoot", boss[0] == sequence.size() - 1)
	_check("route_backward_invalid", not RouteChoiceResolver.is_valid_destination(2, sequence.size(), 1))
	_check("route_forward_valid", RouteChoiceResolver.is_valid_destination(0, sequence.size(), 2))


func _test_movement_contract() -> void:
	var visited: Array[int] = []
	var position := 3
	var destination := 7
	while position < destination:
		position += 1
		visited.append(position)
	_check("movement_step_by_step", visited == [4, 5, 6, 7])
	_check("movement_exact_destination", position == destination)


func _test_tile_resolution_contract() -> void:
	var sequence: Array[int] = [
		BoardTileData.TileType.EMPTY,
		BoardTileData.TileType.HEAL,
		BoardTileData.TileType.COMBAT,
		BoardTileData.TileType.ELITE,
		BoardTileData.TileType.EVENT,
		BoardTileData.TileType.TREASURE,
		BoardTileData.TileType.BOSS,
	]
	_check("tile_ids_frozen", sequence == [0, 1, 3, 6, 4, 5, 2])
	var run := RunState.new()
	run.current_health = 50
	var before := run.current_health
	var recovered := run.heal(20)
	_check("heal_inline_20", recovered == 20 and run.current_health == before + 20)
	var movement_finished := false
	var resolution_requested := false
	for _index: int in [4, 5, 6, 7]:
		pass
	movement_finished = true
	resolution_requested = movement_finished
	_check("resolution_after_movement", resolution_requested)
	_check("adapter_empty", BoardTileResolutionAdapterSource.get_intent(0) == BoardTileResolutionAdapterSource.Intent.EMPTY)
	_check("adapter_heal", BoardTileResolutionAdapterSource.get_intent(1) == BoardTileResolutionAdapterSource.Intent.HEAL)
	_check("adapter_boss", BoardTileResolutionAdapterSource.get_intent(2) == BoardTileResolutionAdapterSource.Intent.BOSS)
	_check("adapter_combat", BoardTileResolutionAdapterSource.get_intent(3) == BoardTileResolutionAdapterSource.Intent.COMBAT)
	_check("adapter_event", BoardTileResolutionAdapterSource.get_intent(4) == BoardTileResolutionAdapterSource.Intent.EVENT)
	_check("adapter_treasure", BoardTileResolutionAdapterSource.get_intent(5) == BoardTileResolutionAdapterSource.Intent.TREASURE)
	_check("adapter_elite", BoardTileResolutionAdapterSource.get_intent(6) == BoardTileResolutionAdapterSource.Intent.ELITE)


func _test_shared_controller_contract() -> void:
	var sequence: Array[int] = [
		BoardTileData.TileType.EMPTY,
		BoardTileData.TileType.COMBAT,
		BoardTileData.TileType.HEAL,
		BoardTileData.TileType.EVENT,
		BoardTileData.TileType.TREASURE,
		BoardTileData.TileType.ELITE,
		BoardTileData.TileType.BOSS,
	]
	var branch_seed := 1
	while branch_seed < 1000 and RouteChoiceResolver.get_destinations(sequence, 0, 1, branch_seed, 0).size() != 2:
		branch_seed += 1
	var run := RunState.new()
	run.board_seed = branch_seed
	run.board_tile_sequence = sequence
	var controller: RefCounted = BoardTurnControllerSource.new(run, sequence)
	var plan: Dictionary = controller.request_roll(1)
	_check("controller_roll", int(plan.get("roll", 0)) == 1)
	_check("controller_route_choice", (plan.get("destinations", []) as Array).size() == 2)
	_check("controller_choice_valid", controller.choose_destination(2))
	_check("controller_choice_records_type", run.chosen_destination == 2 and run.chosen_tile_type == BoardTileData.TileType.HEAL)
	_check("controller_sets_cooldown", run.route_choice_cooldown)
	var visited: Array[int] = []
	while controller.has_pending_steps():
		visited.append(controller.advance_one_step())
	_check("controller_emits_each_step", visited == [1, 2])
	var resolution: Dictionary = controller.request_tile_resolution()
	_check("controller_resolution_after_steps", int(resolution.get("position", -1)) == 2)
	controller.complete_resolution()
	_check("controller_unlocks", not controller.is_turn_locked())
	var cooldown_plan: Dictionary = controller.request_roll(1)
	_check("controller_cooldown_consumed", (cooldown_plan.get("destinations", []) as Array).size() == 1 and not run.route_choice_cooldown)


func _check(key: String, passed: bool) -> void:
	_checks[key] = passed

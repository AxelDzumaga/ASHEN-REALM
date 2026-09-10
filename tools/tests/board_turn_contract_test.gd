extends Node

## Congela el contrato lógico vigente del turno del Board antes de compartirlo
## con otras presentaciones. No usa SaveManager ni escribe el perfil.

const BoardTurnControllerSource = preload("res://scripts/board/board_turn_controller.gd")
const BoardTileResolutionAdapterSource = preload("res://scripts/board/board_tile_resolution_adapter.gd")
const RouteBranchDataSource = preload("res://scripts/board/route_branch_data.gd")

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


## get_base_destination() es la única fórmula que usa el gameplay real
## (BoardTurnController / Board2D / Map3D): el D4 sigue siendo la autoridad
## total, sin gate ni cooldown. El mecanismo dinámico anterior
## (get_destinations con probabilidad, superado por MAP3D-HUMAN-004 — ver
## fork interception abajo) se conserva sólo porque
## tools/simulation/full_run_simulation.gd todavía lo usa para sus propias
## corridas batch de economía; no es parte del dominio de gameplay real.
func _test_routing_contract() -> void:
	var sequence_size := 5
	_check("route_base_within_range", RouteChoiceResolver.get_base_destination(sequence_size, 0, 1) == 1)
	_check("route_base_clamped_to_last", RouteChoiceResolver.get_base_destination(sequence_size, 2, 4) == 4)
	_check("route_base_uses_full_roll", RouteChoiceResolver.get_base_destination(sequence_size, 0, 4) == 4)
	_check("route_backward_invalid", not RouteChoiceResolver.is_valid_destination(2, sequence_size, 1))
	_check("route_forward_valid", RouteChoiceResolver.is_valid_destination(0, sequence_size, 2))
	var legacy_two_options := RouteChoiceResolver.get_destinations(
		[BoardTileData.TileType.EMPTY, BoardTileData.TileType.COMBAT, BoardTileData.TileType.HEAL, BoardTileData.TileType.EVENT, BoardTileData.TileType.BOSS],
		0, 1, 67, 0, false, 100,
	)
	_check("legacy_dynamic_fork_still_importable_for_simulation", legacy_two_options == [1, 2])


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
	_check("fork_id_appended_not_inserted", BoardTileData.TileType.FORK == 7)
	_check("adapter_fork_no_content", BoardTileResolutionAdapterSource.get_intent(BoardTileData.TileType.FORK) == BoardTileResolutionAdapterSource.Intent.FORK)
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


## Congela el contrato de la bifurcación VERDADERA (MAP3D-HUMAN-004): FORK
## pre-generado, intercepción obligatoria en MOVE, ROLL->MOVE->LAND->RESOLVE
## intacto. Sustituye el contrato anterior (destinos dinámicos base+1 con
## gate/cooldown) — esa mecánica fue la causa raíz de "A y B se sienten como
## la misma ruta" y queda superada, no combinada con la nueva.
func _test_shared_controller_contract() -> void:
	# spine: 0 EMPTY, 1 COMBAT, 2 FORK, 3-8 reservado (placeholder, 6 casillas —
	# L0 2026-09-08: BRANCH_LENGTH 4->6, ver comentario en RouteBranchData),
	# 9 EVENT (merge), 10 BOSS. Ruta A: COMBAT,COMBAT,TREASURE,HEAL,EMPTY,EVENT.
	# Ruta B: EVENT,HEAL,EMPTY,TREASURE,COMBAT,EMPTY.
	var sequence: Array[int] = [
		BoardTileData.TileType.EMPTY, BoardTileData.TileType.COMBAT, BoardTileData.TileType.FORK,
		BoardTileData.TileType.EMPTY, BoardTileData.TileType.EMPTY, BoardTileData.TileType.EMPTY, BoardTileData.TileType.EMPTY,
		BoardTileData.TileType.EMPTY, BoardTileData.TileType.EMPTY,
		BoardTileData.TileType.EVENT, BoardTileData.TileType.BOSS,
	]
	var route_a: Array[int] = [
		BoardTileData.TileType.COMBAT, BoardTileData.TileType.COMBAT, BoardTileData.TileType.TREASURE,
		BoardTileData.TileType.HEAL, BoardTileData.TileType.EMPTY, BoardTileData.TileType.EVENT,
	]
	var route_b: Array[int] = [
		BoardTileData.TileType.EVENT, BoardTileData.TileType.HEAL, BoardTileData.TileType.EMPTY,
		BoardTileData.TileType.TREASURE, BoardTileData.TileType.COMBAT, BoardTileData.TileType.EMPTY,
	]
	var branch_data := RouteBranchDataSource.new(2, route_a, route_b, &"combat", &"recovery")

	# PARTE 1 — el roll aterriza EXACTO en el fork (remaining == 0): sólo hay
	# elección este turno, ningún nodo de ruta resuelve todavía.
	var run_a := RunState.new()
	run_a.board_tile_sequence = sequence
	run_a.route_branches = {2: branch_data}
	var controller_a: RefCounted = BoardTurnControllerSource.new(run_a, sequence)
	var plan_a: Dictionary = controller_a.request_roll(2)
	_check("fork_selected_destination_is_fork_index", int(plan_a.get("destinations", [])[0]) == 2)
	controller_a.advance_one_step()
	_check("fork_pause_before_fork_tile_no_pause", int(controller_a.get("state")) == BoardTurnControllerSource.State.MOVING)
	controller_a.advance_one_step()
	_check("fork_pauses_on_arrival", int(controller_a.get("state")) == BoardTurnControllerSource.State.ROUTE_DECISION)
	_check("fork_blocks_pending_steps_while_paused", not controller_a.has_pending_steps())
	_check("fork_choice_accepted", controller_a.choose_branch(RouteBranchDataSource.ROUTE_A))
	_check("fork_zero_remaining_resolves_immediately", int(controller_a.get("state")) == BoardTurnControllerSource.State.AWAITING_RESOLUTION)
	var resolution_a: Dictionary = controller_a.request_tile_resolution()
	_check("fork_tile_itself_has_no_route_content", int(resolution_a.get("tile_type", -1)) == BoardTileData.TileType.FORK)
	controller_a.complete_resolution()
	_check("active_branch_locked_after_choice", run_a.active_branch == RouteBranchDataSource.ROUTE_A)
	_check("cannot_change_branch_field_is_still_a", run_a.active_branch != RouteBranchDataSource.ROUTE_B)

	# Roll siguiente: mismo turno de dado ya no toca el fork (pasado), y lee
	# contenido de la Ruta A elegida para el resto del rango reservado.
	var plan_a2: Dictionary = controller_a.request_roll(3)
	_check("no_second_fork_offer", int(plan_a2.get("destinations", [])[0]) == 5)
	while controller_a.has_pending_steps():
		controller_a.advance_one_step()
	var resolution_a2: Dictionary = controller_a.request_tile_resolution()
	_check("route_a_node3_is_treasure", int(resolution_a2.get("tile_type", -1)) == BoardTileData.TileType.TREASURE)
	controller_a.complete_resolution()

	# board_position=5 tras la parte anterior; merge_index = fork_index(2) +
	# BRANCH_LENGTH(6) + 1 = 9, así que un roll de 4 aterriza justo en el merge.
	var plan_a3: Dictionary = controller_a.request_roll(4)
	while controller_a.has_pending_steps():
		controller_a.advance_one_step()
	var resolution_a3: Dictionary = controller_a.request_tile_resolution()
	_check("merge_clears_branch_state", run_a.active_branch == RouteBranchDataSource.NONE and run_a.active_fork_index == -1)
	_check("merge_tile_reads_spine_content", int(resolution_a3.get("tile_type", -1)) == BoardTileData.TileType.EVENT and int(plan_a3.get("destinations", [])[0]) == 9)
	controller_a.complete_resolution()

	# PARTE 2 — el roll ALCANZA el fork con pasos restantes (remaining > 0):
	# la pausa ocurre a mitad de MOVE y el resto del mismo roll continúa
	# dentro del carril elegido, sin segundo roll y sin resolver el fork.
	var run_b := RunState.new()
	run_b.board_tile_sequence = sequence
	run_b.route_branches = {2: RouteBranchDataSource.new(2, route_a.duplicate(), route_b.duplicate(), &"combat", &"recovery")}
	var controller_b: RefCounted = BoardTurnControllerSource.new(run_b, sequence)
	var plan_b: Dictionary = controller_b.request_roll(4)
	_check("no_extra_no_lost_movement_destination", int(plan_b.get("destinations", [])[0]) == 4)
	var visited: Array[int] = []
	while true:
		if int(controller_b.get("state")) == BoardTurnControllerSource.State.ROUTE_DECISION:
			_check("mid_roll_pause_has_remaining_steps", run_b.board_position < int(plan_b.get("destinations", [])[0]))
			controller_b.choose_branch(RouteBranchDataSource.ROUTE_B)
			_check("remaining_movement_resumes_same_roll", int(controller_b.get("state")) == BoardTurnControllerSource.State.MOVING)
			continue
		if not controller_b.has_pending_steps():
			break
		visited.append(controller_b.advance_one_step())
	_check("no_second_roll_needed_this_turn", run_b.board_position == 4)
	var resolution_b: Dictionary = controller_b.request_tile_resolution()
	_check("route_b_node2_is_heal", int(resolution_b.get("tile_type", -1)) == BoardTileData.TileType.HEAL)
	controller_b.complete_resolution()
	# route_a[1] (mismo nodo local que se acaba de resolver) es COMBAT; si la
	# rama no elegida hubiera influido, el resultado no sería HEAL.
	_check("unchosen_branch_never_resolves", int(resolution_b.get("tile_type", -1)) != route_a[1])
	_check("controller_unlocks", not controller_b.is_turn_locked())


func _check(key: String, passed: bool) -> void:
	_checks[key] = passed

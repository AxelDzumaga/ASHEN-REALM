extends Node

## Cobertura específica: derrota mientras run.active_branch está fijado (el
## jugador murió en un nodo de rama, no en el spine compartido). Complementa
## map3d_defeat_flow_test.gd (que no pasa por ninguna rama) verificando que
## terminate_after_defeat() sigue siendo terminal y que el estado de rama no
## permite reabrir/seguir caminando la ruta.

const GAME_SCENE := preload("res://scenes/core/game.tscn")
const RouteBranchDataSource = preload("res://scripts/board/route_branch_data.gd")

var _failures: Array[String] = []


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"map3d_defeat_inside_branch")
	SaveManager.profile.completed_tutorials.clear()
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	var game: Control = GAME_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.call("_launch_map3d_prototype")
	await _frames(3)
	var map: Control = game.get("board_screen")
	var run: RunState = RunManager.current_run
	var controller: RefCounted = map.get("_turn_controller")

	# Fuerza un fork inmediatamente alcanzable y ya elegido, para no depender
	# de dónde cayó el fork real de esta seed ni de tener que jugar hasta él.
	var route_a: Array[int] = [BoardTileData.TileType.COMBAT, BoardTileData.TileType.COMBAT, BoardTileData.TileType.TREASURE, BoardTileData.TileType.HEAL]
	var route_b: Array[int] = [BoardTileData.TileType.EVENT, BoardTileData.TileType.HEAL, BoardTileData.TileType.EMPTY, BoardTileData.TileType.TREASURE]
	run.route_branches[2] = RouteBranchDataSource.new(2, route_a, route_b, &"combat", &"recovery")
	run.active_branch = RouteBranchDataSource.ROUTE_A
	run.active_fork_index = 2
	run.board_position = 3

	map.call("_request_external_interaction", &"combat", false, false)
	await _frames(3)
	_check("entered_combat_from_branch_node", game.get("current_screen").name == "Combat")
	var combat: Control = game.get("current_screen")
	for _frame: int in 600:
		if int(combat.get("_phase")) == 1 or bool(combat.get("_result_resolved")):
			break
		await get_tree().process_frame
	var player_actor: CombatActor = combat.get("player_actor")
	player_actor.set_current_hp(0)
	run.current_health = 0
	await combat.call("_finish_defeat")
	await get_tree().create_timer(0.7).timeout
	await _frames(3)

	var current: Control = game.get("current_screen")
	_check("run_result_defeat_visible", current.name == "RunResult" and current.visible)
	_check("map3d_not_restored", game.get("board_screen") == null and not is_instance_valid(map))
	_check("run_locked_after_defeat", run.board_locked)
	# El estado de rama queda "congelado" en el run terminado; lo importante
	# es que la run ya no sea jugable (board_locked) y no exista Map3D vivo
	# que pueda seguir leyendo ese carril.
	_check("active_branch_field_harmless_after_termination", run.active_branch == RouteBranchDataSource.ROUTE_A)

	print(JSON.stringify({"failures": _failures}))
	game.queue_free()
	RunManager.current_run = null
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _frames(count: int) -> void:
	for _index: int in count:
		await get_tree().process_frame


func _check(key: String, condition: bool) -> void:
	if not condition:
		_failures.append(key)

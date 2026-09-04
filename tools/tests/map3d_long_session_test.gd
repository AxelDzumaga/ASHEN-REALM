extends Node

const GAME_SCENE := preload("res://scenes/core/game.tscn")
const COMBAT_CYCLES := 24
const EVENT_CYCLES := 4
const TREASURE_CYCLES := 4


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"map3d_long_session")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	var failures: Array[String] = []
	var game: Control = GAME_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.call("_launch_map3d_prototype")
	await get_tree().process_frame
	await get_tree().process_frame
	var map: Control = game.get("board_screen") as Control
	var nodes_before: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var resources_before: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var max_nodes := nodes_before

	for cycle: int in COMBAT_CYCLES:
		game.call("show_combat", false, cycle % 6 == 5)
		await get_tree().process_frame
		_check(failures, "combat_open_%d" % cycle, game.get("current_screen").name == "Combat")
		_check(failures, "hud_hidden_%d" % cycle, not map.get_node("HUDLayer").visible)
		game.call("_on_upgrade_selected", null)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(failures, "combat_return_%d" % cycle, game.get("current_screen") == map and map.get_node("HUDLayer").visible)
		max_nodes = maxi(max_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))

	for cycle: int in EVENT_CYCLES:
		game.call("show_event")
		await get_tree().process_frame
		game.call("_on_event_resolved")
		await get_tree().process_frame
		await get_tree().process_frame
		_check(failures, "event_return_%d" % cycle, game.get("current_screen") == map)

	for cycle: int in TREASURE_CYCLES:
		game.call("show_treasure")
		await get_tree().process_frame
		game.call("_on_treasure_continue_requested")
		await get_tree().process_frame
		await get_tree().process_frame
		_check(failures, "treasure_return_%d" % cycle, game.get("current_screen") == map)

	var nodes_after: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var resources_after: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var combat_connections: int = map.combat_requested.get_connections().size()
	var event_connections: int = map.event_requested.get_connections().size()
	var treasure_connections: int = map.treasure_requested.get_connections().size()
	_check(failures, "same_map_instance", game.get("board_screen") == map)
	_check(failures, "node_count_stable", nodes_after <= nodes_before + 4)
	_check(failures, "resource_count_stable", resources_after <= resources_before + 8)
	_check(failures, "single_signal_connections", combat_connections == 1 and event_connections == 1 and treasure_connections == 1)
	print(JSON.stringify({
		"failures": failures,
		"combat_cycles": COMBAT_CYCLES,
		"event_cycles": EVENT_CYCLES,
		"treasure_cycles": TREASURE_CYCLES,
		"nodes_before": nodes_before,
		"nodes_after": nodes_after,
		"max_nodes": max_nodes,
		"resources_before": resources_before,
		"resources_after": resources_after,
		"signal_connections": [combat_connections, event_connections, treasure_connections],
	}))
	game.queue_free()
	RunManager.current_run = null
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(failures: Array[String], key: String, passed: bool) -> void:
	if not passed:
		failures.append(key)

extends Node

const GAME_SCENE := preload("res://scenes/core/game.tscn")

var _failures: Array[String] = []
var _combat_requested_count := 0
var _combat_screen_count := 0
var _prototype_result_count := 0
var _terminal_snapshot: Dictionary = {}


func _ready() -> void:
	var game: Control = GAME_SCENE.instantiate()
	game.child_entered_tree.connect(_on_game_child_entered)
	add_child(game)
	await get_tree().process_frame
	game.call("_launch_map3d_prototype")
	# Map3D Production Runtime §6: _launch_map3d_prototype() now isolates
	# SaveManager.profile itself (see game.gd), superseding a pre-launch
	# use_isolated_test_profile() call — set the tutorial-skip state on
	# the profile it actually isolates to, after the call, not before.
	SaveManager.profile.completed_tutorials.clear()
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	await _frames(3)
	var map: Control = game.get("board_screen")
	var run: RunState = RunManager.current_run
	var controller: RefCounted = map.get("_turn_controller")
	map.combat_requested.connect(func(_boss: bool, _elite: bool) -> void: _combat_requested_count += 1)
	map.tree_exiting.connect(func() -> void:
		_terminal_snapshot = {
			"interaction_pending": map.get("_interaction_pending"),
			"moving": map.get("_is_moving"),
			"pending_routes": (map.get("_pending_route_destinations") as Array).size(),
			"controller_locked": controller.is_turn_locked(),
			"roll_disabled": (map.get("_roll_button") as Button).disabled,
			"hud_visible": map.get_node("HUDLayer").visible,
		}
	)

	map.call("_request_external_interaction", &"combat", false, false)
	await _frames(3)
	_check("entered_combat_from_map3d", game.get("current_screen").name == "Combat")
	_check("combat_requested_once", _combat_requested_count == 1)
	var combat: Control = game.get("current_screen")
	for _frame: int in 600:
		if int(combat.get("_phase")) == 1 or bool(combat.get("_result_resolved")):
			break
		await get_tree().process_frame
	_check("combat_reaches_player_input", int(combat.get("_phase")) == 1)
	var player_actor: CombatActor = combat.get("player_actor")
	player_actor.set_current_hp(0)
	run.current_health = 0
	await combat.call("_finish_defeat")
	await get_tree().create_timer(0.7).timeout
	await _frames(3)

	var current: Control = game.get("current_screen")
	var overlay: ColorRect = game.get("transition_overlay")
	# Map3D Production Runtime §6 data-safety fix: a --map3d-prototype
	# defeat used to fall through to the real RunResult (which deposits
	# into the real SaveManager.profile) — it must now stay sandboxed via
	# _show_map3d_prototype_result(false), the same screen victory already
	# used. See map3d_prototype_data_safety_test.gd for the full permanent-
	# ProfileData snapshot proof.
	_check("prototype_result_defeat_visible", current.name == "Map3DPrototypeResult" and current.visible)
	_check("single_result_transition", _prototype_result_count == 1)
	_check("map3d_not_restored", game.get("board_screen") == null and not is_instance_valid(map))
	_check("map3d_terminated_snapshot", (
		bool(_terminal_snapshot.get("interaction_pending", false))
		and not bool(_terminal_snapshot.get("moving", true))
		and int(_terminal_snapshot.get("pending_routes", -1)) == 0
		and bool(_terminal_snapshot.get("controller_locked", false))
		and bool(_terminal_snapshot.get("roll_disabled", false))
		and not bool(_terminal_snapshot.get("hud_visible", true))
	))
	_check("run_locked_after_defeat", run.board_locked)
	_check("no_second_combat_request", _combat_requested_count == 1)
	_check("single_combat_screen", _combat_screen_count == 1)
	_check("no_black_screen", current.visible and overlay.modulate.a <= 0.01 and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_check("no_profile_deposit", not run.rewards_deposited)
	var capture_error := OK
	if "--capture-defeat-result" in OS.get_cmdline_user_args():
		var output_path := ProjectSettings.globalize_path("res://build/map3d_playtest/visual/11_defeat_results.png")
		capture_error = get_viewport().get_texture().get_image().save_png(output_path)
		_check("defeat_capture_saved", capture_error == OK)

	print(JSON.stringify({
		"failures": _failures,
		"combat_requested_count": _combat_requested_count,
		"combat_screen_count": _combat_screen_count,
		"prototype_result_count": _prototype_result_count,
		"current_screen": current.name,
		"board_alive": is_instance_valid(map),
		"terminal_snapshot": _terminal_snapshot,
		"transition_alpha": overlay.modulate.a,
		"rewards_deposited": run.rewards_deposited,
		"capture_error": capture_error,
	}))
	game.queue_free()
	RunManager.current_run = null
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _on_game_child_entered(node: Node) -> void:
	if node.name == "Combat":
		_combat_screen_count += 1
	elif node.name == "Map3DPrototypeResult":
		_prototype_result_count += 1


func _frames(count: int) -> void:
	for _index: int in count:
		await get_tree().process_frame


func _check(key: String, condition: bool) -> void:
	if not condition:
		_failures.append(key)

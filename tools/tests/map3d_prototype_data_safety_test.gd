extends Node

## Map3D Production Runtime §6/§7: dedicated regression for the data-safety
## bug this milestone fixed. --map3d-prototype never selects a character
## (CharacterProfileRepository.startup() is skipped entirely in that launch
## path), yet before this fix a *defeat* fell through to the real
## show_run_result(false) -> SaveManager.deposit_run(), which mutates
## whichever profile SaveManager currently has loaded. This proves, with a
## real selected-character ProfileData snapshot taken before and after a
## full prototype session (victory AND defeat), that a prototype run never
## deposits XP/Ash/equipment/milestones and never creates a production
## active_run.json — not by re-reading the fix's code, by executing it.

const GAME_SCENE := preload("res://scenes/core/game.tscn")

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	await _test_prototype_defeat_does_not_mutate_profile()
	await _test_prototype_victory_does_not_mutate_profile()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _boot_game() -> Control:
	var game: Control = GAME_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	return game


func _press(game: Control, unique_path: String) -> void:
	var button: BaseButton = game.current_screen.get_node(unique_path)
	button.emit_signal("pressed")


## CharacterProfileRepository.select_character() itself always bumps and
## persists last_played_at (unrelated to whether a prototype run ever
## touched anything) — every call in this test to grab a snapshot re-runs
## select_character() once, so this field would legitimately differ
## between the "before" and "after" snapshots even with zero prototype
## involvement. Excluded here so the comparison isolates exactly what
## this test is about: everything a prototype run itself could mutate.
func _normalized_snapshot() -> String:
	var snapshot: Dictionary = SaveManager.profile.to_dictionary()
	snapshot.erase("last_played_at")
	return JSON.stringify(snapshot)


## Selects a real, isolated character (so the snapshot is of an actual
## on-disk ProfileData, not an in-memory default) and returns its
## to_dictionary() snapshot plus the character_id.
func _select_sentinel_character(test_root: String, name: String) -> Dictionary:
	CharacterProfileRepository.use_isolated_test_root(test_root)
	ActiveRunRepository.use_isolated_test_root(test_root)
	var game: Control = await _boot_game()
	_press(game, "%StartGameButton")
	await get_tree().process_frame
	var name_edit: LineEdit = game.current_screen.get_node("%NameEdit")
	name_edit.text = name
	_press(game, "%ConfirmButton")
	await get_tree().process_frame
	var character_id: String = CharacterProfileRepository.selected_character_id
	var snapshot: String = _normalized_snapshot()
	game.queue_free()
	await get_tree().process_frame
	# Faithful reproduction of a cold --map3d-prototype launch: that launch
	# path never calls CharacterProfileRepository.startup(), so
	# selected_character_id is genuinely empty at that point. Reset it here
	# rather than letting the previous scene's selection leak across
	# instances within this single test process.
	CharacterProfileRepository.selected_character_id = ""
	return {"character_id": character_id, "snapshot": snapshot}


func _run_prototype_scenario(victory: bool) -> void:
	var suffix: String = "victory" if victory else "defeat"
	var before: Dictionary = await _select_sentinel_character(
		"prototype_data_safety_%s" % suffix, "Sentinel %s" % suffix.capitalize(),
	)
	var character_id: String = before["character_id"]
	var before_snapshot: String = before["snapshot"]

	var game: Control = await _boot_game()
	game.call("_launch_map3d_prototype")
	await get_tree().process_frame
	_check("%s_selected_character_still_empty_during_prototype" % suffix, CharacterProfileRepository.selected_character_id.is_empty())
	var map: Control = game.get("board_screen")
	_check("%s_prototype_uses_map3d" % suffix, map.name == "AshenWastesMap3D")

	# Drive game.gd's own production handlers directly (the same proven
	# pattern map3d_return_flow_test.gd already uses) rather than playing
	# through Combat2D's real turn resolution — this test is about profile
	# isolation, not combat mechanics.
	if victory:
		game.call("show_combat", true, false)
		await get_tree().process_frame
		game.call("_on_combat_won", true, false)
		await get_tree().process_frame
		_check("%s_boss_reward_opened" % suffix, game.current_screen.name == "BossReward")
		game.call("_on_boss_reward_selected", null)
		await get_tree().process_frame
	else:
		game.call("show_combat", false, false)
		await get_tree().process_frame
		game.call("_on_combat_lost", false, false)
		await get_tree().process_frame

	_check("%s_result_is_prototype_screen_not_run_result" % suffix, game.current_screen.name == "Map3DPrototypeResult")
	_check("%s_run_not_marked_deposited" % suffix, not RunManager.current_run.rewards_deposited)
	_check("%s_no_active_run_created_for_sentinel" % suffix, not ActiveRunRepository.has_active_run(character_id))
	game.queue_free()
	await get_tree().process_frame

	# Re-select the same character and compare its permanent ProfileData
	# against the pre-prototype snapshot. Deliberately does NOT call
	# use_isolated_test_root() again here — it wipes and recreates the
	# root directory every time (by design, so a reused test name starts
	# fresh run-to-run), which would delete the sentinel character this
	# same scenario just created. The root set inside
	# _select_sentinel_character() is still current; _launch_map3d_prototype()
	# only ever isolates SaveManager, never CharacterProfileRepository's root.
	CharacterProfileRepository.select_character(character_id)
	var after_snapshot: String = _normalized_snapshot()
	if after_snapshot != before_snapshot:
		_print_snapshot_diff(suffix, before_snapshot, after_snapshot)
	_check("%s_permanent_profile_unchanged" % suffix, after_snapshot == before_snapshot)


func _print_snapshot_diff(suffix: String, before_json: String, after_json: String) -> void:
	var before: Dictionary = JSON.parse_string(before_json)
	var after: Dictionary = JSON.parse_string(after_json)
	var diffs: Dictionary = {}
	var keys: Dictionary = {}
	for key: String in before:
		keys[key] = true
	for key: String in after:
		keys[key] = true
	for key: String in keys:
		var before_value: Variant = before.get(key)
		var after_value: Variant = after.get(key)
		if JSON.stringify(before_value) != JSON.stringify(after_value):
			diffs[key] = {"before": before_value, "after": after_value}
	print("SNAPSHOT_DIFF[%s] %s" % [suffix, JSON.stringify(diffs)])


func _test_prototype_defeat_does_not_mutate_profile() -> void:
	await _run_prototype_scenario(false)


func _test_prototype_victory_does_not_mutate_profile() -> void:
	await _run_prototype_scenario(true)

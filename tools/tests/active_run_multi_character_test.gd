extends Node

## §61/§23: two characters, each with an independent active run, proven
## never to cross-contaminate across repeated switches; deleting a
## character removes its active run as a structural consequence of
## CharacterProfileRepository's existing recursive directory delete
## (not a separate mechanism to maintain in parallel). Also covers §63
## (measure a realistic active_run.json size).

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	_test_a_b_switch_never_cross_writes()
	_test_deleting_character_removes_its_active_run()
	_test_deleting_character_leaves_sibling_active_run_intact()
	_measure_active_run_file_size()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _rich_run(run_id: String, board_position: int) -> RunState:
	var run := RunState.new()
	run.run_id = run_id
	run.biome_id = BiomeCatalog.ASHEN_WASTES.id
	run.biome_data = BiomeCatalog.ASHEN_WASTES
	var sequence: Array[int] = []
	for _i: int in 30:
		sequence.append(BoardTileData.TileType.EMPTY)
	run.board_tile_sequence = sequence
	run.board_position = board_position
	run.current_health = 50 + board_position
	run.active_boons = {&"burning_strike": 2}
	run.telemetry_skill_uses = {"ember_slash": 3}
	return run


func _test_a_b_switch_never_cross_writes() -> void:
	CharacterProfileRepository.use_isolated_test_root("multi_char_active_run")
	ActiveRunRepository.use_isolated_test_root("multi_char_active_run")
	var a_result: Dictionary = CharacterProfileRepository.create_character("Alpha")
	var b_result: Dictionary = CharacterProfileRepository.create_character("Beta")
	var char_a: String = String(a_result.get("character_id", ""))
	var char_b: String = String(b_result.get("character_id", ""))

	ActiveRunRepository.create_run_checkpoint(char_a, _rich_run("run_a", 3))
	ActiveRunRepository.create_run_checkpoint(char_b, _rich_run("run_b", 9))

	for _cycle: int in 3:
		var loaded_a: Dictionary = ActiveRunRepository.load_active_run(char_a)
		var run_a: RunState = loaded_a.get("run")
		_check("a_board_position_stable_cycle_%d" % _cycle, run_a != null and run_a.board_position == 3)
		run_a.current_health -= 1
		ActiveRunRepository.checkpoint(char_a, run_a, ActiveRunRepository.PHASE_ON_BOARD, "test_tick")

		var loaded_b: Dictionary = ActiveRunRepository.load_active_run(char_b)
		var run_b: RunState = loaded_b.get("run")
		_check("b_board_position_stable_cycle_%d" % _cycle, run_b != null and run_b.board_position == 9)

	var final_a: Dictionary = ActiveRunRepository.load_active_run(char_a)
	var final_b: Dictionary = ActiveRunRepository.load_active_run(char_b)
	_check("a_final_run_id_correct", String(final_a.get("run_id", "")) == "run_a")
	_check("b_final_run_id_correct", String(final_b.get("run_id", "")) == "run_b")
	var final_run_a: RunState = final_a.get("run")
	var final_run_b: RunState = final_b.get("run")
	_check("a_health_decremented_by_exactly_three_a_writes", final_run_a != null and final_run_a.current_health == 53 - 3)
	_check("b_health_untouched_by_a_writes", final_run_b != null and final_run_b.current_health == 59)


func _test_deleting_character_removes_its_active_run() -> void:
	CharacterProfileRepository.use_isolated_test_root("delete_removes_run")
	ActiveRunRepository.use_isolated_test_root("delete_removes_run")
	var result: Dictionary = CharacterProfileRepository.create_character("Doomed")
	var character_id: String = String(result.get("character_id", ""))
	ActiveRunRepository.create_run_checkpoint(character_id, _rich_run("run_doomed", 5))
	_check("active_run_exists_before_character_delete", ActiveRunRepository.has_active_run(character_id))

	CharacterProfileRepository.delete_character(character_id)
	_check("active_run_gone_after_character_delete", not ActiveRunRepository.has_active_run(character_id))
	_check("active_run_file_itself_gone", not FileAccess.file_exists(ActiveRunRepository.character_run_path(character_id)))


func _test_deleting_character_leaves_sibling_active_run_intact() -> void:
	CharacterProfileRepository.use_isolated_test_root("delete_leaves_sibling")
	ActiveRunRepository.use_isolated_test_root("delete_leaves_sibling")
	var a_result: Dictionary = CharacterProfileRepository.create_character("Keep")
	var b_result: Dictionary = CharacterProfileRepository.create_character("Delete")
	var char_a: String = String(a_result.get("character_id", ""))
	var char_b: String = String(b_result.get("character_id", ""))
	ActiveRunRepository.create_run_checkpoint(char_a, _rich_run("run_keep", 7))
	ActiveRunRepository.create_run_checkpoint(char_b, _rich_run("run_delete", 11))

	CharacterProfileRepository.delete_character(char_b)
	_check("sibling_active_run_survives_other_deletion", ActiveRunRepository.has_active_run(char_a))
	var loaded_a: Dictionary = ActiveRunRepository.load_active_run(char_a)
	_check("sibling_active_run_data_intact", String(loaded_a.get("run_id", "")) == "run_keep")


func _measure_active_run_file_size() -> void:
	CharacterProfileRepository.use_isolated_test_root("size_measurement")
	ActiveRunRepository.use_isolated_test_root("size_measurement")
	var result: Dictionary = CharacterProfileRepository.create_character("SizeCheck")
	var character_id: String = String(result.get("character_id", ""))
	var run: RunState = _rich_run("run_size", 15)
	run.pending_treasure_offers = [
		{"id": "boon:ember_focus", "kind": "boon", "reward_id": "ember_focus", "label": "BRASA", "description": "una descripcion mas larga para simular contenido real"},
		{"id": "ash", "kind": "ash", "reward_id": "", "label": "CENIZA", "description": "otra descripcion"},
	]
	ActiveRunRepository.create_run_checkpoint(character_id, run)
	var path: String = ProjectSettings.globalize_path(ActiveRunRepository.character_run_path(character_id))
	var size_bytes: int = FileAccess.get_file_as_bytes(path).size()
	print("ACTIVE_RUN_FILE_SIZE_BYTES=%d" % size_bytes)
	_check("active_run_file_comfortably_small", size_bytes < 20_000)

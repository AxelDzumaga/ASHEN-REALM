extends Node

## ActiveRunRepository: checkpoint/load/delete lifecycle, §46 invariants,
## corruption recovery, content-drift (§24/§26), and version-mismatch
## handling. Isolated via ActiveRunRepository.use_isolated_test_root() —
## never touches a real character's real active_run.json.

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	_test_create_and_load_round_trip()
	_test_create_run_checkpoint_refuses_overwrite()
	_test_generic_checkpoint_allows_overwrite_of_same_run()
	_test_delete_removes_all_siblings()
	_test_no_character_id_rejected()
	_test_two_characters_never_cross_write()
	_test_corrupt_main_recovers_from_backup()
	_test_totally_corrupt_run_does_not_crash()
	_test_missing_essential_biome_treated_unrecoverable()
	_test_future_version_fails_safely()
	_test_invalid_phase_rejected()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _build_run(run_id: String, board_position: int = 4) -> RunState:
	var run := RunState.new()
	run.run_id = run_id
	run.biome_id = BiomeCatalog.ASHEN_WASTES.id
	run.biome_data = BiomeCatalog.ASHEN_WASTES
	run.board_tile_sequence = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	run.board_position = board_position
	run.current_health = 88
	run.max_health = 140
	return run


func _test_create_and_load_round_trip() -> void:
	ActiveRunRepository.use_isolated_test_root("create_load")
	var run: RunState = _build_run("run_one")
	_check("has_active_run_false_before_create", not ActiveRunRepository.has_active_run("char_a"))
	var created: bool = ActiveRunRepository.create_run_checkpoint("char_a", run)
	_check("create_run_checkpoint_succeeds", created)
	_check("has_active_run_true_after_create", ActiveRunRepository.has_active_run("char_a"))

	var loaded: Dictionary = ActiveRunRepository.load_active_run("char_a")
	_check("loaded_exists", bool(loaded.get("exists", false)))
	_check("loaded_recoverable", bool(loaded.get("recoverable", false)))
	_check("loaded_phase_on_board", String(loaded.get("phase", "")) == ActiveRunRepository.PHASE_ON_BOARD)
	_check("loaded_run_id", String(loaded.get("run_id", "")) == "run_one")
	var loaded_run: RunState = loaded.get("run")
	_check("loaded_run_board_position", loaded_run != null and loaded_run.board_position == 4)
	_check("loaded_run_current_health", loaded_run != null and loaded_run.current_health == 88)


func _test_create_run_checkpoint_refuses_overwrite() -> void:
	ActiveRunRepository.use_isolated_test_root("refuse_overwrite")
	ActiveRunRepository.create_run_checkpoint("char_a", _build_run("run_first"))
	var second_attempt: bool = ActiveRunRepository.create_run_checkpoint("char_a", _build_run("run_second"))
	_check("second_create_run_checkpoint_refused", not second_attempt)
	var loaded: Dictionary = ActiveRunRepository.load_active_run("char_a")
	_check("original_run_untouched_after_refused_overwrite", String(loaded.get("run_id", "")) == "run_first")


func _test_generic_checkpoint_allows_overwrite_of_same_run() -> void:
	ActiveRunRepository.use_isolated_test_root("allow_progress_overwrite")
	var run: RunState = _build_run("run_progress")
	ActiveRunRepository.create_run_checkpoint("char_a", run)
	run.board_position = 7
	var updated: bool = ActiveRunRepository.checkpoint("char_a", run, ActiveRunRepository.PHASE_ON_BOARD, "movement_completed")
	_check("progress_checkpoint_succeeds", updated)
	var loaded: Dictionary = ActiveRunRepository.load_active_run("char_a")
	var loaded_run: RunState = loaded.get("run")
	_check("progress_checkpoint_reflects_new_position", loaded_run != null and loaded_run.board_position == 7)


func _test_delete_removes_all_siblings() -> void:
	ActiveRunRepository.use_isolated_test_root("delete_siblings")
	var run: RunState = _build_run("run_delete")
	ActiveRunRepository.create_run_checkpoint("char_a", run)
	run.board_position = 6
	ActiveRunRepository.checkpoint("char_a", run, ActiveRunRepository.PHASE_ON_BOARD, "movement_completed")  # creates a .bak too
	var path: String = ActiveRunRepository.character_run_path("char_a")
	_check("bak_exists_before_delete", FileAccess.file_exists(path + ".bak"))
	var deleted: bool = ActiveRunRepository.delete_active_run("char_a")
	_check("delete_reports_success", deleted)
	_check("main_gone_after_delete", not FileAccess.file_exists(path))
	_check("bak_gone_after_delete", not FileAccess.file_exists(path + ".bak"))
	_check("has_active_run_false_after_delete", not ActiveRunRepository.has_active_run("char_a"))


func _test_no_character_id_rejected() -> void:
	ActiveRunRepository.use_isolated_test_root("no_character_id")
	_check("checkpoint_rejects_empty_character_id", not ActiveRunRepository.checkpoint("", _build_run("run_x"), ActiveRunRepository.PHASE_ON_BOARD, "test"))
	_check("create_run_rejects_empty_character_id", not ActiveRunRepository.create_run_checkpoint("", _build_run("run_x")))
	_check("load_rejects_empty_character_id", not bool(ActiveRunRepository.load_active_run("").get("exists", true)))
	_check("delete_rejects_empty_character_id", not ActiveRunRepository.delete_active_run(""))
	_check("has_active_run_rejects_empty_character_id", not ActiveRunRepository.has_active_run(""))


func _test_two_characters_never_cross_write() -> void:
	ActiveRunRepository.use_isolated_test_root("cross_write_isolation")
	var run_a: RunState = _build_run("run_a_id", 2)
	var run_b: RunState = _build_run("run_b_id", 9)
	ActiveRunRepository.create_run_checkpoint("char_a", run_a)
	ActiveRunRepository.create_run_checkpoint("char_b", run_b)

	run_a.board_position = 3
	ActiveRunRepository.checkpoint("char_a", run_a, ActiveRunRepository.PHASE_ON_BOARD, "movement_completed")

	var loaded_b: Dictionary = ActiveRunRepository.load_active_run("char_b")
	var loaded_b_run: RunState = loaded_b.get("run")
	_check("b_untouched_by_a_checkpoint", loaded_b_run != null and loaded_b_run.board_position == 9)

	ActiveRunRepository.delete_active_run("char_a")
	_check("deleting_a_leaves_b_intact", ActiveRunRepository.has_active_run("char_b"))
	var loaded_b_after_a_delete: Dictionary = ActiveRunRepository.load_active_run("char_b")
	var loaded_b_run_after_delete: RunState = loaded_b_after_a_delete.get("run")
	_check("b_still_correct_after_a_deleted", loaded_b_run_after_delete != null and loaded_b_run_after_delete.board_position == 9)


func _test_corrupt_main_recovers_from_backup() -> void:
	ActiveRunRepository.use_isolated_test_root("corrupt_main_recovers")
	var run: RunState = _build_run("run_corrupt_main")
	ActiveRunRepository.create_run_checkpoint("char_a", run)
	run.board_position = 5
	ActiveRunRepository.checkpoint("char_a", run, ActiveRunRepository.PHASE_ON_BOARD, "movement_completed")  # now .bak has board_position=4

	var path: String = ActiveRunRepository.character_run_path("char_a")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{not valid json")
	file.close()

	var loaded: Dictionary = ActiveRunRepository.load_active_run("char_a")
	_check("recovers_from_backup_after_main_corrupt", bool(loaded.get("recoverable", false)))
	var loaded_run: RunState = loaded.get("run")
	_check("recovered_backup_has_expected_position", loaded_run != null and loaded_run.board_position == 4)


func _test_totally_corrupt_run_does_not_crash() -> void:
	ActiveRunRepository.use_isolated_test_root("totally_corrupt")
	var path: String = ActiveRunRepository.character_run_path("char_a")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{not valid json at all")
	file.close()
	var loaded: Dictionary = ActiveRunRepository.load_active_run("char_a")
	_check("totally_corrupt_exists_true", bool(loaded.get("exists", false)))
	_check("totally_corrupt_not_recoverable", not bool(loaded.get("recoverable", true)))
	_check("totally_corrupt_run_is_null", loaded.get("run") == null)


func _test_missing_essential_biome_treated_unrecoverable() -> void:
	ActiveRunRepository.use_isolated_test_root("missing_biome")
	var run: RunState = _build_run("run_missing_biome")
	run.biome_id = &"nonexistent_biome_xyz"
	run.biome_data = null
	ActiveRunRepository.create_run_checkpoint("char_a", run)
	var loaded: Dictionary = ActiveRunRepository.load_active_run("char_a")
	_check("missing_biome_reported_as_unrecoverable", not bool(loaded.get("recoverable", true)))
	_check("missing_biome_file_still_exists", bool(loaded.get("exists", false)))


func _test_future_version_fails_safely() -> void:
	ActiveRunRepository.use_isolated_test_root("future_version")
	var path: String = ActiveRunRepository.character_run_path("char_a")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var payload: Dictionary = {
		"active_run_version": 999,
		"run_id": "run_future",
		"phase": ActiveRunRepository.PHASE_ON_BOARD,
		"run_state": _build_run("run_future").to_dictionary(),
	}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	var loaded: Dictionary = ActiveRunRepository.load_active_run("char_a")
	_check("future_version_not_recoverable", not bool(loaded.get("recoverable", true)))
	_check("future_version_run_null", loaded.get("run") == null)


func _test_invalid_phase_rejected() -> void:
	ActiveRunRepository.use_isolated_test_root("invalid_phase")
	var rejected: bool = ActiveRunRepository.checkpoint("char_a", _build_run("run_bad_phase"), "NOT_A_REAL_PHASE", "test")
	_check("invalid_phase_checkpoint_rejected", not rejected)
	_check("invalid_phase_no_file_written", not ActiveRunRepository.has_active_run("char_a"))

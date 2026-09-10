extends Node

const AtomicJsonStoreSource = preload("res://scripts/save/atomic_json_store.gd")

## Standalone coverage for AtomicJsonStore before it gets wired into
## SaveManager (refactor) and ActiveRunRepository (new code). Uses its own
## isolated scratch directory under user://test_atomic_json_store/ — never
## touches a real save of any kind.

var _failures: Array[String] = []
var _checks: Dictionary = {}
var _root: String = "user://test_atomic_json_store"


func _ready() -> void:
	_wipe_root()
	_test_fresh_write_and_read()
	_test_second_write_creates_backup()
	_test_corrupt_main_recovered_from_backup()
	_test_corrupt_main_recovered_from_temp()
	_test_no_valid_copy_reports_not_found()
	_test_future_version_surfaced_readonly()
	_test_preserve_corrupt_main_keeps_diagnostic_copy()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _wipe_root() -> void:
	var abs_path: String = ProjectSettings.globalize_path(_root)
	_delete_recursive(abs_path)
	DirAccess.make_dir_recursive_absolute(abs_path)


func _delete_recursive(absolute_path: String) -> void:
	var dir: DirAccess = DirAccess.open(absolute_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		if entry_name != "." and entry_name != "..":
			var full_path: String = absolute_path.path_join(entry_name)
			if dir.current_is_dir():
				_delete_recursive(full_path)
			else:
				DirAccess.remove_absolute(full_path)
		entry_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _test_fresh_write_and_read() -> void:
	var path: String = "%s/fresh.json" % _root
	var ok: bool = AtomicJsonStoreSource.write_safely(path, {"value": 42}, "v", 1)
	_check("fresh_write_succeeds", ok)
	var loaded: Dictionary = AtomicJsonStoreSource.load_best_candidate(path, "v", 1)
	_check("fresh_read_found", bool(loaded.get("found", false)))
	_check("fresh_read_source_main", String(loaded.get("source", "")) == "main")
	_check("fresh_read_value_correct", int(Dictionary(loaded.get("data", {})).get("value", -1)) == 42)


func _test_second_write_creates_backup() -> void:
	var path: String = "%s/rotate.json" % _root
	AtomicJsonStoreSource.write_safely(path, {"value": 1}, "v", 1)
	AtomicJsonStoreSource.write_safely(path, {"value": 2}, "v", 1)
	_check("backup_file_exists_after_second_write", FileAccess.file_exists(path + ".bak"))
	var backup: Dictionary = AtomicJsonStoreSource.read_candidate(path + ".bak", "v", false)
	_check("backup_holds_previous_value", int(Dictionary(backup.get("data", {})).get("value", -1)) == 1)
	var main: Dictionary = AtomicJsonStoreSource.read_candidate(path, "v", false)
	_check("main_holds_latest_value", int(Dictionary(main.get("data", {})).get("value", -1)) == 2)


func _test_corrupt_main_recovered_from_backup() -> void:
	var path: String = "%s/corrupt_main_backup.json" % _root
	AtomicJsonStoreSource.write_safely(path, {"value": 1}, "v", 1)
	AtomicJsonStoreSource.write_safely(path, {"value": 2}, "v", 1)
	_corrupt_file(path)
	var loaded: Dictionary = AtomicJsonStoreSource.load_best_candidate(path, "v", 1)
	_check("corrupt_main_recovers_from_backup_found", bool(loaded.get("found", false)))
	_check("corrupt_main_recovers_from_backup_source", String(loaded.get("source", "")) == "backup")
	_check("corrupt_main_recovers_from_backup_value", int(Dictionary(loaded.get("data", {})).get("value", -1)) == 1)
	_check("corrupt_main_preserved_as_diagnostic", _has_corrupt_sibling(path))


func _test_corrupt_main_recovered_from_temp() -> void:
	# Simulate "crash after TEMP write succeeded, before promotion":
	# a valid TEMP exists, MAIN itself never got there / is missing.
	var path: String = "%s/temp_recovery.json" % _root
	AtomicJsonStoreSource.write_safely(path + "._seed", {"unused": true}, "v", 1)  # just to ensure dir exists
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"value": 99, "v": 1}, "\t"))
	file.close()
	var loaded: Dictionary = AtomicJsonStoreSource.load_best_candidate(path, "v", 1)
	_check("temp_only_recovers_found", bool(loaded.get("found", false)))
	_check("temp_only_recovers_source", String(loaded.get("source", "")) == "temporary")
	_check("temp_only_recovers_value", int(Dictionary(loaded.get("data", {})).get("value", -1)) == 99)
	_check("temp_only_promoted_to_main", FileAccess.file_exists(path))


func _test_no_valid_copy_reports_not_found() -> void:
	var path: String = "%s/nothing_valid.json" % _root
	_corrupt_file(path)
	var loaded: Dictionary = AtomicJsonStoreSource.load_best_candidate(path, "v", 1)
	_check("no_valid_copy_not_found", not bool(loaded.get("found", false)))
	_check("no_valid_copy_main_flagged_corrupt", bool(loaded.get("main_was_corrupt", false)))


func _test_future_version_surfaced_readonly() -> void:
	var path: String = "%s/future_version.json" % _root
	AtomicJsonStoreSource.write_safely(path, {"value": 1}, "v", 5)
	var loaded: Dictionary = AtomicJsonStoreSource.load_best_candidate(path, "v", 1)
	_check("future_version_found", bool(loaded.get("found", false)))
	_check("future_version_source", String(loaded.get("source", "")) == "main")
	_check("future_version_reports_version_5", int(loaded.get("version", 0)) == 5)


func _test_preserve_corrupt_main_keeps_diagnostic_copy() -> void:
	var path: String = "%s/preserve.json" % _root
	AtomicJsonStoreSource.write_safely(path, {"value": 7}, "v", 1)
	var preserved: bool = AtomicJsonStoreSource.preserve_corrupt_main(path)
	_check("preserve_corrupt_main_succeeds", preserved)
	_check("preserve_corrupt_main_removes_original", not FileAccess.file_exists(path))
	_check("preserve_corrupt_main_leaves_diagnostic", _has_corrupt_sibling(path))


func _corrupt_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{not valid json at all")
	file.close()


func _has_corrupt_sibling(path: String) -> bool:
	var abs_dir: String = ProjectSettings.globalize_path(path.get_base_dir())
	var base_name: String = path.get_file().trim_suffix(".json")
	var dir: DirAccess = DirAccess.open(abs_dir)
	if dir == null:
		return false
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	var found: bool = false
	while entry_name != "":
		if entry_name.begins_with("%s.corrupt." % base_name):
			found = true
		entry_name = dir.get_next()
	dir.list_dir_end()
	return found

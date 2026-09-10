class_name AtomicJsonStore
extends RefCounted

## Low-level filesystem-atomicity primitive, extracted from SaveManager's
## original _write_profile_safely()/_read_candidate() implementation so
## ActiveRunRepository (and SaveManager itself) share one write/validate/
## backup/promote algorithm instead of two hand-written ones. Owns nothing
## about ProfileData, RunState, or any other domain shape — every method
## here operates on a plain Dictionary and a version integer under a
## caller-chosen key, nothing more.
##
## Pattern (identical in spirit to the pre-refactor SaveManager):
## write TEMP -> validate TEMP round-trips -> rotate old MAIN to BACKUP ->
## promote TEMP to MAIN. On any failure, MAIN (or, if MAIN was itself
## invalid, whatever recovery candidate was already found) is left intact.

const MAIN_SUFFIX := ""
const TEMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"


## Writes `data` (with `version` stamped under `version_key`) to `path`
## using the TEMP -> validate -> rotate BACKUP -> promote MAIN sequence.
## `corrupt_main_pending_preservation`: true if the caller already
## determined the existing MAIN is invalid and must be preserved (not
## silently overwritten) before promotion — mirrors SaveManager's
## _corrupt_main_pending_preservation flow exactly.
static func write_safely(
	path: String,
	data: Dictionary,
	version_key: String,
	version: int,
	corrupt_main_pending_preservation: bool = false,
) -> bool:
	var temp_path: String = path + TEMP_SUFFIX
	var backup_path: String = path + BACKUP_SUFFIX
	var payload: Dictionary = data.duplicate(true)
	payload[version_key] = version
	var json_text: String = JSON.stringify(payload, "\t")

	if not _write_text_file(temp_path, json_text):
		push_warning("AtomicJsonStore: failed while writing TEMP for %s." % path)
		return false
	var temp_candidate: Dictionary = read_candidate(temp_path, version_key, true)
	if not bool(temp_candidate["valid"]) or int(temp_candidate["version"]) != version:
		push_warning("AtomicJsonStore: TEMP validation failed for %s. MAIN and BACKUP were not changed." % path)
		return false

	if corrupt_main_pending_preservation and FileAccess.file_exists(path):
		if not preserve_corrupt_main(path):
			push_warning("AtomicJsonStore: aborted because the corrupt MAIN could not be preserved for %s." % path)
			return false

	if FileAccess.file_exists(path):
		var main_candidate: Dictionary = read_candidate(path, version_key, false)
		if not bool(main_candidate["valid"]):
			if not preserve_corrupt_main(path):
				push_warning("AtomicJsonStore: aborted because MAIN became invalid and could not be preserved for %s." % path)
				return false
		elif not _replace_backup_with_main(path, backup_path):
			push_warning("AtomicJsonStore: aborted because the previous MAIN could not be preserved as BACKUP for %s." % path)
			return false

	if not _rename_file(temp_path, path):
		push_warning("AtomicJsonStore: failed while promoting TEMP for %s. Previous state remains in BACKUP, TEMP retained." % path)
		return false
	if not FileAccess.file_exists(path):
		push_warning("AtomicJsonStore: promotion returned without creating MAIN for %s." % path)
		return false
	return true


## Reads and JSON-parses `path`. `require_version_key`: if true, a
## document missing `version_key` entirely is rejected as invalid (used
## for TEMP validation, where a real write always stamps the version).
static func read_candidate(path: String, version_key: String, require_version_key: bool) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return invalid_candidate()
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return invalid_candidate()
	var data: Dictionary = json.data
	if require_version_key and not data.has(version_key):
		return invalid_candidate()
	var raw_version: Variant = data.get(version_key, 1)
	if typeof(raw_version) != TYPE_INT and typeof(raw_version) != TYPE_FLOAT:
		return invalid_candidate()
	if typeof(raw_version) == TYPE_FLOAT and (is_nan(raw_version) or is_inf(raw_version)):
		return invalid_candidate()
	var version: int = int(raw_version)
	if version < 1:
		return invalid_candidate()
	return {"valid": true, "data": data, "version": version}


static func invalid_candidate() -> Dictionary:
	return {"valid": false, "data": {}, "version": 0}


## MAIN/TEMP/BACKUP recovery, used at load time. Mirrors SaveManager's
## original load_profile() candidate-selection order exactly: valid MAIN
## wins outright; else a valid+in-range TEMP is promoted; else a future
## (newer-version) TEMP is surfaced read-only; else BACKUP is restored
## via TEMP; else nothing is recoverable.
static func load_best_candidate(path: String, version_key: String, current_version: int) -> Dictionary:
	var temp_path: String = path + TEMP_SUFFIX
	var backup_path: String = path + BACKUP_SUFFIX
	var main_exists: bool = FileAccess.file_exists(path)
	var main_candidate: Dictionary = read_candidate(path, version_key, false) if main_exists else invalid_candidate()

	if bool(main_candidate["valid"]):
		if int(main_candidate["version"]) <= current_version:
			_cleanup_residual_temp(temp_path)
		return {"found": true, "source": "main", "data": main_candidate["data"], "version": main_candidate["version"], "main_was_corrupt": false}

	var main_was_corrupt: bool = main_exists

	var temp_candidate: Dictionary = read_candidate(temp_path, version_key, true) if FileAccess.file_exists(temp_path) else invalid_candidate()
	if bool(temp_candidate["valid"]) and int(temp_candidate["version"]) <= current_version:
		if _promote_recovery_temp(path, temp_path, main_was_corrupt):
			return {"found": true, "source": "temporary", "data": temp_candidate["data"], "version": temp_candidate["version"], "main_was_corrupt": false}
		return {"found": false, "source": "temporary_unpromotable", "data": {}, "version": 0, "main_was_corrupt": main_was_corrupt}
	if bool(temp_candidate["valid"]) and int(temp_candidate["version"]) > current_version:
		return {"found": true, "source": "future_temporary", "data": temp_candidate["data"], "version": temp_candidate["version"], "main_was_corrupt": main_was_corrupt}

	var backup_candidate: Dictionary = read_candidate(backup_path, version_key, false) if FileAccess.file_exists(backup_path) else invalid_candidate()
	if bool(backup_candidate["valid"]):
		if int(backup_candidate["version"]) > current_version:
			return {"found": true, "source": "future_backup", "data": backup_candidate["data"], "version": backup_candidate["version"], "main_was_corrupt": main_was_corrupt}
		var restored: bool = _restore_backup(path, backup_path, temp_path, main_was_corrupt)
		# Data is loaded into memory from backup either way — only the
		# on-disk promotion (backup -> MAIN) depends on `restored`. When it
		# fails, MAIN's corrupt state (if any) is still unresolved on disk,
		# so the caller must still preserve it on the next write, exactly
		# as the pre-refactor SaveManager did.
		return {"found": true, "source": "backup" if restored else "backup_unrestored", "data": backup_candidate["data"], "version": backup_candidate["version"], "main_was_corrupt": false if restored else main_was_corrupt}

	return {"found": false, "source": "none", "data": {}, "version": 0, "main_was_corrupt": main_was_corrupt}


## Renames an existing MAIN aside to `<path minus extension>.corrupt.<unix
## timestamp>.json` (with a numeric suffix on collision) rather than
## deleting it — same diagnostic-preservation philosophy as the rest of
## this project's save system.
static func preserve_corrupt_main(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	var base: String = path.trim_suffix(".json") if path.ends_with(".json") else path
	var corrupt_path: String = "%s.corrupt.%d.json" % [base, int(Time.get_unix_time_from_system())]
	var suffix: int = 1
	while FileAccess.file_exists(corrupt_path):
		corrupt_path = "%s.corrupt.%d.%d.json" % [base, int(Time.get_unix_time_from_system()), suffix]
		suffix += 1
	if not _rename_file(path, corrupt_path):
		return false
	print("AtomicJsonStore: corrupt file preserved at %s." % corrupt_path)
	return true


static func _promote_recovery_temp(path: String, temp_path: String, main_was_corrupt: bool) -> bool:
	if main_was_corrupt and FileAccess.file_exists(path) and not preserve_corrupt_main(path):
		return false
	var promoted: bool = _rename_file(temp_path, path)
	if promoted:
		print("AtomicJsonStore: recovered %s from a complete temporary save." % path)
	return promoted


static func _restore_backup(path: String, backup_path: String, temp_path: String, main_was_corrupt: bool) -> bool:
	if FileAccess.file_exists(temp_path) and not _remove_file(temp_path):
		return false
	if not _copy_file(backup_path, temp_path):
		return false
	var version_key_probe: Dictionary = read_candidate(temp_path, "", false)
	if not bool(version_key_probe["valid"]):
		return false
	if main_was_corrupt and FileAccess.file_exists(path):
		if not preserve_corrupt_main(path):
			return false
	var restored: bool = _rename_file(temp_path, path)
	if restored:
		print("AtomicJsonStore: recovered %s from backup." % path)
	return restored


static func _replace_backup_with_main(path: String, backup_path: String) -> bool:
	if FileAccess.file_exists(backup_path):
		if not _remove_file(backup_path):
			return false
	return _rename_file(path, backup_path)


static func _cleanup_residual_temp(temp_path: String) -> void:
	if FileAccess.file_exists(temp_path) and not _remove_file(temp_path):
		push_warning("AtomicJsonStore: a residual TEMP could not be removed at %s." % temp_path)


static func _write_text_file(path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	file.close()
	return FileAccess.file_exists(path)


static func _rename_file(from_path: String, to_path: String) -> bool:
	var error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(from_path), ProjectSettings.globalize_path(to_path))
	return error == OK


static func _copy_file(from_path: String, to_path: String) -> bool:
	var error: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(from_path), ProjectSettings.globalize_path(to_path))
	return error == OK


static func _remove_file(path: String) -> bool:
	var error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return error == OK

extends Node

## Domain/repository layer for local character (profile) slots. Owns
## enumeration, slot-count limits, id generation, index repair, legacy
## migration and safe deletion. Deliberately does NOT own ProfileData
## serialization — every read/write of an actual character's profile.json
## goes through SaveManager (repointed at that character's path), so there
## is exactly one atomic-save pipeline in the project, not two.
##
## Inert by design: _ready() performs no filesystem I/O. Nothing here runs
## unless a caller explicitly invokes it (startup()/list_characters()/etc).
## This keeps every existing headless test (which never instantiates
## game.tscn) completely unaffected, and mirrors
## SaveManager.use_isolated_test_profile()'s "opt-in redirection" pattern
## via use_isolated_test_root().

signal characters_changed

const MAX_CHARACTER_SLOTS: int = 3
const MAX_DISPLAY_NAME_LENGTH: int = 20
const DEFAULT_PROFILES_ROOT: String = "user://profiles"
const INDEX_VERSION: int = 1
const LEGACY_MIGRATED_DISPLAY_NAME: String = "Ashen Wanderer"

var profiles_root: String = DEFAULT_PROFILES_ROOT
var selected_character_id: String = ""

## Which file counts as "the legacy profile to migrate". Empty means
## "use the real SaveManager.SAVE_PATH constant" (production default).
## use_isolated_test_root() points this at a path that is guaranteed not
## to exist, so no isolated test can ever accidentally treat a real
## developer's real user://profile.json as a migration source; a test
## that specifically wants to exercise migration overrides this to an
## isolated legacy-profile path it created itself, after calling
## use_isolated_test_root().
var legacy_path_override: String = ""

var _characters_cache: Array = []
var _cache_loaded: bool = false


## Test isolation, symmetric with SaveManager.use_isolated_test_profile():
## redirects every subsequent repository operation to an isolated user://
## subtree so automated tests never touch the real player's
## user://profiles/. Synthetic profiles created this way are never
## registered anywhere outside this isolated root.
func use_isolated_test_root(test_name: String = "runtime_test") -> void:
	if not OS.is_debug_build():
		push_warning("use_isolated_test_root() ignorado fuera de un build de debug.")
		return
	profiles_root = "user://test_profiles_root/%s/profiles" % test_name
	# Wipe any leftover state from a previous invocation of the same test —
	# isolated test roots use fixed, repeatable names, so without this a
	# reused name would accumulate characters/index state across separate
	# test runs instead of starting fresh each time.
	_delete_directory_recursive(ProjectSettings.globalize_path(profiles_root))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profiles_root))
	selected_character_id = ""
	legacy_path_override = "user://test_profiles_root/%s/__no_legacy_source__.json" % test_name
	_cache_loaded = false
	_characters_cache = []


## Real game entry point only (game.gd). Performs legacy migration if this
## is the first boot under the new layout, otherwise loads/repairs the
## index from disk. Safe to call more than once; idempotent.
func startup() -> Array:
	_ensure_dir()
	if FileAccess.file_exists(_index_path()) or FileAccess.file_exists(_index_backup_path()):
		return refresh()
	var scanned: Array = _scan_valid_characters()
	if scanned.is_empty() and _has_meaningful_legacy_profile():
		_migrate_legacy()
		return list_characters()
	return refresh()


func list_characters() -> Array:
	if not _cache_loaded:
		refresh()
	return _characters_cache.duplicate(true)


## Character profile files are authoritative — always rebuilt from a disk
## scan, never trusted blindly from index.json. index.json is written back
## afterward purely as a cache/listing convenience; if it disagreed with
## disk (stale, corrupt, missing, duplicate, orphaned entries...), this
## call silently repairs it.
func refresh() -> Array:
	_ensure_dir()
	var scanned: Array = _scan_valid_characters()
	_characters_cache = scanned
	_cache_loaded = true
	_persist_index(scanned)
	return _characters_cache.duplicate(true)


func can_create_character() -> bool:
	return list_characters().size() < MAX_CHARACTER_SLOTS


func character_exists(character_id: String) -> bool:
	if character_id.is_empty():
		return false
	for entry: Dictionary in list_characters():
		if String(entry.get("character_id", "")) == character_id:
			return true
	return false


func get_character_entry(character_id: String) -> Dictionary:
	for entry: Dictionary in list_characters():
		if String(entry.get("character_id", "")) == character_id:
			return entry
	return {}


## Name-only creation (approved design: no class/race/appearance/stat
## allocation at creation). Transaction order matters: the character
## profile is saved first, and the index is only ever updated after that
## save succeeds — never "index says it exists but no valid profile was
## written."
func create_character(display_name: String) -> Dictionary:
	var trimmed: String = display_name.strip_edges()
	if trimmed.is_empty():
		return {"success": false, "error": "empty_name"}
	if trimmed.length() > MAX_DISPLAY_NAME_LENGTH:
		trimmed = trimmed.substr(0, MAX_DISPLAY_NAME_LENGTH)
	if not can_create_character():
		return {"success": false, "error": "slots_full"}

	var character_id: String = _generate_unique_id()
	var new_profile: ProfileData = ProfileData.new()
	var now: int = int(Time.get_unix_time_from_system())
	new_profile.character_id = character_id
	new_profile.display_name = trimmed
	new_profile.created_at = now
	new_profile.last_played_at = now

	var previous_path: String = SaveManager.save_path
	var previous_profile: ProfileData = SaveManager.profile
	var previous_future_flag: bool = SaveManager.is_future_save_loaded
	SaveManager.save_path = _profile_path(character_id)
	SaveManager.profile = new_profile
	SaveManager.is_future_save_loaded = false
	var saved: bool = SaveManager.save_profile()
	if not saved:
		SaveManager.save_path = previous_path
		SaveManager.profile = previous_profile
		SaveManager.is_future_save_loaded = previous_future_flag
		return {"success": false, "error": "save_failed"}

	selected_character_id = character_id
	refresh()
	characters_changed.emit()
	return {"success": true, "character_id": character_id}


## Repoints SaveManager at the requested character (re-running its full
## MAIN/TEMP/BACKUP recovery via load_profile()), then stamps
## last_played_at and refreshes the index cache entry for it. Refuses
## unknown ids outright — this is the guard against stale UI state
## selecting/deleting the wrong slot.
func select_character(character_id: String) -> bool:
	if not character_exists(character_id):
		return false
	SaveManager.save_path = _profile_path(character_id)
	if not SaveManager.load_profile():
		return false
	if SaveManager.profile.character_id.is_empty():
		SaveManager.profile.character_id = character_id
	if SaveManager.profile.display_name.is_empty():
		SaveManager.profile.display_name = LEGACY_MIGRATED_DISPLAY_NAME
	SaveManager.profile.last_played_at = int(Time.get_unix_time_from_system())
	SaveManager.save_profile()
	selected_character_id = character_id
	refresh()
	return true


## Deletes exactly the requested character. Re-validates existence against
## the authoritative list first (never trusts stale UI state alone).
## Global settings (SettingsManager, its own file) are untouched. Other
## character directories are untouched. character_id is never reused
## (ids are timestamp+random, not sequential slot numbers).
func delete_character(character_id: String) -> bool:
	if not character_exists(character_id):
		return false
	if SaveManager.save_path == _profile_path(character_id):
		SaveManager.clear_active_character()
	if selected_character_id == character_id:
		selected_character_id = ""
	_delete_directory_recursive(ProjectSettings.globalize_path(_character_dir(character_id)))
	refresh()
	characters_changed.emit()
	return true


func _generate_unique_id() -> String:
	var candidate: String = ""
	var attempts: int = 0
	while candidate.is_empty() or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_character_dir(candidate))):
		var timestamp: int = int(Time.get_unix_time_from_system())
		var random_part: String = "%06x" % randi_range(0, 0xFFFFFF)
		candidate = "char_%d_%s" % [timestamp, random_part]
		attempts += 1
		if attempts > 20:
			break
	return candidate


func _character_dir(character_id: String) -> String:
	return "%s/%s" % [profiles_root, character_id]


func _profile_path(character_id: String) -> String:
	return "%s/profile.json" % _character_dir(character_id)


func _legacy_path() -> String:
	return legacy_path_override if not legacy_path_override.is_empty() else SaveManager.SAVE_PATH


## Reads the legacy file directly (read-only, via ProfileData.from_dictionary
## — reusing the same deserialization the rest of the project uses, not a
## second pipeline) rather than trusting whatever SaveManager currently has
## loaded in memory, since SaveManager could be pointed anywhere by the
## time this runs. Distinguishes a genuine pre-existing save from a fresh
## default ProfileData (SaveManager itself auto-creates
## user://profile.json with defaults the first time it ever boots with no
## save present at all — that must never be mistaken for "a legacy
## character to migrate").
func _has_meaningful_legacy_profile() -> bool:
	var path: String = _legacy_path()
	var data: Dictionary = _read_json_dict(path)
	if data.is_empty():
		return false
	var legacy: ProfileData = ProfileData.from_dictionary(data)
	return (
		legacy.total_runs > 0
		or legacy.player_level > PlayerProgressionConfig.START_LEVEL
		or legacy.total_ash > 0
		or not legacy.owned_equipment.is_empty()
		or not legacy.completed_milestone_ids.is_empty()
		or not legacy.completed_tutorials.is_empty()
		or legacy.total_combats_won > 0
	)


## Legacy user://profile.json -> Slot 1. Repoints SaveManager at the legacy
## path and runs its full load_profile() recovery pipeline (MAIN/TEMP/
## BACKUP, version migration, sanitization) to obtain the profile, so a
## corrupt-MAIN-valid-BACKUP legacy save recovers exactly as it would for
## a normal boot. The legacy file itself is never deleted here or anywhere
## in this milestone.
func _migrate_legacy() -> Dictionary:
	var legacy_path: String = _legacy_path()
	var previous_path: String = SaveManager.save_path
	var previous_profile: ProfileData = SaveManager.profile
	var previous_future_flag: bool = SaveManager.is_future_save_loaded

	SaveManager.save_path = legacy_path
	if not SaveManager.load_profile():
		SaveManager.save_path = previous_path
		SaveManager.profile = previous_profile
		SaveManager.is_future_save_loaded = previous_future_flag
		return {"success": false}

	var legacy_profile: ProfileData = SaveManager.profile
	var character_id: String = _generate_unique_id()
	var now: int = int(Time.get_unix_time_from_system())
	legacy_profile.character_id = character_id
	if legacy_profile.display_name.is_empty():
		legacy_profile.display_name = LEGACY_MIGRATED_DISPLAY_NAME
	if legacy_profile.created_at <= 0:
		legacy_profile.created_at = now
	legacy_profile.last_played_at = now

	SaveManager.save_path = _profile_path(character_id)
	SaveManager.profile = legacy_profile
	SaveManager.is_future_save_loaded = false
	var saved: bool = SaveManager.save_profile()
	if not saved:
		# Roll back so the app keeps functioning off the legacy file; a
		# future startup() retries migration. The legacy file is untouched
		# either way, so no progress is ever at risk.
		SaveManager.save_path = legacy_path
		SaveManager.load_profile()
		return {"success": false}

	selected_character_id = character_id
	refresh()
	characters_changed.emit()
	return {"success": true, "character_id": character_id}


## Ground truth: walks every subdirectory of profiles_root and tries to
## read a valid profile.json (falling back to profile.json.bak, read-only —
## no promotion/repair write happens here; a real select_character() call
## runs SaveManager's full recovery pipeline). A directory with neither a
## valid MAIN nor BACKUP is reported as a corrupt entry (not silently
## dropped) so the UI can render a CORRUPT SLOT instead of a slot that
## mysteriously vanished, and so a corrupted sibling never hides another
## valid character.
func _scan_valid_characters() -> Array:
	var result: Array = []
	var abs_root: String = ProjectSettings.globalize_path(profiles_root)
	var dir: DirAccess = DirAccess.open(abs_root)
	if dir == null:
		return result
	var found_ids: Dictionary = {}
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		if entry_name != "." and entry_name != ".." and dir.current_is_dir():
			var read_profile: ProfileData = _read_character_profile(entry_name)
			if read_profile != null:
				var effective_id: String = read_profile.character_id if not read_profile.character_id.is_empty() else entry_name
				if not found_ids.has(effective_id):
					found_ids[effective_id] = true
					result.append(_entry_from_profile(effective_id, read_profile))
			elif not found_ids.has(entry_name):
				found_ids[entry_name] = true
				result.append({
					"character_id": entry_name, "display_name": "", "player_level": 0,
					"selected_biome_id": "", "last_played_at": 0, "created_at": 0, "corrupt": true,
				})
		entry_name = dir.get_next()
	dir.list_dir_end()
	# created_at has 1-second resolution, so characters created in the same
	# second would otherwise tie and reorder unpredictably on every rescan
	# (directory listing order is not guaranteed stable). character_id
	# breaks the tie deterministically, so the list order stays fixed
	# across repeated listings even when creation timestamps collide.
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var created_a: int = int(a.get("created_at", 0))
		var created_b: int = int(b.get("created_at", 0))
		if created_a != created_b:
			return created_a < created_b
		return String(a.get("character_id", "")) < String(b.get("character_id", "")))
	if result.size() > MAX_CHARACTER_SLOTS:
		push_warning("More than MAX_CHARACTER_SLOTS (%d) valid directories found under %s; keeping the oldest %d for selection, excess left on disk untouched." % [MAX_CHARACTER_SLOTS, profiles_root, MAX_CHARACTER_SLOTS])
		result = result.slice(0, MAX_CHARACTER_SLOTS)
	return result


func _entry_from_profile(character_id: String, profile: ProfileData) -> Dictionary:
	return {
		"character_id": character_id,
		"display_name": profile.display_name,
		"player_level": profile.player_level,
		"selected_biome_id": String(profile.selected_biome_id),
		"last_played_at": profile.last_played_at,
		"created_at": profile.created_at,
		"corrupt": false,
	}


func _read_character_profile(dir_name: String) -> ProfileData:
	var base: String = "%s/%s" % [profiles_root, dir_name]
	var main_data: Dictionary = _read_json_dict("%s/profile.json" % base)
	if not main_data.is_empty():
		return ProfileData.from_dictionary(main_data)
	var backup_data: Dictionary = _read_json_dict("%s/profile.json.bak" % base)
	if not backup_data.is_empty():
		return ProfileData.from_dictionary(backup_data)
	return null


func _read_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profiles_root))


func _index_path() -> String:
	return "%s/index.json" % profiles_root


func _index_backup_path() -> String:
	return "%s.bak" % _index_path()


func _index_temp_path() -> String:
	return "%s.tmp" % _index_path()


func _persist_index(entries: Array) -> void:
	_write_index_atomic({"index_version": INDEX_VERSION, "characters": entries})


## Same rename-based atomicity spirit as SaveManager's MAIN/TEMP/BACKUP
## writer (write TEMP, validate it parses back, rotate old MAIN to BACKUP,
## promote TEMP to MAIN) — kept as its own small writer rather than
## sharing SaveManager's private pipeline, since index.json is cache/
## listing metadata, not a ProfileData serialization (see file header).
func _write_index_atomic(data: Dictionary) -> bool:
	_ensure_dir()
	var json_text: String = JSON.stringify(data, "\t")
	var temp_path: String = _index_temp_path()
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(json_text)
	file.flush()
	file.close()
	if _read_json_dict(temp_path).is_empty():
		return false
	var index_path: String = _index_path()
	var backup_path: String = _index_backup_path()
	if FileAccess.file_exists(index_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
		DirAccess.rename_absolute(ProjectSettings.globalize_path(index_path), ProjectSettings.globalize_path(backup_path))
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(index_path)) == OK


func _delete_directory_recursive(absolute_path: String) -> void:
	var dir: DirAccess = DirAccess.open(absolute_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		if entry_name != "." and entry_name != "..":
			var full_path: String = absolute_path.path_join(entry_name)
			if dir.current_is_dir():
				_delete_directory_recursive(full_path)
			else:
				DirAccess.remove_absolute(full_path)
		entry_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)

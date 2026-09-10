extends Node

## Profile System (character slots) domain coverage: slot limits, id
## uniqueness, index repair (stale/corrupt/orphan), safe deletion,
## cross-character save isolation, legacy migration (including an
## interrupted-migration recovery case), and test-profile isolation
## staying decoupled from the repository. Never touches the real
## user://profile.json or user://profiles/ — every sub-test redirects both
## SaveManager (use_isolated_test_profile) and CharacterProfileRepository
## (use_isolated_test_root) to their own isolated user:// subtree.

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	_test_fresh_install()
	_test_create_and_limits()
	_test_unique_ids_and_name_collision()
	_test_reopen_preserves_index()
	_test_persistence_across_switch()
	_test_switch_no_cross_write()
	_test_delete_leaves_others_intact()
	_test_settings_survive_deletion()
	_test_corrupt_profile_isolated()
	_test_stale_index_repaired()
	_test_corrupt_index_repaired()
	_test_orphan_discovered()
	_test_legacy_migration()
	_test_interrupted_migration_recovery()
	_test_isolated_test_profile_unaffected()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _test_fresh_install() -> void:
	CharacterProfileRepository.use_isolated_test_root("fresh_install")
	var characters: Array = CharacterProfileRepository.startup()
	_check("fresh_install_zero_characters", characters.is_empty())
	_check("fresh_install_list_matches", CharacterProfileRepository.list_characters().is_empty())


func _test_create_and_limits() -> void:
	CharacterProfileRepository.use_isolated_test_root("create_limits")
	CharacterProfileRepository.startup()
	var first: Dictionary = CharacterProfileRepository.create_character("Brand")
	_check("create_first_succeeds", bool(first.get("success", false)))
	_check("create_first_list_size_1", CharacterProfileRepository.list_characters().size() == 1)
	CharacterProfileRepository.create_character("Second")
	CharacterProfileRepository.create_character("Third")
	_check("create_three_list_size_3", CharacterProfileRepository.list_characters().size() == 3)
	_check("cannot_create_fourth", not CharacterProfileRepository.can_create_character())
	var fourth: Dictionary = CharacterProfileRepository.create_character("Fourth")
	_check("fourth_rejected", not bool(fourth.get("success", false)) and String(fourth.get("error", "")) == "slots_full")
	_check("fourth_did_not_change_count", CharacterProfileRepository.list_characters().size() == 3)
	var empty_name: Dictionary = CharacterProfileRepository.create_character("   ")
	_check("empty_name_rejected", not bool(empty_name.get("success", false)) and String(empty_name.get("error", "")) == "empty_name")


func _test_unique_ids_and_name_collision() -> void:
	CharacterProfileRepository.use_isolated_test_root("unique_ids")
	CharacterProfileRepository.startup()
	var a: Dictionary = CharacterProfileRepository.create_character("Twin")
	var b: Dictionary = CharacterProfileRepository.create_character("Twin")
	var id_a: String = String(a.get("character_id", ""))
	var id_b: String = String(b.get("character_id", ""))
	_check("same_name_both_created", bool(a.get("success", false)) and bool(b.get("success", false)))
	_check("same_name_distinct_ids", not id_a.is_empty() and id_a != id_b)
	var entries: Array = CharacterProfileRepository.list_characters()
	_check("names_not_used_as_identity", entries.size() == 2)


func _test_reopen_preserves_index() -> void:
	CharacterProfileRepository.use_isolated_test_root("reopen")
	CharacterProfileRepository.startup()
	CharacterProfileRepository.create_character("Persisted")
	var before: Array = CharacterProfileRepository.list_characters()
	# Simulate reopening the app/repository: drop the in-memory cache and
	# reload purely from what's on disk (index.json + directory scan).
	CharacterProfileRepository._cache_loaded = false
	CharacterProfileRepository._characters_cache = []
	var after: Array = CharacterProfileRepository.list_characters()
	_check("reopen_same_count", before.size() == after.size() and after.size() == 1)
	_check("reopen_same_character_id", String(before[0].get("character_id", "")) == String(after[0].get("character_id", "")))


func _test_persistence_across_switch() -> void:
	CharacterProfileRepository.use_isolated_test_root("persistence")
	CharacterProfileRepository.startup()
	var a: Dictionary = CharacterProfileRepository.create_character("Alpha")
	var id_a: String = String(a.get("character_id", ""))
	SaveManager.profile.player_level = 6
	SaveManager.profile.player_xp = 42
	SaveManager.profile.owned_equipment = {"ashen_blade": 1}
	SaveManager.profile.total_ash = 250
	SaveManager.profile.guardian_sigils = 3
	SaveManager.profile.forge_shards = 9
	SaveManager.profile.owned_meta_unlock_ids = [StringName("ember_focus")]
	SaveManager.profile.completed_tutorials = ["run_results"]
	SaveManager.save_profile()

	var b: Dictionary = CharacterProfileRepository.create_character("Beta")
	var id_b: String = String(b.get("character_id", ""))
	CharacterProfileRepository.select_character(id_a)
	_check("level_persists", SaveManager.profile.player_level == 6)
	_check("xp_persists", SaveManager.profile.player_xp == 42)
	_check("inventory_persists", int(SaveManager.profile.owned_equipment.get("ashen_blade", 0)) == 1)
	_check("currencies_persist", SaveManager.profile.total_ash == 250 and SaveManager.profile.guardian_sigils == 3 and SaveManager.profile.forge_shards == 9)
	_check("unlocks_persist", StringName("ember_focus") in SaveManager.profile.owned_meta_unlock_ids)
	_check("tutorials_persist", "run_results" in SaveManager.profile.completed_tutorials)
	_check("switch_target_b_exists", not id_b.is_empty())


func _test_switch_no_cross_write() -> void:
	CharacterProfileRepository.use_isolated_test_root("cross_write")
	CharacterProfileRepository.startup()
	var a: Dictionary = CharacterProfileRepository.create_character("Warden")
	var id_a: String = String(a.get("character_id", ""))
	SaveManager.profile.total_ash = 111
	SaveManager.save_profile()

	var b: Dictionary = CharacterProfileRepository.create_character("Scout")
	var id_b: String = String(b.get("character_id", ""))
	SaveManager.profile.total_ash = 222
	SaveManager.save_profile()

	CharacterProfileRepository.select_character(id_a)
	_check("switch_a_before_mutate", SaveManager.profile.total_ash == 111)
	SaveManager.profile.total_ash = 333
	SaveManager.save_profile()

	CharacterProfileRepository.select_character(id_b)
	_check("switch_b_untouched_by_a_mutation", SaveManager.profile.total_ash == 222)

	CharacterProfileRepository.select_character(id_a)
	_check("switch_a_kept_its_own_mutation", SaveManager.profile.total_ash == 333)


func _test_delete_leaves_others_intact() -> void:
	CharacterProfileRepository.use_isolated_test_root("delete_isolation")
	CharacterProfileRepository.startup()
	var a: Dictionary = CharacterProfileRepository.create_character("A")
	var id_a: String = String(a.get("character_id", ""))
	SaveManager.profile.total_ash = 10
	SaveManager.save_profile()
	var b: Dictionary = CharacterProfileRepository.create_character("B")
	var id_b: String = String(b.get("character_id", ""))
	SaveManager.profile.total_ash = 20
	SaveManager.save_profile()
	var c: Dictionary = CharacterProfileRepository.create_character("C")
	var id_c: String = String(c.get("character_id", ""))
	SaveManager.profile.total_ash = 30
	SaveManager.save_profile()

	var deleted: bool = CharacterProfileRepository.delete_character(id_b)
	_check("delete_b_succeeds", deleted)
	_check("delete_b_removed_from_list", not CharacterProfileRepository.character_exists(id_b))
	_check("delete_b_list_size_2", CharacterProfileRepository.list_characters().size() == 2)

	CharacterProfileRepository.select_character(id_a)
	_check("delete_leaves_a_intact", SaveManager.profile.total_ash == 10)
	CharacterProfileRepository.select_character(id_c)
	_check("delete_leaves_c_intact", SaveManager.profile.total_ash == 30)

	var stale_delete: bool = CharacterProfileRepository.delete_character(id_b)
	_check("deleting_already_deleted_id_fails_safely", not stale_delete)
	var bogus_delete: bool = CharacterProfileRepository.delete_character("char_does_not_exist")
	_check("deleting_unknown_id_rejected", not bogus_delete)


func _test_settings_survive_deletion() -> void:
	CharacterProfileRepository.use_isolated_test_root("settings_survive")
	CharacterProfileRepository.startup()
	var a: Dictionary = CharacterProfileRepository.create_character("SettingsCheck")
	var id_a: String = String(a.get("character_id", ""))
	var volume_before: float = SettingsManager.master_volume
	var reduce_motion_before: bool = SettingsManager.reduce_motion
	CharacterProfileRepository.delete_character(id_a)
	_check("settings_volume_unchanged_after_delete", is_equal_approx(SettingsManager.master_volume, volume_before))
	_check("settings_reduce_motion_unchanged_after_delete", SettingsManager.reduce_motion == reduce_motion_before)


func _test_corrupt_profile_isolated() -> void:
	CharacterProfileRepository.use_isolated_test_root("corrupt_profile")
	CharacterProfileRepository.startup()
	var a: Dictionary = CharacterProfileRepository.create_character("Sound")
	var id_a: String = String(a.get("character_id", ""))
	var b: Dictionary = CharacterProfileRepository.create_character("AlsoSound")
	var id_b: String = String(b.get("character_id", ""))
	SaveManager.profile.total_ash = 77
	SaveManager.save_profile()

	var corrupt_path: String = ProjectSettings.globalize_path(CharacterProfileRepository._profile_path(id_a))
	var file: FileAccess = FileAccess.open(corrupt_path, FileAccess.WRITE)
	file.store_string("{not valid json")
	file.close()

	var entries: Array = CharacterProfileRepository.refresh()
	_check("corrupt_sibling_still_listed_total", entries.size() == 2)
	var found_corrupt: bool = false
	var found_b_intact: bool = false
	for entry: Dictionary in entries:
		if String(entry.get("character_id", "")) == id_a:
			found_corrupt = bool(entry.get("corrupt", false))
		if String(entry.get("character_id", "")) == id_b:
			found_b_intact = not bool(entry.get("corrupt", false)) and int(entry.get("player_level", 0)) > 0
	_check("corrupt_entry_flagged_not_hidden", found_corrupt)
	CharacterProfileRepository.select_character(id_b)
	_check("sibling_of_corrupt_unaffected", SaveManager.profile.total_ash == 77)
	_check("corrupt_detection_did_not_drop_sibling", found_b_intact)


func _test_stale_index_repaired() -> void:
	CharacterProfileRepository.use_isolated_test_root("stale_index")
	CharacterProfileRepository.startup()
	CharacterProfileRepository.create_character("Real1")
	CharacterProfileRepository.create_character("Real2")
	var real_ids: Array = []
	for entry: Dictionary in CharacterProfileRepository.list_characters():
		real_ids.append(String(entry.get("character_id", "")))

	var stale_data: Dictionary = {
		"index_version": 1,
		"characters": [{"character_id": "char_ghost_000000", "display_name": "Ghost", "player_level": 1, "selected_biome_id": "", "last_played_at": 0}],
	}
	CharacterProfileRepository._write_index_atomic(stale_data)

	var repaired: Array = CharacterProfileRepository.refresh()
	var repaired_ids: Array = []
	for entry: Dictionary in repaired:
		repaired_ids.append(String(entry.get("character_id", "")))
	_check("stale_index_drops_ghost_entry", not ("char_ghost_000000" in repaired_ids))
	_check("stale_index_recovers_real_entries", repaired_ids.size() == 2 and real_ids[0] in repaired_ids and real_ids[1] in repaired_ids)


func _test_corrupt_index_repaired() -> void:
	CharacterProfileRepository.use_isolated_test_root("corrupt_index")
	CharacterProfileRepository.startup()
	var a: Dictionary = CharacterProfileRepository.create_character("Solo")
	var id_a: String = String(a.get("character_id", ""))

	var index_abs: String = ProjectSettings.globalize_path(CharacterProfileRepository._index_path())
	var file: FileAccess = FileAccess.open(index_abs, FileAccess.WRITE)
	file.store_string("{{{ this is not json")
	file.close()

	var repaired: Array = CharacterProfileRepository.refresh()
	_check("corrupt_index_still_recovers_real_character", repaired.size() == 1 and String(repaired[0].get("character_id", "")) == id_a)
	var reread: Dictionary = CharacterProfileRepository._read_json_dict(CharacterProfileRepository._index_path())
	_check("corrupt_index_file_rewritten_valid", not reread.is_empty())


func _test_orphan_discovered() -> void:
	CharacterProfileRepository.use_isolated_test_root("orphan_discovery")
	CharacterProfileRepository.startup()
	# Bypass create_character() entirely: write a valid character profile
	# directly via SaveManager, the same way a completed-but-not-yet-
	# indexed migration or creation would leave things after a crash.
	var orphan_id: String = "char_orphan_000001"
	var orphan_profile: ProfileData = ProfileData.new()
	orphan_profile.character_id = orphan_id
	orphan_profile.display_name = "Orphan"
	orphan_profile.player_level = 2
	SaveManager.save_path = CharacterProfileRepository._profile_path(orphan_id)
	SaveManager.profile = orphan_profile
	SaveManager.is_future_save_loaded = false
	SaveManager.save_profile()

	var discovered: Array = CharacterProfileRepository.refresh()
	var found: bool = false
	for entry: Dictionary in discovered:
		if String(entry.get("character_id", "")) == orphan_id:
			found = true
	_check("orphan_character_discovered_by_repair", found)


func _test_legacy_migration() -> void:
	SaveManager.use_isolated_test_profile("legacy_migration_source")
	SaveManager.profile.total_runs = 5
	SaveManager.profile.player_level = 3
	SaveManager.profile.owned_equipment = {"ashen_blade": 1}
	SaveManager.profile.total_ash = 88
	SaveManager.save_profile()
	var legacy_path: String = SaveManager.save_path

	CharacterProfileRepository.use_isolated_test_root("legacy_migration_dest")
	CharacterProfileRepository.legacy_path_override = legacy_path
	var characters: Array = CharacterProfileRepository.startup()
	_check("legacy_migration_creates_one_character", characters.size() == 1)
	if not characters.is_empty():
		_check("legacy_migration_default_display_name", String(characters[0].get("display_name", "")) == CharacterProfileRepository.LEGACY_MIGRATED_DISPLAY_NAME)
		_check("legacy_migration_preserves_level", int(characters[0].get("player_level", 0)) == 3)
	_check("legacy_migration_preserves_data_on_saveManager", SaveManager.profile.total_runs == 5 and int(SaveManager.profile.owned_equipment.get("ashen_blade", 0)) == 1)
	_check("legacy_file_not_deleted", FileAccess.file_exists(legacy_path))


func _test_interrupted_migration_recovery() -> void:
	SaveManager.use_isolated_test_profile("interrupted_migration_source")
	SaveManager.profile.total_runs = 7
	SaveManager.profile.player_level = 4
	SaveManager.save_profile()
	var legacy_path: String = SaveManager.save_path

	CharacterProfileRepository.use_isolated_test_root("interrupted_migration_dest")
	CharacterProfileRepository.legacy_path_override = legacy_path
	# Simulate "migration already completed the profile write, then crashed
	# before index.json was ever created": a valid character directory
	# exists, but no index.json.
	var already_migrated_id: String = "char_already_migrated_000001"
	var already_migrated: ProfileData = ProfileData.new()
	already_migrated.character_id = already_migrated_id
	already_migrated.display_name = CharacterProfileRepository.LEGACY_MIGRATED_DISPLAY_NAME
	already_migrated.total_runs = 7
	SaveManager.save_path = CharacterProfileRepository._profile_path(already_migrated_id)
	SaveManager.profile = already_migrated
	SaveManager.is_future_save_loaded = false
	SaveManager.save_profile()

	var characters: Array = CharacterProfileRepository.startup()
	_check("interrupted_migration_no_duplicate", characters.size() == 1)
	if not characters.is_empty():
		_check("interrupted_migration_keeps_existing_character", String(characters[0].get("character_id", "")) == already_migrated_id)


func _test_isolated_test_profile_unaffected() -> void:
	CharacterProfileRepository.use_isolated_test_root("decoupled_from_test_profile")
	CharacterProfileRepository.startup()
	var before_count: int = CharacterProfileRepository.list_characters().size()
	SaveManager.use_isolated_test_profile("legacy_unrelated_synthetic")
	SaveManager.profile.total_ash = 999
	SaveManager.save_profile()
	_check("test_profile_isolation_does_not_register_in_repository", CharacterProfileRepository.list_characters().size() == before_count)

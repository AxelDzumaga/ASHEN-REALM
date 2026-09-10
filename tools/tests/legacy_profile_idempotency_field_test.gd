extends Node

## §32: a SAVE_VERSION 14 profile written before last_deposited_run_id
## existed must still load safely — the field defaults to "", nothing
## else is lost, no migration/version bump required.

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	_test_legacy_v14_profile_without_field_loads_safely()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _test_legacy_v14_profile_without_field_loads_safely() -> void:
	SaveManager.use_isolated_test_profile("legacy_v14_no_run_idempotency_field")
	var legacy_path: String = SaveManager.save_path

	# A hand-built v14 payload exactly as it would have looked before this
	# milestone — no last_deposited_run_id key at all, real progression
	# data present.
	var legacy_payload: Dictionary = {
		"save_version": 14,
		"total_ash": 500,
		"player_level": 6,
		"player_xp": 40,
		"total_runs": 12,
		"owned_equipment": {"ashen_blade": 1, "wardens_plate": 1},
		"completed_milestone_ids": ["first_expedition", "first_victory"],
		"character_id": "char_legacy_test",
		"display_name": "Legacy Wanderer",
	}
	var file: FileAccess = FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy_payload, "\t"))
	file.close()

	var loaded: bool = SaveManager.load_profile()
	_check("legacy_profile_loads", loaded)
	_check("last_deposited_run_id_defaults_empty", SaveManager.profile.last_deposited_run_id == "")
	_check("legacy_ash_preserved", SaveManager.profile.total_ash == 500)
	_check("legacy_level_preserved", SaveManager.profile.player_level == 6)
	_check("legacy_equipment_preserved", int(SaveManager.profile.owned_equipment.get("ashen_blade", 0)) == 1)
	_check("legacy_milestones_preserved", "first_victory" in SaveManager.profile.completed_milestone_ids)
	_check("legacy_character_identity_preserved", SaveManager.profile.character_id == "char_legacy_test")

	# Deposit a run against this migrated-in-memory profile: must work
	# normally (idempotency marker was empty, not something that
	# accidentally blocks the very first deposit for this profile).
	var run := RunState.new()
	run.run_id = "run_after_legacy_load"
	run.run_completed = true
	run.run_ash = 10
	var deposited: bool = SaveManager.deposit_run(run)
	_check("deposit_after_legacy_load_succeeds", deposited)
	_check("idempotency_marker_set_after_first_real_deposit", SaveManager.profile.last_deposited_run_id == "run_after_legacy_load")

extends Node

## P0 correctness: SaveManager.deposit_run() reward-deposit idempotency,
## keyed by RunState.run_id / ProfileData.last_deposited_run_id. Never
## touches the real user://profile.json — every case uses
## SaveManager.use_isolated_test_profile().

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	_test_double_deposit_same_run_does_not_double_reward()
	_test_different_run_deposits_independently()
	_test_failed_transaction_does_not_partially_mutate()
	_test_reload_from_disk_after_deposit_stays_correct()
	_test_reload_after_stale_resume_recovery_stays_correct()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


## A non-trivial fixture touching every reward channel deposit_run() knows
## about: XP/level gain, ash, equipment loot, a duplicate conversion,
## milestone completion, boss chest + guardian sigils, biome material.
func _build_rich_run(run_id: String) -> RunState:
	var run := RunState.new()
	run.run_id = run_id
	run.biome_id = BiomeCatalog.ASHEN_WASTES.id
	run.biome_data = BiomeCatalog.ASHEN_WASTES
	run.run_completed = true
	run.combats_won = 4
	run.run_ash = 120
	run.biome_material_earned = 6
	run.equipped_companion_id = &"ember_hound"
	run.pending_loot_id = "ashen_blade"
	run.loot_rolled = true
	return run


func _test_double_deposit_same_run_does_not_double_reward() -> void:
	SaveManager.use_isolated_test_profile("deposit_idempotency_double")
	var run_a: RunState = _build_rich_run("run_alpha_0001")
	var first_result: bool = SaveManager.deposit_run(run_a)
	_check("first_deposit_succeeds", first_result)
	var snapshot: Dictionary = SaveManager.profile.to_dictionary()

	# Simulate a resumed run: a DIFFERENT RunState instance carrying the
	# SAME run_id, with rewards_deposited still false (as a stale
	# active_run.json — never updated after the first deposit — would
	# produce on resume).
	var run_a_resumed: RunState = _build_rich_run("run_alpha_0001")
	_check("resumed_run_state_starts_undeposited", not run_a_resumed.rewards_deposited)
	var second_result: bool = SaveManager.deposit_run(run_a_resumed)
	_check("second_deposit_reports_success", second_result)
	_check("second_deposit_normalizes_terminal_state", run_a_resumed.rewards_deposited)

	var after: Dictionary = SaveManager.profile.to_dictionary()
	_check("ash_not_doubled", int(after.get("total_ash", -1)) == int(snapshot.get("total_ash", -2)))
	_check("player_xp_not_doubled", int(after.get("player_xp", -1)) == int(snapshot.get("player_xp", -2)) and int(after.get("player_level", -1)) == int(snapshot.get("player_level", -2)))
	_check("total_runs_not_doubled", int(after.get("total_runs", -1)) == int(snapshot.get("total_runs", -2)))
	_check("total_victories_not_doubled", int(after.get("total_victories", -1)) == int(snapshot.get("total_victories", -2)))
	_check("guardian_sigils_not_doubled", int(after.get("guardian_sigils", -1)) == int(snapshot.get("guardian_sigils", -2)))
	_check("owned_equipment_not_duplicated", after.get("owned_equipment", {}) == snapshot.get("owned_equipment", {}))
	_check("biome_materials_not_doubled", after.get("biome_materials", {}) == snapshot.get("biome_materials", {}))
	_check("unopened_chests_not_doubled", after.get("unopened_chests", {}) == snapshot.get("unopened_chests", {}))


func _test_different_run_deposits_independently() -> void:
	SaveManager.use_isolated_test_profile("deposit_idempotency_different_run")
	var run_a: RunState = _build_rich_run("run_beta_a")
	SaveManager.deposit_run(run_a)
	var after_a: Dictionary = SaveManager.profile.to_dictionary()

	# Different loot id than run_a's, deliberately: otherwise run_b's
	# "loot" would already be owned from run_a and get duplicate-salvaged
	# into extra ash instead of granted, confounding the plain ash-
	# accumulation assertion below with correct-but-unrelated behavior.
	var run_b: RunState = _build_rich_run("run_beta_b")
	run_b.pending_loot_id = "wardens_edge"
	var deposited_b: bool = SaveManager.deposit_run(run_b)
	_check("different_run_id_deposits", deposited_b)
	_check("different_run_id_is_new_idempotency_key", SaveManager.profile.last_deposited_run_id == "run_beta_b")
	var after_b: Dictionary = SaveManager.profile.to_dictionary()
	# >= rather than ==: milestone completion (e.g. a "second expedition"
	# style milestone landing exactly on this deposit) can add its own
	# one-time bonus ash on top of run_b.run_ash — that's correct economy
	# behavior, not something this idempotency test should be brittle to.
	# The property actually under test is "accumulates independently, not
	# blocked or overwritten by run_a's deposit".
	_check("different_run_ash_accumulates", int(after_b.get("total_ash", 0)) >= int(after_a.get("total_ash", 0)) + run_b.run_ash)
	_check("different_run_total_runs_accumulates", int(after_b.get("total_runs", 0)) == int(after_a.get("total_runs", 0)) + 1)


func _test_failed_transaction_does_not_partially_mutate() -> void:
	SaveManager.use_isolated_test_profile("deposit_idempotency_failure")
	var before: Dictionary = SaveManager.profile.to_dictionary()
	var run_c: RunState = _build_rich_run("run_gamma")

	# Force the underlying write to fail without touching the real
	# filesystem contract: point save_path at a directory that cannot
	# exist as a file parent (a path component that is itself an existing
	# file, not a directory, so make_dir_recursive_absolute/FileAccess.open
	# cannot succeed).
	var blocked_path: String = SaveManager.save_path
	var real_path: String = SaveManager.save_path
	var blocker_dir: String = real_path.get_base_dir() + "/blocker_file"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocker_dir.get_base_dir()))
	var blocker: FileAccess = FileAccess.open(ProjectSettings.globalize_path(blocker_dir), FileAccess.WRITE)
	if blocker != null:
		blocker.store_string("x")
		blocker.close()
	SaveManager.save_path = blocker_dir + "/profile.json"

	var deposited: bool = SaveManager.deposit_run(run_c)
	_check("forced_failure_deposit_reports_false", not deposited)
	_check("forced_failure_run_state_not_marked_deposited", not run_c.rewards_deposited)
	_check("forced_failure_profile_reverted", SaveManager.profile.to_dictionary() == before)
	_check("forced_failure_idempotency_marker_not_set", SaveManager.profile.last_deposited_run_id != "run_gamma")

	SaveManager.save_path = blocked_path


func _test_reload_from_disk_after_deposit_stays_correct() -> void:
	SaveManager.use_isolated_test_profile("deposit_idempotency_reload")
	var run_d: RunState = _build_rich_run("run_delta")
	SaveManager.deposit_run(run_d)
	var expected_ash: int = SaveManager.profile.total_ash
	var expected_runs: int = SaveManager.profile.total_runs
	var saved_path: String = SaveManager.save_path

	# Simulate the real crash-recovery scenario: destroy the in-memory
	# SaveManager state entirely and reload purely from what's on disk —
	# not just re-reading the same still-resident ProfileData object.
	SaveManager.profile = ProfileData.new()
	SaveManager.save_path = saved_path
	SaveManager.load_profile()

	_check("reload_preserves_ash_exactly_once", SaveManager.profile.total_ash == expected_ash)
	_check("reload_preserves_total_runs_exactly_once", SaveManager.profile.total_runs == expected_runs)
	_check("reload_preserves_idempotency_marker", SaveManager.profile.last_deposited_run_id == "run_delta")


func _test_reload_after_stale_resume_recovery_stays_correct() -> void:
	SaveManager.use_isolated_test_profile("deposit_idempotency_reload_stale")
	var run_e: RunState = _build_rich_run("run_epsilon")
	SaveManager.deposit_run(run_e)
	var expected_ash: int = SaveManager.profile.total_ash
	var saved_path: String = SaveManager.save_path

	# A stale resumed RunState (rewards_deposited never made it to disk in
	# active_run.json) attempts recovery deposit again against the
	# already-updated profile.
	var run_e_resumed: RunState = _build_rich_run("run_epsilon")
	SaveManager.deposit_run(run_e_resumed)

	SaveManager.profile = ProfileData.new()
	SaveManager.save_path = saved_path
	SaveManager.load_profile()

	_check("reload_after_stale_recovery_ash_exactly_once", SaveManager.profile.total_ash == expected_ash)

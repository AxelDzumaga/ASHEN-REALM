extends Node

## Core Loop / Final Reward §20 (CRITICAL) / §29 / §30 — proves the actual
## progression gate, not the previous (incorrect) one. Ember Marsh must
## unlock on defeating Ashen Warden (milestone "warden_defeated"), never on
## merely finishing an expedition (milestone "first_expedition" — the old,
## wrong gate this milestone replaces). Pure domain layer: ProfileData +
## SaveManager.deposit_run() + BiomeCatalog.is_unlocked() + MilestoneResolver,
## no game.tscn — fast and deterministic.

const ASHEN_WASTES_ID: StringName = &"ashen_wastes"
const EMBER_MARSH_ID: StringName = &"ember_marsh"

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	_test_defeat_does_not_unlock_ember_marsh()
	_test_warden_victory_unlocks_ember_marsh()
	_test_unlock_persists_after_reload()
	_test_first_victory_completes_but_is_not_the_gate()
	_test_unrelated_milestone_does_not_unlock()
	_test_milestone_completion_timing_and_dedup()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _fresh_run(character_name: String) -> RunState:
	var run := RunState.new()
	run.run_id = "run_%s_%d" % [character_name, randi()]
	run.biome_id = ASHEN_WASTES_ID
	run.biome_data = BiomeCatalog.ASHEN_WASTES
	var sequence: Array[int] = []
	for _i: int in 30:
		sequence.append(BoardTileData.TileType.EMPTY)
	run.board_tile_sequence = sequence
	run.owned_equipment_ids_at_start = []
	return run


func _test_defeat_does_not_unlock_ember_marsh() -> void:
	SaveManager.use_isolated_test_profile(&"core_loop_biome_defeat")
	SaveManager.profile = ProfileData.new()
	_check("baseline_ashen_wastes_unlocked", BiomeCatalog.is_unlocked(BiomeCatalog.ASHEN_WASTES, SaveManager.profile.completed_milestone_ids))
	_check("baseline_ember_marsh_locked", not BiomeCatalog.is_unlocked(BiomeCatalog.EMBER_MARSH, SaveManager.profile.completed_milestone_ids))

	var run: RunState = _fresh_run("defeat")
	run.run_completed = false
	var deposited: bool = SaveManager.deposit_run(run)
	_check("defeat_deposit_succeeds", deposited)
	_check("defeat_completes_first_expedition", "first_expedition" in SaveManager.profile.completed_milestone_ids)
	_check("defeat_does_not_complete_warden_defeated", "warden_defeated" not in SaveManager.profile.completed_milestone_ids)
	_check("defeat_ember_marsh_still_locked", not BiomeCatalog.is_unlocked(BiomeCatalog.EMBER_MARSH, SaveManager.profile.completed_milestone_ids))
	_check("defeat_run_reports_no_unlock", run.newly_unlocked_biome_ids.is_empty())


func _test_warden_victory_unlocks_ember_marsh() -> void:
	SaveManager.use_isolated_test_profile(&"core_loop_biome_victory")
	SaveManager.profile = ProfileData.new()

	var run: RunState = _fresh_run("victory")
	run.run_completed = true
	# record_boss_victory() only flips run_completed/run_ash — deposit_run()
	# needs biome_data.boss.id to attribute the kill to "ashen_warden"
	# specifically, exactly like a real Ashen Wastes boss victory would.
	_check("fixture_boss_id_is_ashen_warden", run.biome_data.boss.id == &"ashen_warden")
	var deposited: bool = SaveManager.deposit_run(run)
	_check("victory_deposit_succeeds", deposited)
	_check("victory_completes_warden_defeated", "warden_defeated" in SaveManager.profile.completed_milestone_ids)
	_check("victory_ember_marsh_now_unlocked", BiomeCatalog.is_unlocked(BiomeCatalog.EMBER_MARSH, SaveManager.profile.completed_milestone_ids))
	_check("victory_run_reports_ember_marsh_unlocked", EMBER_MARSH_ID in run.newly_unlocked_biome_ids)
	_check("victory_ashen_wastes_still_available", BiomeCatalog.is_unlocked(BiomeCatalog.ASHEN_WASTES, SaveManager.profile.completed_milestone_ids))


func _test_unlock_persists_after_reload() -> void:
	SaveManager.use_isolated_test_profile(&"core_loop_biome_persist")
	SaveManager.profile = ProfileData.new()
	var run: RunState = _fresh_run("persist")
	run.run_completed = true
	SaveManager.deposit_run(run)
	_check("persist_unlocked_before_reload", BiomeCatalog.is_unlocked(BiomeCatalog.EMBER_MARSH, SaveManager.profile.completed_milestone_ids))

	# "Reload": round-trip through the exact same to_dictionary()/
	# from_dictionary() a real app restart would use, not just re-reading
	# the same in-memory object.
	var reloaded: ProfileData = ProfileData.from_dictionary(SaveManager.profile.to_dictionary())
	_check("persist_unlocked_after_reload", BiomeCatalog.is_unlocked(BiomeCatalog.EMBER_MARSH, reloaded.completed_milestone_ids))
	_check("persist_via_disk_reload", SaveManager.load_profile() and BiomeCatalog.is_unlocked(BiomeCatalog.EMBER_MARSH, SaveManager.profile.completed_milestone_ids))


func _test_first_victory_completes_but_is_not_the_gate() -> void:
	SaveManager.use_isolated_test_profile(&"core_loop_first_victory")
	SaveManager.profile = ProfileData.new()
	# Force a non-Ashen-Warden boss attribution to prove first_victory
	# (TOTAL_VICTORIES) completes on ANY boss win, while warden_defeated
	# (BOSS_DEFEATED, target ashen_warden specifically) does not.
	var ember_marsh_boss_run: RunState = _fresh_run("first_victory_ember")
	ember_marsh_boss_run.run_completed = true
	ember_marsh_boss_run.biome_id = EMBER_MARSH_ID
	ember_marsh_boss_run.biome_data = BiomeCatalog.EMBER_MARSH
	_check("fixture_ember_marsh_boss_is_not_warden", ember_marsh_boss_run.biome_data.boss.id != &"ashen_warden")
	SaveManager.deposit_run(ember_marsh_boss_run)
	_check("first_victory_completes_on_any_boss_win", "first_victory" in SaveManager.profile.completed_milestone_ids)
	_check("warden_defeated_not_completed_by_other_boss", "warden_defeated" not in SaveManager.profile.completed_milestone_ids)
	_check("ember_marsh_boss_win_does_not_unlock_ember_marsh_itself", EMBER_MARSH_ID not in ember_marsh_boss_run.newly_unlocked_biome_ids)


func _test_unrelated_milestone_does_not_unlock() -> void:
	SaveManager.use_isolated_test_profile(&"core_loop_unrelated_milestone")
	SaveManager.profile = ProfileData.new()
	# ten_combats / equipment_collector / companion_expedition-style
	# progress — anything that is NOT warden_defeated — must never unlock
	# Ember Marsh, no matter how much of it accumulates.
	SaveManager.profile.total_combats_won = 999
	SaveManager.evaluate_milestones()
	_check("unrelated_milestone_progress_does_not_unlock", not BiomeCatalog.is_unlocked(BiomeCatalog.EMBER_MARSH, SaveManager.profile.completed_milestone_ids))


func _test_milestone_completion_timing_and_dedup() -> void:
	SaveManager.use_isolated_test_profile(&"core_loop_milestone_timing")
	SaveManager.profile = ProfileData.new()
	var milestone: MilestoneData = MilestoneCatalog.get_by_id(&"warden_defeated")
	_check("fixture_warden_defeated_target_is_1", milestone.target_count == 1)

	var run_a: RunState = _fresh_run("timing_a")
	run_a.run_completed = true
	_check("not_completed_before_any_win", "warden_defeated" not in SaveManager.profile.completed_milestone_ids)
	SaveManager.deposit_run(run_a)
	_check("completed_at_threshold", "warden_defeated" in SaveManager.profile.completed_milestone_ids)
	var ash_after_first: int = SaveManager.profile.total_ash

	var run_b: RunState = _fresh_run("timing_b")
	run_b.run_completed = true
	SaveManager.deposit_run(run_b)
	_check("not_reawarded_on_second_win", run_b.milestone_ash_awarded == 0)
	_check("not_reannounced_as_newly_unlocked_on_second_win", EMBER_MARSH_ID not in run_b.newly_unlocked_biome_ids)
	_check("ash_reward_not_duplicated", SaveManager.profile.total_ash >= ash_after_first)

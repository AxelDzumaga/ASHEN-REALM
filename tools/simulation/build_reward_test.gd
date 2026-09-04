extends Node

var _failures: Array[String] = []


func _ready() -> void:
	SynergyResolver.use_stage62_baseline_rules = false
	_test_deterministic_offers()
	_test_pool_invariants()
	_test_common_rarity_modes()
	_test_affinity_remains_probabilistic()
	_test_synergy_conditions()
	_test_boss_and_augment_offers()
	var report: Dictionary = {
		"stage": 65,
		"failures": _failures,
		"tests": 6,
		"save_or_profile_written": false,
		"save_version_expected": 9,
		"debug_tools_expected": false,
	}
	var output: String = "res://build/stage65/tests/build_reward_tests.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _new_run() -> RunState:
	var run: RunState = RunState.new()
	run.biome_data = BiomeCatalog.get_or_default(&"ashen_wastes")
	run.biome_id = run.biome_data.id
	run.board_seed = 630063
	run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	run.active_skill_id = ActiveSkillCatalog.DEFAULT_SKILL_ID
	run.equipped_companion_id = CompanionCatalog.EMBER_HOUND_ID
	return run


func _test_deterministic_offers() -> void:
	var first: RunState = _new_run()
	var second: RunState = _new_run()
	var a: Array[UpgradeData] = BuildRewardResolver.generate_boon_options(first, false, 63001)
	var b: Array[UpgradeData] = BuildRewardResolver.generate_boon_options(second, false, 63001)
	if BuildRewardResolver.signature(a) != BuildRewardResolver.signature(b):
		_failures.append("same_seed_boon_offer_differs")
	var level_a: Array[UpgradeData] = BuildRewardResolver.generate_level_options(first, 63002)
	var level_b: Array[UpgradeData] = BuildRewardResolver.generate_level_options(second, 63002)
	if BuildRewardResolver.signature(level_a) != BuildRewardResolver.signature(level_b):
		_failures.append("same_seed_level_offer_differs")


func _test_pool_invariants() -> void:
	var run: RunState = _new_run()
	for seed: int in range(63010, 63110):
		var audit: Dictionary = {"enabled": true}
		var options: Array[UpgradeData] = BuildRewardResolver.generate_boon_options(run, seed % 2 == 0, seed, "", audit)
		if options.is_empty():
			_failures.append("empty_boon_offer")
			return
		var ids: Dictionary[StringName, bool] = {}
		for option: UpgradeData in options:
			if ids.has(option.id):
				_failures.append("duplicate_boon_in_offer")
				return
			ids[option.id] = true
		if int(audit.get("fallbacks", 0)) != 0:
			_failures.append("renormalized_rarity_used_fallback")
			return
	var capped: UpgradeData = UpgradeCatalog.BURNING_STRIKE
	run.active_boons[capped.id] = capped.max_stacks
	var capped_options: Array[UpgradeData] = BuildRewardResolver.generate_boon_options(run, false, 63111)
	if capped in capped_options:
		_failures.append("max_stack_boon_remains_eligible")
	run.add_boon(capped.id)
	if run.get_boon_count(capped.id) != capped.max_stacks:
		_failures.append("boon_stack_exceeds_max")


func _test_common_rarity_modes() -> void:
	var run: RunState = _new_run()
	var legacy_common_rolls: int = 0
	for seed: int in range(63120, 63220):
		var legacy_audit: Dictionary = {"enabled": true}
		BuildRewardResolver.generate_boon_options(run, false, seed, "", legacy_audit, &"fallback")
		legacy_common_rolls += int(legacy_audit.get("rarity_rolls", {}).get(str(UpgradeData.UpgradeRarity.COMMON), 0))
		var fixed_audit: Dictionary = {"enabled": true}
		BuildRewardResolver.generate_boon_options(run, false, seed, "", fixed_audit)
		if int(fixed_audit.get("rarity_rolls", {}).get(str(UpgradeData.UpgradeRarity.COMMON), 0)) != 0 or int(fixed_audit.get("fallbacks", 0)) != 0:
			_failures.append("common_roll_or_fallback_survives_renormalization")
			return
	if legacy_common_rolls == 0:
		_failures.append("legacy_common_control_not_observed")


func _test_affinity_remains_probabilistic() -> void:
	var run: RunState = _new_run()
	run.active_boons[UpgradeCatalog.BURNING_STRIKE.id] = 2
	var saw_off_build: bool = false
	var saw_offer_without_offense: bool = false
	for seed: int in range(63200, 63500):
		var options: Array[UpgradeData] = BuildRewardResolver.generate_boon_options(run, false, seed)
		var offense_count: int = 0
		for option: UpgradeData in options:
			if option.affinity == UpgradeData.Affinity.OFFENSE:
				offense_count += 1
			else:
				saw_off_build = true
		saw_offer_without_offense = saw_offer_without_offense or offense_count == 0
	if not saw_off_build:
		_failures.append("affinity_removed_off_build_choices")
	if not saw_offer_without_offense:
		_failures.append("affinity_guarantees_on_build_choice")


func _test_synergy_conditions() -> void:
	var run: RunState = _new_run()
	run.recalculate_synergies()
	if &"inferno_rhythm" in run.active_synergy_ids:
		_failures.append("inferno_activates_from_default_loadout")
	run.add_boon(&"burning_strike")
	if &"inferno_rhythm" in run.active_synergy_ids:
		_failures.append("inferno_activates_from_one_piece")
	run.add_boon(&"relentless_flame")
	if &"inferno_rhythm" not in run.active_synergy_ids:
		_failures.append("inferno_pair_does_not_activate")
	var offense_run: RunState = _new_run()
	offense_run.add_boon(&"last_ember")
	offense_run.add_boon(&"pyre_heart")
	if &"inferno_rhythm" in offense_run.active_synergy_ids:
		_failures.append("inferno_activates_from_two_offensive_boons")
	offense_run.add_boon(&"burning_strike")
	if &"inferno_rhythm" not in offense_run.active_synergy_ids:
		_failures.append("inferno_three_offensive_boons_do_not_activate")
	var guard_run: RunState = _new_run()
	guard_run.add_boon(&"ashen_bulwark")
	if &"iron_vigil" in guard_run.active_synergy_ids:
		_failures.append("iron_vigil_activates_from_default_plus_one_boon")
	guard_run.add_skill_augment(&"reinforced_ash")
	if &"iron_vigil" not in guard_run.active_synergy_ids:
		_failures.append("iron_vigil_three_sources_do_not_activate")


func _test_boss_and_augment_offers() -> void:
	var run: RunState = _new_run()
	var boss_a: Array[BossRewardData] = BuildRewardResolver.generate_boss_options(run, 63601, 3)
	var boss_b: Array[BossRewardData] = BuildRewardResolver.generate_boss_options(run, 63601, 3)
	if boss_a.size() != 3 or boss_a != boss_b:
		_failures.append("boss_offer_invalid_or_nondeterministic")
	var aug_a: Array[SkillAugmentData] = BuildRewardResolver.generate_augment_options(run, 63602)
	var aug_b: Array[SkillAugmentData] = BuildRewardResolver.generate_augment_options(run, 63602)
	if aug_a.size() != 3 or aug_a != aug_b:
		_failures.append("augment_offer_invalid_or_nondeterministic")

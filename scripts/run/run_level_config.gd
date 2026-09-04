class_name RunLevelConfig
extends RefCounted

const START_LEVEL: int = 1
const MAX_RUN_LEVEL: int = 10
const BASE_XP_REQUIREMENT: int = 50
const XP_GROWTH: float = 1.12
const NORMAL_COMBAT_XP: int = 35
const ELITE_COMBAT_XP: int = 70
const BOSS_COMBAT_XP: int = 140
const OPTION_COUNT: int = 3


static func xp_required_for_level(level: int) -> int:
	if level >= MAX_RUN_LEVEL:
		return 0
	return int(round(float(BASE_XP_REQUIREMENT) * pow(XP_GROWTH, float(maxi(0, level - 1)))))


static func get_level_up_pool(run: RunState) -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	for upgrade: UpgradeData in UpgradeCatalog.get_stat_upgrades():
		if run.get_run_level_upgrade_count(upgrade.id) < upgrade.max_stacks:
			result.append(upgrade)
	return result


static func generate_options(run: RunState) -> Array[UpgradeData]:
	var derived_seed: int = BuildRewardResolver.make_seed(run, &"level_up", run.level_up_choices_generated)
	return BuildRewardResolver.generate_level_options(run, derived_seed)

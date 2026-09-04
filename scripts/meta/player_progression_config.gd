class_name PlayerProgressionConfig
extends RefCounted

## Progresión permanente del viajero. Independiente del nivel temporal de run.
const START_LEVEL: int = 1
const MAX_LEVEL: int = 50
const BASE_XP_REQUIREMENT: int = 100
const LINEAR_GROWTH: int = 28
const QUADRATIC_GROWTH: int = 4

const NORMAL_COMBAT_XP: int = 18
const ELITE_COMBAT_XP: int = 42
const BOSS_COMBAT_XP: int = 90
const RUN_FINISH_XP: int = 20


static func xp_required_for_level(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	var safe_level: int = clampi(level, START_LEVEL, MAX_LEVEL)
	var offset: int = safe_level - START_LEVEL
	return BASE_XP_REQUIREMENT + offset * LINEAR_GROWTH + offset * offset * QUADRATIC_GROWTH


static func calculate_run_xp(run_state: RunState) -> int:
	if run_state == null:
		return 0
	var normal_wins: int = maxi(0, run_state.combats_won - run_state.elites_won)
	var total: int = RUN_FINISH_XP
	total += normal_wins * NORMAL_COMBAT_XP
	total += maxi(0, run_state.elites_won) * ELITE_COMBAT_XP
	if run_state.run_completed:
		total += BOSS_COMBAT_XP
	return total


static func sanitize_progress(level: int, xp: int) -> Dictionary:
	var safe_level: int = clampi(level, START_LEVEL, MAX_LEVEL)
	var safe_xp: int = maxi(0, xp)
	while safe_level < MAX_LEVEL:
		var requirement: int = xp_required_for_level(safe_level)
		if requirement <= 0 or safe_xp < requirement:
			break
		safe_xp -= requirement
		safe_level += 1
	if safe_level >= MAX_LEVEL:
		safe_xp = 0
	return {"level": safe_level, "xp": safe_xp}

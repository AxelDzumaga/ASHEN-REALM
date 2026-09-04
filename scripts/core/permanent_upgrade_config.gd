class_name PermanentUpgradeConfig
extends RefCounted

enum UpgradeType {
	VITALITY,
	MIGHT,
	GUARD,
}

const MAX_LEVEL := 10
const VITALITY_BASE_COST := 30
const MIGHT_BASE_COST := 40
const GUARD_BASE_COST := 40


static func get_cost(type: UpgradeType, current_level: int) -> int:
	return get_base_cost(type) * (current_level + 1)


static func get_base_cost(type: UpgradeType) -> int:
	match type:
		UpgradeType.VITALITY:
			return VITALITY_BASE_COST
		UpgradeType.MIGHT:
			return MIGHT_BASE_COST
		UpgradeType.GUARD:
			return GUARD_BASE_COST
		_:
			return 0


static func get_level(profile: ProfileData, type: UpgradeType) -> int:
	match type:
		UpgradeType.VITALITY:
			return profile.permanent_health_level
		UpgradeType.MIGHT:
			return profile.permanent_attack_level
		UpgradeType.GUARD:
			return profile.permanent_defense_level
		_:
			return 0


static func set_level(profile: ProfileData, type: UpgradeType, level: int) -> void:
	var safe_level := clampi(level, 0, MAX_LEVEL)
	match type:
		UpgradeType.VITALITY:
			profile.permanent_health_level = safe_level
		UpgradeType.MIGHT:
			profile.permanent_attack_level = safe_level
		UpgradeType.GUARD:
			profile.permanent_defense_level = safe_level


static func get_total_bonus(type: UpgradeType, level: int) -> int:
	match type:
		UpgradeType.VITALITY:
			return clampi(level, 0, MAX_LEVEL) * 5
		UpgradeType.MIGHT, UpgradeType.GUARD:
			return clampi(level, 0, MAX_LEVEL)
		_:
			return 0

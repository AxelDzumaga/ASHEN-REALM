class_name MilestoneData
extends Resource

enum ConditionType {
	TOTAL_RUNS,
	TOTAL_VICTORIES,
	TOTAL_COMBATS,
	BOSS_DEFEATED,
	EPIC_EQUIPMENT_OWNED,
	SYNERGY_DISCOVERED,
	FULL_SKILL_LOADOUT,
	COMPANION_RUNS,
	EQUIPMENT_COLLECTION,
}

@export var milestone_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var condition_type: ConditionType = ConditionType.TOTAL_RUNS
@export_range(1, 100000, 1) var target_count: int = 1
@export var target_id: StringName = &""
@export_range(0, 1000, 1) var reward_ash: int = 0
@export_range(0, 1000, 1) var priority: int = 100
@export var icon_id: StringName = &"ash"

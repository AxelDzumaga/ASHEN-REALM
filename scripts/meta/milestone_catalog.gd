class_name MilestoneCatalog
extends RefCounted

const MilestoneDataType = preload("res://scripts/data/milestone_data.gd")

const FIRST_EXPEDITION: MilestoneDataType = preload("res://data/milestones/first_expedition.tres")
const FIRST_VICTORY: MilestoneDataType = preload("res://data/milestones/first_victory.tres")
const FIVE_EXPEDITIONS: MilestoneDataType = preload("res://data/milestones/five_expeditions.tres")
const TEN_COMBATS: MilestoneDataType = preload("res://data/milestones/ten_combats.tres")
const FIRST_EPIC: MilestoneDataType = preload("res://data/milestones/first_epic.tres")
const FIRST_SYNERGY: MilestoneDataType = preload("res://data/milestones/first_synergy.tres")
const COMPANION_EXPEDITION: MilestoneDataType = preload("res://data/milestones/companion_expedition.tres")
const WARDEN_DEFEATED: MilestoneDataType = preload("res://data/milestones/warden_defeated.tres")
const PYRE_DEFEATED: MilestoneDataType = preload("res://data/milestones/pyre_defeated.tres")
const EQUIPMENT_COLLECTOR: MilestoneDataType = preload("res://data/milestones/equipment_collector.tres")

const ALL: Array[MilestoneDataType] = [
	FIRST_EXPEDITION,
	FIRST_VICTORY,
	FIVE_EXPEDITIONS,
	TEN_COMBATS,
	FIRST_EPIC,
	FIRST_SYNERGY,
	COMPANION_EXPEDITION,
	WARDEN_DEFEATED,
	PYRE_DEFEATED,
	EQUIPMENT_COLLECTOR,
]


static func get_all() -> Array[MilestoneDataType]:
	return ALL.duplicate()


static func get_by_id(milestone_id: StringName) -> MilestoneDataType:
	for milestone: MilestoneDataType in ALL:
		if milestone.milestone_id == milestone_id:
			return milestone
	return null


static func get_total_reward_ash() -> int:
	var total: int = 0
	for milestone: MilestoneDataType in ALL:
		total += milestone.reward_ash
	return total

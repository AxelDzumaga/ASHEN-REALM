class_name SkillAugmentCatalog
extends RefCounted

const SEARING_EDGE: SkillAugmentData = preload("res://data/skill_augments/ember_slash/searing_edge.tres")
const EMBER_EFFICIENCY: SkillAugmentData = preload("res://data/skill_augments/ember_slash/ember_efficiency.tres")
const EXECUTIONERS_EMBER: SkillAugmentData = preload("res://data/skill_augments/ember_slash/executioners_ember.tres")
const REINFORCED_ASH: SkillAugmentData = preload("res://data/skill_augments/ashen_guard/reinforced_ash.tres")
const STORED_EMBERS: SkillAugmentData = preload("res://data/skill_augments/ashen_guard/stored_embers.tres")
const COUNTER_GUARD: SkillAugmentData = preload("res://data/skill_augments/ashen_guard/counter_guard.tres")
const DEEP_BREATH: SkillAugmentData = preload("res://data/skill_augments/second_wind/deep_breath.tres")
const QUICK_RECOVERY: SkillAugmentData = preload("res://data/skill_augments/second_wind/quick_recovery.tres")
const ASHEN_RENEWAL: SkillAugmentData = preload("res://data/skill_augments/second_wind/ashen_renewal.tres")

const ALL: Array[SkillAugmentData] = [
	SEARING_EDGE, EMBER_EFFICIENCY, EXECUTIONERS_EMBER,
	REINFORCED_ASH, STORED_EMBERS, COUNTER_GUARD,
	DEEP_BREATH, QUICK_RECOVERY, ASHEN_RENEWAL,
]


static func get_all() -> Array[SkillAugmentData]:
	return ALL.duplicate()


static func get_by_id(augment_id: StringName) -> SkillAugmentData:
	for augment: SkillAugmentData in ALL:
		if augment.id == augment_id:
			return augment
	return null


static func get_for_skill(skill_id: StringName) -> Array[SkillAugmentData]:
	var result: Array[SkillAugmentData] = []
	for augment: SkillAugmentData in ALL:
		if augment.skill_id == skill_id:
			result.append(augment)
	return result


static func get_eligible_for_run(run: RunState) -> Array[SkillAugmentData]:
	var result: Array[SkillAugmentData] = []
	for skill_id: StringName in run.equipped_skill_ids:
		if skill_id.is_empty():
			continue
		for augment: SkillAugmentData in get_for_skill(skill_id):
			if run.get_skill_augment_count(augment.id) < augment.max_stacks:
				result.append(augment)
	return result

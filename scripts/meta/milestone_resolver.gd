class_name MilestoneResolver
extends RefCounted

const MilestoneDataType = preload("res://scripts/data/milestone_data.gd")
const MilestoneCatalogSource = preload("res://scripts/meta/milestone_catalog.gd")

const RANK_POINTS_PER_LEVEL: int = 25
const MAX_RANK: int = 8

class CompletionResult extends RefCounted:
	var completed_ids: Array[StringName] = []
	var reward_ash: int = 0


static func evaluate(profile: ProfileData) -> CompletionResult:
	var result: CompletionResult = CompletionResult.new()
	for milestone: MilestoneDataType in MilestoneCatalogSource.get_all():
		if String(milestone.milestone_id) in profile.completed_milestone_ids:
			continue
		if get_progress(profile, milestone) < milestone.target_count:
			continue
		profile.completed_milestone_ids.append(String(milestone.milestone_id))
		profile.pending_milestone_ids.append(String(milestone.milestone_id))
		profile.total_ash += milestone.reward_ash
		result.completed_ids.append(milestone.milestone_id)
		result.reward_ash += milestone.reward_ash
	return result


static func sanitize_profile(profile: ProfileData) -> void:
	var completed: Array[String] = []
	for value: String in profile.completed_milestone_ids:
		if MilestoneCatalogSource.get_by_id(StringName(value)) != null and value not in completed:
			completed.append(value)
	profile.completed_milestone_ids = completed
	var pending: Array[String] = []
	for value: String in profile.pending_milestone_ids:
		if value in completed and value not in pending:
			pending.append(value)
	profile.pending_milestone_ids = pending
	var safe_boss_counts: Dictionary = {}
	for boss_id: Variant in profile.boss_defeat_counts:
		var id: StringName = StringName(String(boss_id))
		if not CodexCatalog.has_entry(CodexCatalog.BOSSES, id):
			continue
		var count: int = maxi(0, int(profile.boss_defeat_counts[boss_id]))
		if count > 0:
			safe_boss_counts[String(id)] = count
	profile.boss_defeat_counts = safe_boss_counts


static func get_progress(profile: ProfileData, milestone: MilestoneDataType) -> int:
	if profile == null or milestone == null:
		return 0
	match milestone.condition_type:
		MilestoneDataType.ConditionType.TOTAL_RUNS:
			return profile.total_runs
		MilestoneDataType.ConditionType.TOTAL_VICTORIES:
			return profile.total_victories
		MilestoneDataType.ConditionType.TOTAL_COMBATS:
			return profile.total_combats_won
		MilestoneDataType.ConditionType.BOSS_DEFEATED:
			return int(profile.boss_defeat_counts.get(String(milestone.target_id), 0))
		MilestoneDataType.ConditionType.EPIC_EQUIPMENT_OWNED:
			return _count_owned_epics(profile)
		MilestoneDataType.ConditionType.SYNERGY_DISCOVERED:
			return DiscoveryTracker.get_discovered_count_for_profile(profile, CodexCatalog.SYNERGIES)
		MilestoneDataType.ConditionType.FULL_SKILL_LOADOUT:
			return _equipped_skill_count(profile)
		MilestoneDataType.ConditionType.COMPANION_RUNS:
			return profile.total_companion_runs
		MilestoneDataType.ConditionType.EQUIPMENT_COLLECTION:
			return get_owned_equipment_count(profile)
		_:
			return 0


static func get_next_goal(profile: ProfileData) -> MilestoneDataType:
	var candidates: Array[MilestoneDataType] = []
	for milestone: MilestoneDataType in MilestoneCatalogSource.get_all():
		if String(milestone.milestone_id) not in profile.completed_milestone_ids:
			candidates.append(milestone)
	candidates.sort_custom(func(a: MilestoneDataType, b: MilestoneDataType) -> bool:
		if a.priority == b.priority:
			return String(a.milestone_id) < String(b.milestone_id)
		return a.priority < b.priority
	)
	return candidates[0] if not candidates.is_empty() else null


static func get_progress_text(profile: ProfileData, milestone: MilestoneDataType) -> String:
	if milestone == null:
		return "TODOS LOS HITOS COMPLETADOS"
	return "%d / %d" % [mini(get_progress(profile, milestone), milestone.target_count), milestone.target_count]


static func get_owned_equipment_count(profile: ProfileData) -> int:
	var count: int = 0
	for item: EquipmentData in EquipmentCatalog.get_all():
		if int(profile.owned_equipment.get(String(item.id), 0)) > 0:
			count += 1
	return count


static func get_unlocked_companion_count(profile: ProfileData) -> int:
	var count: int = 0
	for companion: CompanionData in CompanionCatalog.get_all():
		if companion.companion_id in profile.unlocked_companion_ids:
			count += 1
	return count


static func get_meta_points(profile: ProfileData) -> int:
	var upgrade_levels: int = (
		profile.permanent_health_level
		+ profile.permanent_attack_level
		+ profile.permanent_defense_level
	)
	return (
		profile.completed_milestone_ids.size() * 10
		+ upgrade_levels * 2
		+ get_owned_equipment_count(profile)
		+ floori(float(DiscoveryTracker.get_total_discovered_count_for_profile(profile)) / 10.0)
	)


static func get_ashen_rank(profile: ProfileData) -> int:
	return clampi(1 + floori(float(get_meta_points(profile)) / float(RANK_POINTS_PER_LEVEL)), 1, MAX_RANK)


static func get_rank_progress_text(profile: ProfileData) -> String:
	var rank: int = get_ashen_rank(profile)
	if rank >= MAX_RANK:
		return "MAX"
	var points: int = get_meta_points(profile)
	return "%d / %d" % [points % RANK_POINTS_PER_LEVEL, RANK_POINTS_PER_LEVEL]


static func _count_owned_epics(profile: ProfileData) -> int:
	var count: int = 0
	for item: EquipmentData in EquipmentCatalog.get_all():
		if item.rarity == EquipmentData.Rarity.EPIC and int(profile.owned_equipment.get(String(item.id), 0)) > 0:
			count += 1
	return count


static func _equipped_skill_count(profile: ProfileData) -> int:
	var count: int = 0
	for skill_id: StringName in profile.equipped_skill_ids:
		if not skill_id.is_empty() and ActiveSkillCatalog.get_by_id(skill_id) != null:
			count += 1
	return count

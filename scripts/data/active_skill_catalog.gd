class_name ActiveSkillCatalog
extends RefCounted

const DEFAULT_SKILL_ID: StringName = &"ember_slash"
const EMBER_SLASH: ActiveSkillData = preload("res://data/skills/ember_slash.tres")
const ASHEN_GUARD: ActiveSkillData = preload("res://data/skills/ashen_guard.tres")
const SECOND_WIND: ActiveSkillData = preload("res://data/skills/second_wind.tres")
const SKILLS: Array[ActiveSkillData] = [EMBER_SLASH, ASHEN_GUARD, SECOND_WIND]
const MAX_EQUIPPED_SKILLS: int = 3


static func get_all() -> Array[ActiveSkillData]:
	return SKILLS.duplicate()


static func get_by_id(skill_id: StringName) -> ActiveSkillData:
	for active_skill: ActiveSkillData in SKILLS:
		if active_skill.id == skill_id:
			return active_skill
	return null


static func get_or_default(skill_id: StringName) -> ActiveSkillData:
	var active_skill: ActiveSkillData = get_by_id(skill_id)
	return active_skill if active_skill != null else EMBER_SLASH


static func sanitize_id(skill_id: StringName) -> StringName:
	return skill_id if get_by_id(skill_id) != null else DEFAULT_SKILL_ID


static func get_default_loadout() -> Array[StringName]:
	return [EMBER_SLASH.id, ASHEN_GUARD.id, SECOND_WIND.id]


static func get_default_unlocked_ids() -> Array[StringName]:
	return get_default_loadout()


static func sanitize_unlocked_ids(raw_ids: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for skill_id: StringName in raw_ids:
		var skill: ActiveSkillData = get_by_id(skill_id)
		if skill != null and skill.enabled and skill_id not in result:
			result.append(skill_id)
	return get_default_unlocked_ids() if result.is_empty() else result


static func sanitize_loadout(raw_ids: Array[StringName], unlocked_ids: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	var equipped: Array[StringName] = []
	for skill_id: StringName in raw_ids:
		if result.size() >= MAX_EQUIPPED_SKILLS:
			break
		var skill: ActiveSkillData = get_by_id(skill_id)
		if skill_id.is_empty():
			result.append(&"")
		elif skill != null and skill.enabled and skill_id in unlocked_ids and skill_id not in equipped:
			result.append(skill_id)
			equipped.append(skill_id)
		else:
			result.append(&"")
	while not result.is_empty() and result.back().is_empty():
		result.pop_back()
	return result


static func migrate_legacy_loadout(legacy_skill_id: StringName, unlocked_ids: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	var safe_legacy_id: StringName = sanitize_id(legacy_skill_id)
	if safe_legacy_id in unlocked_ids:
		result.append(safe_legacy_id)
	for skill_id: StringName in get_default_loadout():
		if result.size() >= MAX_EQUIPPED_SKILLS:
			break
		if skill_id in unlocked_ids and skill_id not in result:
			result.append(skill_id)
	return result


static func type_name(skill_type: ActiveSkillData.SkillType) -> String:
	match skill_type:
		ActiveSkillData.SkillType.DEFENSE:
			return "DEFENSA"
		ActiveSkillData.SkillType.HEAL:
			return "CURACIÓN"
		_:
			return "DAÑO"

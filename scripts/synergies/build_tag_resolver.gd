class_name BuildTagResolver
extends RefCounted

const BURN: StringName = &"burn"
const EMBER: StringName = &"ember"
const CRIT: StringName = &"crit"
const SKILL: StringName = &"skill"
const HEAL: StringName = &"heal"
const GUARD: StringName = &"guard"
const LOW_HP: StringName = &"low_hp"
const DEFENSE: StringName = &"defense"
const STATUS: StringName = &"status"
const COMPANION: StringName = &"companion"
const ATTACK: StringName = &"attack"
const ENERGY: StringName = &"energy"

const ALL_TAGS: Array[StringName] = [
	BURN, EMBER, CRIT, SKILL, HEAL, GUARD, LOW_HP,
	DEFENSE, STATUS, COMPANION, ATTACK, ENERGY,
]


static func resolve(run: RunState, offered_boon: UpgradeData = null) -> BuildTagReport:
	var report: BuildTagReport = BuildTagReport.new()
	if run == null:
		return report
	_add_equipment(report, EquipmentCatalog.get_by_id(String(run.equipped_weapon_id)))
	_add_equipment(report, EquipmentCatalog.get_by_id(String(run.equipped_armor_id)))
	for skill_id: StringName in run.equipped_skill_ids:
		var skill: ActiveSkillData = ActiveSkillCatalog.get_by_id(skill_id)
		if skill != null:
			var skill_tags: Array[StringName] = [SKILL]
			skill_tags.append_array(_normalize_tags(skill.tags))
			report.add_source(StringName("skill:%s" % skill.id), skill_tags)
	for augment_id: StringName in run.skill_augments:
		if run.get_skill_augment_count(augment_id) <= 0:
			continue
		var augment: SkillAugmentData = SkillAugmentCatalog.get_by_id(augment_id)
		if augment != null:
			report.add_source(StringName("augment:%s" % augment.id), _normalize_tags(augment.tags))
	for boon_id: StringName in run.active_boons:
		if run.get_boon_count(boon_id) <= 0:
			continue
		var boon: UpgradeData = UpgradeCatalog.get_by_id(boon_id)
		if boon != null and boon.category == UpgradeData.Category.PASSIVE:
			report.add_source(StringName("boon:%s" % boon.id), _normalize_tags(boon.tags))
	if offered_boon != null and offered_boon.category == UpgradeData.Category.PASSIVE:
		report.add_source(StringName("boon:%s" % offered_boon.id), _normalize_tags(offered_boon.tags))
	var companion: CompanionData = CompanionCatalog.get_by_id(run.equipped_companion_id)
	if companion != null:
		var companion_tags: Array[StringName] = [COMPANION]
		companion_tags.append_array(_normalize_tags(companion.tags))
		report.add_source(StringName("companion:%s" % companion.companion_id), companion_tags)
	if run.biome_data != null and run.biome_data.build_affinity_tag in ALL_TAGS:
		var biome_tags: Array[StringName] = [run.biome_data.build_affinity_tag]
		report.add_source(StringName("biome:%s" % run.biome_data.id), biome_tags)
	return report


static func _add_equipment(report: BuildTagReport, item: EquipmentData) -> void:
	if item == null:
		return
	var tags: Array[StringName] = _normalize_tags(item.tags)
	if item.attack_bonus > 0:
		tags.append(ATTACK)
	match item.affinity:
		EquipmentData.Affinity.EMBER:
			tags.append(EMBER)
		EquipmentData.Affinity.MIRE:
			tags.append(HEAL)
		EquipmentData.Affinity.WARDEN:
			tags.append(DEFENSE)
		EquipmentData.Affinity.ASH:
			tags.append(ATTACK)
	if item.crit_chance > 0.0 or item.crit_damage_bonus > 0.0:
		tags.append(CRIT)
	if item.ember_gain_bonus > 0.0:
		tags.append(ENERGY)
	if item.healing_power_bonus > 0.0:
		tags.append(HEAL)
	if item.skill_damage_bonus > 0.0:
		tags.append(SKILL)
	match item.passive_effect_id:
		EquipmentEffectResolver.BURNING_EDGE:
			tags.append(BURN)
		EquipmentEffectResolver.BLOODBOUND:
			tags.append(LOW_HP)
		EquipmentEffectResolver.MIRE_REGENERATION:
			tags.append(HEAL)
			tags.append(STATUS)
		EquipmentEffectResolver.WARDEN_FIRST_GUARD:
			tags.append(GUARD)
			tags.append(DEFENSE)
		EquipmentEffectResolver.SUNDERING_EDGE:
			tags.append(STATUS)
			tags.append(ATTACK)
		EquipmentEffectResolver.GUARDED_REGROWTH:
			tags.append(GUARD)
			tags.append(HEAL)
			tags.append(STATUS)
	report.add_source(StringName("equipment:%s" % item.id), tags)


static func _normalize_tags(raw_tags: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for raw_tag: StringName in raw_tags:
		var tag: StringName = raw_tag
		match raw_tag:
			&"critical": tag = CRIT
			&"healing", &"sustain": tag = HEAL
			&"low_health": tag = LOW_HP
			&"offense", &"melee": tag = ATTACK
			&"regen": tag = STATUS
		if tag in ALL_TAGS and tag not in result:
			result.append(tag)
	return result

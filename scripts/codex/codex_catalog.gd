class_name CodexCatalog
extends RefCounted

const REGIONS := &"regions"
const ENEMIES := &"enemies"
const ELITES := &"elites"
const BOSSES := &"bosses"
const EQUIPMENT := &"equipment"
const BOONS := &"boons"
const SYNERGIES := &"synergies"
const ACTIVE_SKILLS := &"active_skills"
const SKILL_AUGMENTS := &"skill_augments"
const COMPANIONS := &"companions"

const CATEGORIES: Array[StringName] = [
	REGIONS, ENEMIES, ELITES, BOSSES, EQUIPMENT, BOONS,
	SYNERGIES, ACTIVE_SKILLS, SKILL_AUGMENTS, COMPANIONS,
]


static func get_categories() -> Array[StringName]:
	return CATEGORIES.duplicate()


static func get_category_name(category: StringName) -> String:
	match category:
		REGIONS: return "REGIONES"
		ENEMIES: return "ENEMIGOS"
		ELITES: return "ÉLITES"
		BOSSES: return "JEFES"
		EQUIPMENT: return "EQUIPAMIENTO"
		BOONS: return "BENDICIONES"
		SYNERGIES: return "SINERGIAS"
		ACTIVE_SKILLS: return "HABILIDADES ACTIVAS"
		SKILL_AUGMENTS: return "AUMENTOS DE HABILIDAD"
		COMPANIONS: return "COMPAÑEROS"
		_: return "DESCONOCIDO"


static func get_entries(category: StringName) -> Array[CodexEntry]:
	var result: Array[CodexEntry] = []
	match category:
		REGIONS:
			for biome: BiomeData in BiomeCatalog.get_all():
				result.append(CodexEntry.new(category, biome.id, biome.display_name))
		ENEMIES:
			_append_enemies(result, category, false, false)
		ELITES:
			_append_enemies(result, category, true, false)
		BOSSES:
			_append_enemies(result, category, false, true)
		EQUIPMENT:
			for item: EquipmentData in EquipmentCatalog.get_all():
				result.append(CodexEntry.new(category, item.id, item.display_name))
		BOONS:
			for upgrade: UpgradeData in UpgradeCatalog.get_all():
				if upgrade.category == UpgradeData.Category.PASSIVE:
					result.append(CodexEntry.new(category, upgrade.id, upgrade.display_name))
		SYNERGIES:
			for synergy_id: StringName in BoonSynergyResolver.ALL:
				result.append(CodexEntry.new(category, synergy_id, BoonSynergyResolver.get_display_name(synergy_id)))
		ACTIVE_SKILLS:
			for active_skill: ActiveSkillData in ActiveSkillCatalog.get_all():
				result.append(CodexEntry.new(category, active_skill.id, active_skill.display_name))
		SKILL_AUGMENTS:
			for augment: SkillAugmentData in SkillAugmentCatalog.get_all():
				result.append(CodexEntry.new(category, augment.id, augment.display_name))
		COMPANIONS:
			for companion: CompanionData in CompanionCatalog.get_all():
				result.append(CodexEntry.new(category, companion.companion_id, companion.display_name))
	return result


static func get_entry(category: StringName, entry_id: StringName) -> CodexEntry:
	for entry: CodexEntry in get_entries(category):
		if entry.id == entry_id:
			return entry
	return null


static func has_entry(category: StringName, entry_id: StringName) -> bool:
	return get_entry(category, entry_id) != null


static func get_total_count() -> int:
	var total: int = 0
	for category: StringName in CATEGORIES:
		total += get_entries(category).size()
	return total


static func get_unknown_title(category: StringName) -> String:
	match category:
		ENEMIES:
			return "CRIATURA DESCONOCIDA"
		ELITES:
			return "ÉLITE DESCONOCIDA"
		BOSSES:
			return "JEFE DESCONOCIDO"
		EQUIPMENT:
			return "EQUIPAMIENTO DESCONOCIDO"
		BOONS:
			return "BENDICIÓN DESCONOCIDA"
		SYNERGIES:
			return "SINERGIA DESCONOCIDA"
		SKILL_AUGMENTS:
			return "AUMENTO DE HABILIDAD DESCONOCIDO"
		COMPANIONS:
			return "COMPAÑERO DESCONOCIDO"
		_:
			return "ENTRADA DESCONOCIDA"


static func get_detail(category: StringName, entry_id: StringName, profile: ProfileData) -> String:
	match category:
		REGIONS:
			return _region_detail(BiomeCatalog.get_by_id(entry_id))
		ENEMIES, ELITES, BOSSES:
			return _enemy_detail(category, entry_id)
		EQUIPMENT:
			return _equipment_detail(EquipmentCatalog.get_by_id(String(entry_id)), profile)
		BOONS:
			return _boon_detail(UpgradeCatalog.get_by_id(entry_id), profile)
		SYNERGIES:
			return _synergy_detail(entry_id)
		ACTIVE_SKILLS:
			return _skill_detail(ActiveSkillCatalog.get_by_id(entry_id))
		SKILL_AUGMENTS:
			return _augment_detail(SkillAugmentCatalog.get_by_id(entry_id))
		COMPANIONS:
			return _companion_detail(CompanionCatalog.get_by_id(entry_id), profile)
		_:
			return "No hay información disponible en el Archivo."


static func _append_enemies(result: Array[CodexEntry], category: StringName, elites: bool, boss: bool) -> void:
	for biome: BiomeData in BiomeCatalog.get_all():
		if boss:
			result.append(CodexEntry.new(category, biome.boss.id, biome.boss.display_name, biome.id))
			continue
		var pool: Array[EnemyData] = biome.elite_enemy_pool if elites else biome.normal_enemy_pool
		for enemy: EnemyData in pool:
			result.append(CodexEntry.new(category, enemy.id, enemy.display_name, biome.id))


static func _region_detail(biome: BiomeData) -> String:
	if biome == null:
		return "Región desconocida."
	return "%s\n\n%s\n\n%s\n\nLongitud del tablero: %d\nEnemigos: %d\nÉlites: %d\nJefe: %s\n\nDESCUBIERTA" % [
		biome.display_name.to_upper(), biome.subtitle, biome.description, biome.board_length,
		biome.normal_enemy_pool.size(), biome.elite_enemy_pool.size(), biome.boss.display_name,
	]


static func _enemy_detail(category: StringName, entry_id: StringName) -> String:
	var entry: CodexEntry = get_entry(category, entry_id)
	if entry == null:
		return "Encuentro desconocido."
	var enemy: EnemyData = _find_enemy(category, entry_id)
	var biome: BiomeData = BiomeCatalog.get_by_id(entry.region_id)
	var encounter_type: String = "JEFE" if category == BOSSES else ("ÉLITE" if category == ELITES else "ENEMIGO")
	var role_name: String = enemy.ai_profile.get_role_name() if enemy.ai_profile != null else "ENEMIGO"
	var action_names: Array[String] = enemy.ai_profile.get_action_names() if enemy.ai_profile != null else ["Ataque"]
	var boss_detail: String = ""
	if category == BOSSES and enemy.boss_encounter != null:
		var phase_names: Array[String] = []
		for phase: BossPhaseData in enemy.boss_encounter.phases:
			if phase != null:
				phase_names.append("%s (%d%%)" % [phase.display_name, phase.hp_threshold_percent])
				if phase.ai_profile_override != null:
					for phase_action_name: String in phase.ai_profile_override.get_action_names():
						if phase_action_name not in action_names:
							action_names.append(phase_action_name)
		if enemy.boss_encounter.summon_action != null and enemy.boss_encounter.summon_action.display_name not in action_names:
			action_names.append(enemy.boss_encounter.summon_action.display_name)
		boss_detail = "\n\nMECÁNICA\n%s\n\nFASES\n%s" % [
			enemy.boss_encounter.mechanic_description,
			" → ".join(phase_names),
		]
	return "%s\n\n%s\nRegión: %s\nRol: %s\nHabilidades: %s\n\nVida: %d\nAtaque: %d\nDefensa: %d\n%s%s\n\nUna criatura encontrada en %s." % [
		enemy.display_name.to_upper(), encounter_type, biome.display_name,
		role_name, ", ".join(action_names), enemy.max_health, enemy.attack, enemy.defense, enemy.get_affinity_summary(), boss_detail, biome.display_name,
	]


static func _find_enemy(category: StringName, entry_id: StringName) -> EnemyData:
	for biome: BiomeData in BiomeCatalog.get_all():
		if category == BOSSES and biome.boss.id == entry_id:
			return biome.boss
		var pool: Array[EnemyData] = biome.elite_enemy_pool if category == ELITES else biome.normal_enemy_pool
		for enemy: EnemyData in pool:
			if enemy.id == entry_id:
				return enemy
	return null


static func get_enemy(category: StringName, entry_id: StringName) -> EnemyData:
	if category != ENEMIES and category != ELITES and category != BOSSES:
		return null
	return _find_enemy(category, entry_id)


static func _equipment_detail(item: EquipmentData, profile: ProfileData) -> String:
	if item == null:
		return "Equipamiento desconocido."
	var amount: int = int(profile.owned_equipment.get(String(item.id), 0))
	var equipped: bool = String(item.id) == EquipmentCatalog.get_equipped_id_for_slot(profile, item.slot)
	var passive_text: String = EquipmentCatalog.get_passive_text(item)
	return "%s\n\n%s · TIER %d · %s\nREQUISITO: NIVEL %d · %s\n\n%s\n\n%s%s%s" % [
		item.display_name.to_upper(), EquipmentCatalog.get_rarity_name(item.rarity).to_upper(),
		item.tier, EquipmentCatalog.get_slot_label(item.slot),
		item.required_level, "EQUIPABLE" if profile.player_level >= item.required_level else "BLOQUEADO",
		item.description,
		EquipmentCatalog.get_stats_text(item), "\n\n" + passive_text if not passive_text.is_empty() else "",
		"\nPoseídos: %d%s" % [amount, " · EQUIPADO" if equipped else ""] if amount > 0 else "",
	]


static func _companion_detail(companion: CompanionData, profile: ProfileData) -> String:
	if companion == null:
		return "Compañero desconocido."
	var equipped: bool = profile.equipped_companion_id == companion.companion_id
	return "%s\n\nCOMPAÑERO · %s\n\n%s\n\nVida: %d\nAtaque: %d\nDefensa: %d\n\n%s\n%s\n\n%s\n%s" % [
		companion.display_name.to_upper(),
		"EQUIPADO" if equipped else "DISPONIBLE",
		companion.description,
		companion.max_hp,
		companion.attack,
		companion.defense,
		companion.passive_name.to_upper(),
		companion.passive_description,
		companion.ability_name.to_upper(),
		companion.ability_description,
	]


static func _boon_detail(boon: UpgradeData, profile: ProfileData) -> String:
	if boon == null:
		return "Bendición desconocida."
	var related: Array[String] = []
	for synergy_id: StringName in BoonSynergyResolver.ALL:
		var synergy_key: String = "%s:%s" % [String(SYNERGIES), String(synergy_id)]
		if synergy_key in profile.discovered_codex_entries and boon.id in BoonSynergyResolver.get_required_boons(synergy_id):
			related.append(BoonSynergyResolver.get_display_name(synergy_id))
	return "%s\n\n%s · %s\n\n%s\n\nBase: %s\nAcumulación: %s\n\nSinergias relacionadas: %s" % [
		boon.display_name.to_upper(), UpgradeCatalog.get_affinity_name(boon.affinity),
		UpgradeCatalog.get_rarity_name(boon.rarity), boon.description,
		BoonController.describe_next_copy(boon.id, 0), BoonController.describe_next_copy(boon.id, 1),
		", ".join(related) if not related.is_empty() else "Ninguna",
	]


static func _synergy_detail(synergy_id: StringName) -> String:
	return "%s\n\n%s\n\nRequiere:\n%s\n\nEfecto:\n%s" % [
		BoonSynergyResolver.get_display_name(synergy_id), BoonSynergyResolver.get_description(synergy_id),
		BoonSynergyResolver.get_requirements_text(synergy_id).replace(" + ", "\n"),
		BoonSynergyResolver.get_effect_text(synergy_id),
	]


static func _skill_detail(active_skill: ActiveSkillData) -> String:
	if active_skill == null:
		return "Habilidad activa desconocida."
	return "%s\n\n%s\n\n%s\n\nCosto de Brasa: %d\nRecarga: %d ataques básicos\n\n%s" % [
		active_skill.display_name.to_upper(), ActiveSkillCatalog.type_name(active_skill.skill_type),
		active_skill.description, active_skill.energy_cost, active_skill.cooldown_turns, active_skill.effect_summary,
	]


static func _augment_detail(augment: SkillAugmentData) -> String:
	if augment == null:
		return "Aumento de habilidad desconocido."
	var active_skill: ActiveSkillData = ActiveSkillCatalog.get_by_id(augment.skill_id)
	return "%s\n\nPara: %s\nCategoría: %s\nRango máximo: %s\n\n%s\n\nProgresión:\n%s" % [
		augment.display_name.to_upper(), active_skill.display_name, augment.category,
		SkillAugmentResolver.roman(augment.max_stacks), augment.description, _augment_progression(augment.id),
	]


static func _augment_progression(augment_id: StringName) -> String:
	match augment_id:
		&"searing_edge":
			return "Base 200% · Rango I 220% · Rango II 240%"
		&"ember_efficiency":
			return "Base 100 de Brasa · Rango I 85 · Rango II 70"
		&"executioners_ember":
			return "Rango I: +35% de daño final con 25% de Vida enemiga o menos"
		&"reinforced_ash":
			return "Base 70% · Rango I 75% · Rango II 80%"
		&"stored_embers":
			return "Rango I +15 de Brasa · Rango II +25 de Brasa"
		&"counter_guard":
			return "Rango I 8 de daño · Rango II 14 de daño"
		&"deep_breath":
			return "Base 30% · Rango I 35% · Rango II 40% de Vida máxima"
		&"quick_recovery":
			return "Base 90 de Brasa · Rango I 75 · Rango II 60"
		&"ashen_renewal":
			return "Rango I +3 de Defensa · Rango II +5 de Defensa"
		_:
			return "Progresión desconocida"

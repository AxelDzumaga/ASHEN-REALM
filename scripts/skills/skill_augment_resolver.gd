class_name SkillAugmentResolver
extends RefCounted


static func effective_energy_cost(skill: ActiveSkillData, run: RunState) -> int:
	var reduction: int = 0
	if skill.id == ActiveSkillCatalog.EMBER_SLASH.id:
		reduction = run.get_skill_augment_count(&"ember_efficiency") * 15
	elif skill.id == ActiveSkillCatalog.SECOND_WIND.id:
		reduction = run.get_skill_augment_count(&"quick_recovery") * 15
	return maxi(0, skill.energy_cost - reduction)


static func effective_damage_multiplier(skill: ActiveSkillData, run: RunState) -> float:
	return skill.damage_multiplier + float(run.get_skill_augment_count(&"searing_edge")) * 0.2


static func execution_multiplier(run: RunState, enemy_health: int, enemy_max_health: int) -> float:
	if run.get_skill_augment_count(&"executioners_ember") <= 0:
		return 1.0
	return 1.35 if enemy_health * 100 <= enemy_max_health * 25 else 1.0


static func effective_guard_reduction(skill: ActiveSkillData, run: RunState) -> float:
	return minf(0.80, skill.damage_reduction + float(run.get_skill_augment_count(&"reinforced_ash")) * 0.05)


static func stored_embers_energy(run: RunState) -> int:
	var stacks: int = run.get_skill_augment_count(&"stored_embers")
	return 0 if stacks <= 0 else (15 if stacks == 1 else 25)


static func counter_guard_damage(run: RunState) -> int:
	var stacks: int = run.get_skill_augment_count(&"counter_guard")
	return 0 if stacks <= 0 else (8 if stacks == 1 else 14)


static func effective_heal_percent(skill: ActiveSkillData, run: RunState) -> float:
	return minf(0.40, skill.heal_percent + float(run.get_skill_augment_count(&"deep_breath")) * 0.05)


static func renewal_defense(run: RunState) -> int:
	var stacks: int = run.get_skill_augment_count(&"ashen_renewal")
	return 0 if stacks <= 0 else (3 if stacks == 1 else 5)


static func effective_summary(skill: ActiveSkillData, run: RunState) -> String:
	match skill.skill_type:
		ActiveSkillData.SkillType.DAMAGE:
			return "Daño: %d%% ATQ  ·  Brasa: %d  ·  Recarga: %d" % [
				roundi(effective_damage_multiplier(skill, run) * 100.0), effective_energy_cost(skill, run), skill.cooldown_turns,
			]
		ActiveSkillData.SkillType.DEFENSE:
			return "Guardia: %d%% de reducción  ·  Brasa: %d  ·  Recarga: %d" % [
				roundi(effective_guard_reduction(skill, run) * 100.0), effective_energy_cost(skill, run), skill.cooldown_turns,
			]
		_:
			return "Curación: %d%% de Vida máxima  ·  Brasa: %d  ·  Una vez por combate" % [
				roundi(effective_heal_percent(skill, run) * 100.0), effective_energy_cost(skill, run),
			]


static func list_for_skill(run: RunState, skill_id: StringName = &"") -> Array[String]:
	var lines: Array[String] = []
	var effective_skill_id: StringName = run.active_skill_id if skill_id.is_empty() else skill_id
	for augment: SkillAugmentData in SkillAugmentCatalog.get_for_skill(effective_skill_id):
		var count: int = run.get_skill_augment_count(augment.id)
		if count > 0:
			lines.append("%s %s" % [augment.display_name, roman(count)])
	return lines


static func describe_next(augment: SkillAugmentData, owned: int) -> String:
	var next: int = mini(owned + 1, augment.max_stacks)
	match augment.id:
		&"searing_edge":
			return "Multiplicador de daño: %.1fx → %.1fx" % [2.0 + owned * 0.2, 2.0 + next * 0.2]
		&"ember_efficiency":
			return "Costo de Brasa: %d → %d" % [100 - owned * 15, 100 - next * 15]
		&"quick_recovery":
			return "Costo de Brasa: %d → %d" % [90 - owned * 15, 90 - next * 15]
		&"executioners_ember":
			return "+35% de daño final con 25% de Vida enemiga o menos"
		&"reinforced_ash":
			return "Reducción de daño: %d%% → %d%%" % [70 + owned * 5, 70 + next * 5]
		&"stored_embers":
			return "Brasa tras bloquear un golpe: +%d → +%d" % [_stored_value(owned), _stored_value(next)]
		&"counter_guard":
			return "Daño de contraataque: %d → %d" % [_counter_value(owned), _counter_value(next)]
		&"deep_breath":
			return "Curación: %d%% → %d%% de Vida máxima" % [30 + owned * 5, 30 + next * 5]
		&"ashen_renewal":
			return "Defensa en combate tras curarte: +%d → +%d" % [_renewal_value(owned), _renewal_value(next)]
		_:
			return augment.description


static func roman(value: int) -> String:
	var numerals: Array[String] = ["", "I", "II"]
	return numerals[clampi(value, 0, 2)]


static func _stored_value(stacks: int) -> int:
	return 0 if stacks <= 0 else (15 if stacks == 1 else 25)


static func _counter_value(stacks: int) -> int:
	return 0 if stacks <= 0 else (8 if stacks == 1 else 14)


static func _renewal_value(stacks: int) -> int:
	return 0 if stacks <= 0 else (3 if stacks == 1 else 5)

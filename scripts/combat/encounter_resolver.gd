class_name EncounterResolver
extends RefCounted

## Combat Domain M5 — deriva de CombatRules.MAX_TEAM_SIZE.
const MAX_ENEMIES: int = CombatRules.MAX_TEAM_SIZE
const MIN_BUDGET: int = 3
const MAX_BUDGET: int = 8
const EMBER_SPAWN_ID: StringName = &"ember_spawn"
const RNG_SALT: int = 0x48EC02


static func build_normal(biome: BiomeData, run: RunState) -> EncounterInstance:
	if biome == null or run == null:
		return null
	var pool: Array[EnemyData] = []
	for enemy: EnemyData in EnemySpawnResolver.get_pool(biome):
		if enemy != null and enemy.id != EMBER_SPAWN_ID and enemy.encounter_cost > 0:
			pool.append(enemy)
	if pool.is_empty():
		return null
	var progress_percent: int = _progress_percent(run, biome)
	var budget: int = _budget_for_progress(progress_percent)
	var plans: Array[EncounterInstance] = []
	for template: EncounterTemplateData in EncounterCatalog.get_all():
		if template != null and template.is_eligible(biome.id, progress_percent, budget):
			plans.append_array(_build_template_plans(template, pool, budget, progress_percent))
	if plans.is_empty():
		return null
	var alternatives: Array[EncounterInstance] = []
	for plan: EncounterInstance in plans:
		if plan.signature != run.last_normal_encounter_signature:
			alternatives.append(plan)
	if not alternatives.is_empty():
		plans = alternatives
	var chosen: EncounterInstance = _weighted_pick(plans, budget, _local_rng(run, biome), biome)
	if chosen != null:
		run.last_normal_encounter_signature = chosen.signature
	return chosen


static func _build_template_plans(
	template: EncounterTemplateData,
	pool: Array[EnemyData],
	budget: int,
	progress_percent: int,
) -> Array[EncounterInstance]:
	var result: Array[EncounterInstance] = []
	var empty_composition: Array[EnemyData] = []
	_append_compositions(template, pool, budget, progress_percent, 0, empty_composition, 0, result)
	var unique_result: Array[EncounterInstance] = []
	var seen_signatures: Array[StringName] = []
	for plan: EncounterInstance in result:
		if plan.signature in seen_signatures:
			continue
		seen_signatures.append(plan.signature)
		unique_result.append(plan)
	return unique_result


static func _append_compositions(
	template: EncounterTemplateData,
	pool: Array[EnemyData],
	budget: int,
	progress_percent: int,
	role_index: int,
	current: Array[EnemyData],
	current_cost: int,
	result: Array[EncounterInstance],
) -> void:
	if role_index >= template.roles.size():
		if _is_fair(current, progress_percent):
			var plan: EncounterInstance = EncounterInstance.new()
			plan.template = template
			plan.enemies = current.duplicate()
			plan.total_cost = current_cost
			plan.progress_percent = progress_percent
			plan.refresh_signature()
			result.append(plan)
		return
	var required_role: int = template.roles[role_index]
	for candidate: EnemyData in pool:
		if candidate.ai_profile == null or candidate.ai_profile.role != required_role:
			continue
		if template.duplicate_policy == EncounterTemplateData.DuplicatePolicy.DISALLOW and candidate in current:
			continue
		var next_cost: int = current_cost + candidate.encounter_cost
		if next_cost > budget:
			continue
		var next: Array[EnemyData] = current.duplicate()
		next.append(candidate)
		_append_compositions(template, pool, budget, progress_percent, role_index + 1, next, next_cost, result)


static func _is_fair(enemies: Array[EnemyData], progress_percent: int) -> bool:
	if enemies.is_empty() or enemies.size() > MAX_ENEMIES:
		return false
	if enemies.size() >= 3 and progress_percent < 65:
		return false
	var support_count: int = 0
	var disruptive_count: int = 0
	var companion_hunter_count: int = 0
	for enemy: EnemyData in enemies:
		if enemy.ai_profile == null:
			return false
		if enemy.ai_profile.role == EnemyAIEnums.Role.SUPPORT:
			support_count += 1
		if enemy.ai_profile.default_target_policy == EnemyAIEnums.TargetPolicy.COMPANION_PREFERRED:
			companion_hunter_count += 1
		if _has_disruptive_action(enemy.ai_profile):
			disruptive_count += 1
	if support_count > 1:
		return false
	if companion_hunter_count > 1:
		return false
	if progress_percent < 45 and disruptive_count > 1:
		return false
	if progress_percent < 70 and companion_hunter_count > 0 and support_count > 0:
		return false
	return true


static func _has_disruptive_action(profile: EnemyAIData) -> bool:
	for action: EnemyActionData in profile.actions:
		if action != null and action.status_id in [&"weaken", &"armor_break"]:
			return true
	return false


static func _weighted_pick(
	plans: Array[EncounterInstance],
	budget: int,
	rng: RandomNumberGenerator,
	biome: BiomeData,
) -> EncounterInstance:
	var total_weight: int = 0
	var weights: Array[int] = []
	for plan: EncounterInstance in plans:
		var closeness: int = maxi(1, 4 - absi(budget - plan.total_cost))
		var plan_weight: int = maxi(1, plan.template.weight * closeness)
		for enemy: EnemyData in plan.enemies:
			plan_weight *= EnemySpawnResolver.get_enemy_weight(biome, enemy)
		weights.append(plan_weight)
		total_weight += plan_weight
	var roll: int = rng.randi_range(1, total_weight)
	for index: int in range(plans.size()):
		roll -= weights[index]
		if roll <= 0:
			return plans[index]
	return plans.back()


static func _progress_percent(run: RunState, biome: BiomeData) -> int:
	var final_position: int = maxi(1, biome.board_length - 1)
	return clampi(roundi(float(run.board_position) * 100.0 / float(final_position)), 0, 100)


static func _budget_for_progress(progress_percent: int) -> int:
	return clampi(MIN_BUDGET + floori(float(progress_percent) * 5.0 / 100.0), MIN_BUDGET, MAX_BUDGET)


static func _local_rng(run: RunState, biome: BiomeData) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var biome_mix: int = String(biome.id).hash()
	var position_mix: int = (run.board_position + 1) * 104729
	rng.seed = absi(run.board_seed ^ biome_mix ^ position_mix ^ RNG_SALT)
	return rng

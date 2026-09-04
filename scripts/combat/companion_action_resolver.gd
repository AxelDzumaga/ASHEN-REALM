class_name CompanionActionResolver
extends RefCounted

class ActionPlan:
	extends RefCounted
	var target: CombatActor
	var damage: int = 0
	var uses_ability: bool = false
	var passive_triggered: bool = false


static func choose_target(selected_target: CombatActor, enemies: Array[CombatActor]) -> CombatActor:
	if _is_valid_enemy(selected_target, enemies):
		return selected_target
	for enemy: CombatActor in enemies:
		if _is_valid_enemy(enemy, enemies):
			return enemy
	return null


static func build_plan(
	companion_actor: CombatActor,
	companion_data: CompanionData,
	runtime_state: CompanionRuntimeState,
	selected_target: CombatActor,
	enemies: Array[CombatActor],
	statuses: CombatStatusController,
	target_defense_bonus: int = 0,
) -> ActionPlan:
	var plan: ActionPlan = ActionPlan.new()
	plan.target = choose_target(selected_target, enemies)
	if companion_actor == null or companion_data == null or runtime_state == null or statuses == null or plan.target == null:
		return plan
	plan.uses_ability = runtime_state.is_ability_ready(companion_data)
	var effective_attack: int = statuses.get_effective_attack(companion_actor, companion_actor.get_attack())
	var effective_defense: int = statuses.get_effective_defense(
		plan.target,
		plan.target.get_defense() + maxi(0, target_defense_bonus),
	)
	plan.damage = CombatMath.calculate_damage(effective_attack, effective_defense)
	plan.passive_triggered = (
		companion_data.passive_id == &"ember_hunter"
		and plan.target.has_status(&"burn")
		and companion_data.passive_damage_multiplier > 1.0
	)
	if plan.passive_triggered:
		plan.damage = maxi(1, roundi(float(plan.damage) * companion_data.passive_damage_multiplier))
	return plan


static func _is_valid_enemy(candidate: CombatActor, enemies: Array[CombatActor]) -> bool:
	return (
		candidate != null
		and candidate.team == CombatActor.Team.ENEMY
		and candidate.is_targetable()
		and candidate in enemies
	)

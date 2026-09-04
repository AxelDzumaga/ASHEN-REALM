class_name EnemyIntentPlanner
extends RefCounted


static func plan(
	attacker: CombatActor,
	profile: EnemyAIData,
	runtime: EnemyAIRuntimeState,
	alive_targets: Array[CombatActor],
	rng: RandomNumberGenerator,
	plan_sequence: int,
	forced_action: EnemyActionData = null,
	excluded_action_ids: Array[StringName] = [],
) -> EnemyIntent:
	if attacker == null or not attacker.is_alive() or profile == null or runtime == null or rng == null:
		return null
	var decision: EnemyActionResolver.Decision = EnemyActionResolver.Decision.new()
	if forced_action != null:
		decision.action = forced_action
		decision.target = attacker
	else:
		decision = EnemyActionResolver.choose_for_plan(
			attacker, profile, runtime, alive_targets, rng, excluded_action_ids,
		)
	if decision.action == null:
		return null
	var intent: EnemyIntent = EnemyIntent.new()
	intent.action = decision.action
	intent.action_id = decision.action.action_id
	intent.action_type = decision.action.action_type
	intent.source_actor = attacker
	intent.target_actor = decision.target
	intent.target_policy = profile.default_target_policy
	if decision.action.override_target_policy:
		intent.target_policy = decision.action.target_policy
	intent.category = _resolve_category(decision.action)
	intent.estimated_power = decision.action.power_multiplier
	intent.status_effect = decision.action.status_id
	intent.status_stacks = decision.action.status_stacks
	intent.defense_amount = decision.action.defense_bonus
	intent.source_role = profile.role
	intent.planned_turn = runtime.turn_count + 1
	intent.plan_id = StringName("%s:%d:%s:%d" % [
		attacker.actor_id, intent.planned_turn, intent.action_id, plan_sequence,
	])
	return intent


static func _resolve_category(action: EnemyActionData) -> EnemyIntent.Category:
	if action == null:
		return EnemyIntent.Category.SPECIAL
	if action.action_id == &"warden_rebuke":
		return EnemyIntent.Category.SPECIAL
	match action.action_type:
		EnemyAIEnums.ActionType.ATTACK:
			return EnemyIntent.Category.ATTACK
		EnemyAIEnums.ActionType.ATTACK_STATUS:
			return EnemyIntent.Category.STATUS
		EnemyAIEnums.ActionType.SELF_BUFF:
			return EnemyIntent.Category.DEFEND
		EnemyAIEnums.ActionType.SUMMON:
			return EnemyIntent.Category.SUMMON
		_:
			return EnemyIntent.Category.SPECIAL

class_name EnemyActionResolver
extends RefCounted

class Decision:
	extends RefCounted
	var action: EnemyActionData
	var target: CombatActor


static func choose(
	attacker: CombatActor,
	profile: EnemyAIData,
	runtime: EnemyAIRuntimeState,
	alive_players: Array[CombatActor],
	rng: RandomNumberGenerator,
	excluded_action_ids: Array[StringName] = [],
) -> Decision:
	return _choose(attacker, profile, runtime, alive_players, rng, excluded_action_ids, false)


static func choose_for_plan(
	attacker: CombatActor,
	profile: EnemyAIData,
	runtime: EnemyAIRuntimeState,
	alive_players: Array[CombatActor],
	rng: RandomNumberGenerator,
	excluded_action_ids: Array[StringName] = [],
) -> Decision:
	return _choose(attacker, profile, runtime, alive_players, rng, excluded_action_ids, true)


static func _choose(
	attacker: CombatActor,
	profile: EnemyAIData,
	runtime: EnemyAIRuntimeState,
	alive_players: Array[CombatActor],
	rng: RandomNumberGenerator,
	excluded_action_ids: Array[StringName],
	for_plan: bool,
) -> Decision:
	var decision: Decision = Decision.new()
	if attacker == null or not attacker.is_alive() or profile == null or runtime == null or rng == null:
		return decision
	var valid_actions: Array[EnemyActionData] = []
	var total_weight: int = 0
	for candidate: EnemyActionData in profile.actions:
		var action_available: bool = runtime.can_plan_action(candidate) if for_plan else runtime.can_use_action(candidate)
		if candidate == null or candidate.action_id in excluded_action_ids or not action_available:
			continue
		if candidate.action_type != EnemyAIEnums.ActionType.SELF_BUFF and alive_players.is_empty():
			continue
		valid_actions.append(candidate)
		total_weight += candidate.weight
	if valid_actions.is_empty() or total_weight <= 0:
		return decision
	var roll: int = rng.randi_range(1, total_weight)
	var accumulated: int = 0
	for candidate: EnemyActionData in valid_actions:
		accumulated += candidate.weight
		if roll <= accumulated:
			decision.action = candidate
			break
	if decision.action == null:
		decision.action = valid_actions[valid_actions.size() - 1]
	if decision.action.action_type == EnemyAIEnums.ActionType.SELF_BUFF:
		decision.target = attacker
		return decision
	var policy: EnemyAIEnums.TargetPolicy = profile.default_target_policy
	if decision.action.override_target_policy:
		policy = decision.action.target_policy
	decision.target = choose_target(policy, alive_players, rng)
	return decision


static func choose_target(
	policy: EnemyAIEnums.TargetPolicy,
	alive_players: Array[CombatActor],
	rng: RandomNumberGenerator,
) -> CombatActor:
	if alive_players.is_empty():
		return null
	match policy:
		EnemyAIEnums.TargetPolicy.LOWEST_HP:
			return _lowest_health_ratio(alive_players)
		EnemyAIEnums.TargetPolicy.RANDOM_ALIVE:
			return alive_players[rng.randi_range(0, alive_players.size() - 1)]
		EnemyAIEnums.TargetPolicy.COMPANION_PREFERRED:
			for actor: CombatActor in alive_players:
				if actor.actor_type == CombatActor.ActorType.COMPANION:
					return actor
			return _primary_player(alive_players)
		_:
			return _primary_player(alive_players)


static func _primary_player(alive_players: Array[CombatActor]) -> CombatActor:
	for actor: CombatActor in alive_players:
		if actor.actor_type == CombatActor.ActorType.PLAYER:
			return actor
	return alive_players[0] if not alive_players.is_empty() else null


static func _lowest_health_ratio(alive_players: Array[CombatActor]) -> CombatActor:
	var chosen: CombatActor = alive_players[0]
	var chosen_ratio: float = float(chosen.get_current_hp()) / float(chosen.get_max_hp())
	for actor: CombatActor in alive_players:
		var ratio: float = float(actor.get_current_hp()) / float(actor.get_max_hp())
		if ratio < chosen_ratio or (is_equal_approx(ratio, chosen_ratio) and actor.formation_slot < chosen.formation_slot):
			chosen = actor
			chosen_ratio = ratio
	return chosen

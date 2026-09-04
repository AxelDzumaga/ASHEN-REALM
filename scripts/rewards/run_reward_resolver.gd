class_name RunRewardResolver
extends RefCounted

enum Type { UPGRADE, SKILL_AUGMENT }

const NORMAL_AUGMENT_CHANCE: float = 0.25
const ELITE_AUGMENT_CHANCE: float = 0.50


static func choose(is_elite: bool, run: RunState) -> Type:
	if SkillAugmentCatalog.get_eligible_for_run(run).is_empty():
		return Type.UPGRADE
	if DebugConfig.DEBUG_TOOLS_ENABLED and DebugConfig.DEBUG_FORCE_NEXT_REWARD_TYPE >= 0:
		return Type.SKILL_AUGMENT if DebugConfig.DEBUG_FORCE_NEXT_REWARD_TYPE == Type.SKILL_AUGMENT else Type.UPGRADE
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = run.next_reward_offer_seed(&"reward_type_elite" if is_elite else &"reward_type_normal")
	var augment_chance: float = ELITE_AUGMENT_CHANCE if is_elite else NORMAL_AUGMENT_CHANCE
	return Type.SKILL_AUGMENT if rng.randf() < augment_chance else Type.UPGRADE

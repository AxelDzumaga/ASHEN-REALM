class_name BuildRewardResolver
extends RefCounted

## ETAPA 63: reglas deterministas y ligeras para ofertas de build.
## La afinidad inclina probabilidades; nunca garantiza una opción concreta.

const OPTION_COUNT: int = 3
const NORMAL_COMMON_CHANCE: float = 0.65
const NORMAL_RARE_CHANCE: float = 0.30
const ELITE_COMMON_CHANCE: float = 0.30
const ELITE_RARE_CHANCE: float = 0.50
const AFFINITY_MULTIPLIER_PER_STACK: float = 0.35
const AFFINITY_MULTIPLIER_CAP: float = 2.05
const SYNERGY_COMPLETION_MULTIPLIER: float = 1.80
const SAME_AFFINITY_SECOND_SLOT_MULTIPLIER: float = 0.62

enum OfferQuality { OFF_BUILD, NEUTRAL, ON_BUILD, SYNERGY_COMPLETING }


static func make_seed(run: RunState, context: StringName, sequence: int) -> int:
	if run == null:
		return absi(hash(String(context)) ^ sequence ^ 0x63B17D)
	return absi(run.board_seed ^ hash(String(context)) ^ (sequence * 104729) ^ 0x63B17D)


static func generate_boon_options(run: RunState, is_elite: bool, seed: int, previous_signature: String = "", audit: Dictionary = {}, rarity_mode: StringName = &"renormalized") -> Array[UpgradeData]:
	var pool: Array[UpgradeData] = []
	for boon: UpgradeData in UpgradeCatalog.get_boons():
		if run == null or run.get_boon_count(boon.id) < boon.max_stacks:
			pool.append(boon)
	if pool.size() < OPTION_COUNT:
		return pool
	for attempt: int in range(16):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = absi(seed + attempt * 8191)
		var attempt_audit: Dictionary = {} if audit.is_empty() else {"rarity_rolls": {}, "fallbacks": 0}
		var result: Array[UpgradeData] = _generate_boon_set(run, is_elite, pool, rng, attempt_audit, rarity_mode)
		if previous_signature.is_empty() or signature(result) != previous_signature:
			if not audit.is_empty():
				audit.merge(attempt_audit, true)
			return result
	return _fallback_distinct(pool, previous_signature)


static func generate_level_options(run: RunState, seed: int) -> Array[UpgradeData]:
	var pool: Array[UpgradeData] = RunLevelConfig.get_level_up_pool(run)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	return _weighted_diverse_upgrades(run, pool, rng, mini(OPTION_COUNT, pool.size()), false)


static func generate_augment_options(run: RunState, seed: int) -> Array[SkillAugmentData]:
	var pool: Array[SkillAugmentData] = SkillAugmentCatalog.get_eligible_for_run(run)
	var result: Array[SkillAugmentData] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	while not pool.is_empty() and result.size() < OPTION_COUNT:
		var weights: Array[float] = []
		for augment: SkillAugmentData in pool:
			var weight: float = 1.0
			var related: int = _related_tag_count(run, augment.tags)
			weight *= minf(AFFINITY_MULTIPLIER_CAP, 1.0 + related * 0.14)
			if run != null and augment.skill_id == MetaUnlockCatalog.get_skill_id(run.starting_option_id):
				weight *= 1.35
			if not result.is_empty() and augment.skill_id == result[0].skill_id:
				weight *= SAME_AFFINITY_SECOND_SLOT_MULTIPLIER
			weights.append(weight)
		var index: int = _weighted_index(weights, rng)
		result.append(pool[index])
		pool.remove_at(index)
	return result


static func generate_boss_options(run: RunState, seed: int, count: int = OPTION_COUNT) -> Array[BossRewardData]:
	var pool: Array[BossRewardData] = BossRewardCatalog.get_all()
	var result: Array[BossRewardData] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	while not pool.is_empty() and result.size() < count:
		var index: int = rng.randi_range(0, pool.size() - 1)
		result.append(pool[index])
		pool.remove_at(index)
	return result


static func classify_boon(run: RunState, boon: UpgradeData) -> OfferQuality:
	if run == null or boon == null:
		return OfferQuality.NEUTRAL
	if not SynergyResolver.get_activated_by_boon(run, boon.id).is_empty():
		return OfferQuality.SYNERGY_COMPLETING
	var affinity_count: int = run.get_affinity_count(boon.affinity)
	if boon.affinity != UpgradeData.Affinity.NONE and affinity_count > 0:
		return OfferQuality.ON_BUILD
	var dominant: int = _dominant_affinity(run)
	if dominant != UpgradeData.Affinity.NONE and boon.affinity != dominant:
		return OfferQuality.OFF_BUILD
	return OfferQuality.NEUTRAL


static func signature(options: Array[UpgradeData]) -> String:
	var ids: Array[String] = []
	for upgrade: UpgradeData in options:
		ids.append(String(upgrade.id))
	ids.sort()
	return "|".join(ids)


static func _generate_boon_set(run: RunState, is_elite: bool, pool: Array[UpgradeData], rng: RandomNumberGenerator, audit: Dictionary = {}, rarity_mode: StringName = &"renormalized") -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	while result.size() < OPTION_COUNT:
		var rarity: int = _roll_rarity(is_elite, rng, rarity_mode)
		if not audit.is_empty():
			var rarity_key: String = str(rarity)
			audit["rarity_rolls"][rarity_key] = int(audit["rarity_rolls"].get(rarity_key, 0)) + 1
		var rarity_pool: Array[UpgradeData] = []
		for boon: UpgradeData in pool:
			if boon not in result and boon.rarity == rarity:
				rarity_pool.append(boon)
		if rarity_pool.is_empty():
			if not audit.is_empty():
				audit["fallbacks"] = int(audit.get("fallbacks", 0)) + 1
			for boon: UpgradeData in pool:
				if boon not in result:
					rarity_pool.append(boon)
		var chosen: UpgradeData = _pick_weighted_upgrade(run, rarity_pool, result, rng)
		if chosen == null:
			break
		result.append(chosen)
	return result


static func _weighted_diverse_upgrades(run: RunState, pool: Array[UpgradeData], rng: RandomNumberGenerator, count: int, use_synergy: bool) -> Array[UpgradeData]:
	var remaining: Array[UpgradeData] = pool.duplicate()
	var result: Array[UpgradeData] = []
	while not remaining.is_empty() and result.size() < count:
		var weights: Array[float] = []
		for upgrade: UpgradeData in remaining:
			var weight: float = _upgrade_weight(run, upgrade, result, use_synergy)
			weights.append(weight)
		var index: int = _weighted_index(weights, rng)
		result.append(remaining[index])
		remaining.remove_at(index)
	return result


static func _pick_weighted_upgrade(run: RunState, candidates: Array[UpgradeData], selected: Array[UpgradeData], rng: RandomNumberGenerator) -> UpgradeData:
	if candidates.is_empty():
		return null
	var weights: Array[float] = []
	for boon: UpgradeData in candidates:
		weights.append(_upgrade_weight(run, boon, selected, true))
	return candidates[_weighted_index(weights, rng)]


static func _upgrade_weight(run: RunState, upgrade: UpgradeData, selected: Array[UpgradeData], use_synergy: bool) -> float:
	var weight: float = 1.0
	if run != null and upgrade.affinity != UpgradeData.Affinity.NONE:
		var affinity_count: int = run.get_reward_affinity_count(upgrade.affinity)
		weight *= minf(AFFINITY_MULTIPLIER_CAP, 1.0 + affinity_count * AFFINITY_MULTIPLIER_PER_STACK)
		if use_synergy and not SynergyResolver.get_activated_by_boon(run, upgrade.id).is_empty():
			weight *= SYNERGY_COMPLETION_MULTIPLIER
	if selected.size() >= 2 and selected[0].affinity == selected[1].affinity and upgrade.affinity == selected[0].affinity:
		weight *= SAME_AFFINITY_SECOND_SLOT_MULTIPLIER
	return maxf(0.05, weight)


static func _roll_rarity(is_elite: bool, rng: RandomNumberGenerator, rarity_mode: StringName = &"renormalized") -> int:
	var roll: float = rng.randf()
	if rarity_mode == &"renormalized":
		var rare_chance: float = ELITE_RARE_CHANCE / (1.0 - ELITE_COMMON_CHANCE) if is_elite else NORMAL_RARE_CHANCE / (1.0 - NORMAL_COMMON_CHANCE)
		return UpgradeData.UpgradeRarity.RARE if roll < rare_chance else UpgradeData.UpgradeRarity.EPIC
	if is_elite:
		return UpgradeData.UpgradeRarity.COMMON if roll < ELITE_COMMON_CHANCE else (UpgradeData.UpgradeRarity.RARE if roll < ELITE_COMMON_CHANCE + ELITE_RARE_CHANCE else UpgradeData.UpgradeRarity.EPIC)
	return UpgradeData.UpgradeRarity.COMMON if roll < NORMAL_COMMON_CHANCE else (UpgradeData.UpgradeRarity.RARE if roll < NORMAL_COMMON_CHANCE + NORMAL_RARE_CHANCE else UpgradeData.UpgradeRarity.EPIC)


static func _weighted_index(weights: Array[float], rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for weight: float in weights:
		total += maxf(0.0, weight)
	if total <= 0.0:
		return rng.randi_range(0, weights.size() - 1)
	var roll: float = rng.randf() * total
	for index: int in range(weights.size()):
		roll -= maxf(0.0, weights[index])
		if roll <= 0.0:
			return index
	return weights.size() - 1


static func _dominant_affinity(run: RunState) -> int:
	var best: int = UpgradeData.Affinity.NONE
	var best_count: int = 0
	for affinity: int in [UpgradeData.Affinity.OFFENSE, UpgradeData.Affinity.DEFENSE, UpgradeData.Affinity.SUSTAIN]:
		var count: int = run.get_affinity_count(affinity)
		if count > best_count:
			best = affinity
			best_count = count
	return best


static func _related_tag_count(run: RunState, tags: Array[StringName]) -> int:
	if run == null:
		return 0
	var report: BuildTagReport = BuildTagResolver.resolve(run)
	var total: int = 0
	for tag: StringName in tags:
		if report.get_count(tag) > 0:
			total += 1
	return total


static func _fallback_distinct(pool: Array[UpgradeData], previous_signature: String) -> Array[UpgradeData]:
	for first: int in range(pool.size() - 2):
		for second: int in range(first + 1, pool.size() - 1):
			for third: int in range(second + 1, pool.size()):
				var candidate: Array[UpgradeData] = [pool[first], pool[second], pool[third]]
				if signature(candidate) != previous_signature:
					return candidate
	return []

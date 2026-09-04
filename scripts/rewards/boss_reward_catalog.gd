class_name BossRewardCatalog
extends RefCounted

const ASHEN_BOUNTY: BossRewardData = preload("res://data/boss_rewards/ashen_bounty.tres")
const SPOILS_OF_THE_WARDEN: BossRewardData = preload("res://data/boss_rewards/spoils_of_the_warden.tres")
const EMBER_CACHE: BossRewardData = preload("res://data/boss_rewards/ember_cache.tres")
const PYRES_FAVOR: BossRewardData = preload("res://data/boss_rewards/pyres_favor.tres")

const ALL: Array[BossRewardData] = [
	ASHEN_BOUNTY,
	SPOILS_OF_THE_WARDEN,
	EMBER_CACHE,
	PYRES_FAVOR,
]


static func get_all() -> Array[BossRewardData]:
	return ALL.duplicate()


static func get_by_id(reward_id: StringName) -> BossRewardData:
	for reward: BossRewardData in ALL:
		if reward.id == reward_id:
			return reward
	return null


static func apply(reward: BossRewardData, run: RunState) -> bool:
	if reward == null or run.boss_reward_applied:
		return false
	match reward.id:
		&"ashen_bounty":
			run.run_ash += 55
		&"spoils_of_the_warden":
			run.run_ash += 30
			run.loot_minimum_rarity = EquipmentData.Rarity.RARE
		&"ember_cache":
			run.run_ash += 15
			run.loot_rarity_upgrades = 1
		&"pyres_favor":
			run.loot_minimum_rarity = EquipmentData.Rarity.EPIC
		_:
			return false
	run.boss_reward_id = reward.id
	run.boss_reward_applied = true
	return true


static func get_result_effect(reward_id: StringName, final_loot: EquipmentData) -> String:
	match reward_id:
		&"ashen_bounty":
			return "+55 de Ceniza"
		&"spoils_of_the_warden":
			return "+30 de Ceniza · Botín garantizado Raro o superior"
		&"ember_cache":
			return "+15 de Ceniza · Botín mejorado a %s" % (EquipmentCatalog.get_rarity_name(final_loot.rarity) if final_loot != null else "una rareza superior")
		&"pyres_favor":
			return "Botín garantizado Épico"
		_:
			return ""

class_name UpgradeCatalog
extends RefCounted

const VITAL_EMBER: UpgradeData = preload("res://data/upgrades/vital_ember.tres")
const SHARPENED_EDGE: UpgradeData = preload("res://data/upgrades/sharpened_edge.tres")
const IRON_SKIN: UpgradeData = preload("res://data/upgrades/iron_skin.tres")
const RESTORATIVE_SPARK: UpgradeData = preload("res://data/upgrades/restorative_spark.tres")
const BURNING_RESOLVE: UpgradeData = preload("res://data/upgrades/burning_resolve.tres")
const ASHEN_HEART: UpgradeData = preload("res://data/upgrades/ashen_heart.tres")
const BURNING_STRIKE: UpgradeData = preload("res://data/upgrades/boons/burning_strike.tres")
const ASHEN_BULWARK: UpgradeData = preload("res://data/upgrades/boons/ashen_bulwark.tres")
const EMBER_BLOOD: UpgradeData = preload("res://data/upgrades/boons/ember_blood.tres")
const LAST_EMBER: UpgradeData = preload("res://data/upgrades/boons/last_ember.tres")
const CINDER_SKIN: UpgradeData = preload("res://data/upgrades/boons/cinder_skin.tres")
const RELENTLESS_FLAME: UpgradeData = preload("res://data/upgrades/boons/relentless_flame.tres")
const ASHEN_REPRISAL: UpgradeData = preload("res://data/upgrades/boons/ashen_reprisal.tres")
const PYRE_HEART: UpgradeData = preload("res://data/upgrades/boons/pyre_heart.tres")

const ALL: Array[UpgradeData] = [
	VITAL_EMBER,
	SHARPENED_EDGE,
	IRON_SKIN,
	RESTORATIVE_SPARK,
	BURNING_RESOLVE,
	ASHEN_HEART,
	BURNING_STRIKE,
	ASHEN_BULWARK,
	EMBER_BLOOD,
	LAST_EMBER,
	CINDER_SKIN,
	RELENTLESS_FLAME,
	ASHEN_REPRISAL,
	PYRE_HEART,
]


static func get_all() -> Array[UpgradeData]:
	return ALL.duplicate()


static func get_stat_upgrades() -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	for upgrade: UpgradeData in ALL:
		if upgrade.category == UpgradeData.Category.STAT:
			result.append(upgrade)
	return result


static func get_boons() -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	for upgrade: UpgradeData in ALL:
		if upgrade.category == UpgradeData.Category.PASSIVE:
			result.append(upgrade)
	return result


static func get_by_id(upgrade_id: StringName) -> UpgradeData:
	for upgrade: UpgradeData in ALL:
		if upgrade.id == upgrade_id:
			return upgrade
	return null


static func get_by_rarity(rarity: int) -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	for upgrade: UpgradeData in ALL:
		if upgrade.rarity == rarity:
			result.append(upgrade)
	return result


static func get_rarity_name(rarity: int) -> String:
	return ["COMÚN", "RARO", "ÉPICO"][rarity]


static func get_rarity_color(rarity: int) -> Color:
	return [VisualTheme.COMMON, VisualTheme.RARE, VisualTheme.EPIC][rarity]


static func get_affinity_name(affinity: UpgradeData.Affinity) -> String:
	match affinity:
		UpgradeData.Affinity.OFFENSE:
			return "OFENSIVA"
		UpgradeData.Affinity.DEFENSE:
			return "DEFENSIVA"
		UpgradeData.Affinity.SUSTAIN:
			return "SOSTÉN"
		_:
			return "MEJORA"

class_name SynergyCatalog
extends RefCounted

const INFERNO_RHYTHM: SynergyData = preload("res://data/synergies/inferno_rhythm.tres")
const ASHEN_VENGEANCE: SynergyData = preload("res://data/synergies/ashen_vengeance.tres")
const LAST_STAND: SynergyData = preload("res://data/synergies/last_stand.tres")
const PHOENIX_BLOOD: SynergyData = preload("res://data/synergies/phoenix_blood.tres")
const CINDER_PRECISION: SynergyData = preload("res://data/synergies/cinder_precision.tres")
const IRON_VIGIL: SynergyData = preload("res://data/synergies/iron_vigil.tres")
const MIRE_BLOOM: SynergyData = preload("res://data/synergies/mire_bloom.tres")
const RUNIC_FLOW: SynergyData = preload("res://data/synergies/runic_flow.tres")

const ALL: Array[SynergyData] = [
	INFERNO_RHYTHM,
	ASHEN_VENGEANCE,
	LAST_STAND,
	PHOENIX_BLOOD,
	CINDER_PRECISION,
	IRON_VIGIL,
	MIRE_BLOOM,
	RUNIC_FLOW,
]


static func get_all() -> Array[SynergyData]:
	return ALL.duplicate()


static func get_by_id(synergy_id: StringName) -> SynergyData:
	for synergy: SynergyData in ALL:
		if synergy.synergy_id == synergy_id:
			return synergy
	return null

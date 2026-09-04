class_name BoonSynergyResolver
extends RefCounted

# Compatibility facade: historical callers keep this public API while the
# source of truth is the data-driven SynergyCatalog/SynergyResolver pair.
const INFERNO_RHYTHM := &"inferno_rhythm"
const ASHEN_VENGEANCE := &"ashen_vengeance"
const LAST_STAND := &"last_stand"
const PHOENIX_BLOOD := &"phoenix_blood"
const CINDER_PRECISION := &"cinder_precision"
const IRON_VIGIL := &"iron_vigil"
const MIRE_BLOOM := &"mire_bloom"
const RUNIC_FLOW := &"runic_flow"

const ALL: Array[StringName] = [
	INFERNO_RHYTHM, ASHEN_VENGEANCE, LAST_STAND, PHOENIX_BLOOD,
	CINDER_PRECISION, IRON_VIGIL, MIRE_BLOOM, RUNIC_FLOW,
]


static func is_active(synergy_id: StringName, run: RunState) -> bool:
	return SynergyResolver.is_active(synergy_id, run)


static func get_active_ids(run: RunState) -> Array[StringName]:
	var result: Array[StringName] = []
	if run != null:
		result = run.active_synergy_ids.duplicate()
	return result


static func get_completed_by(run: RunState, offered_boon_id: StringName) -> Array[StringName]:
	return SynergyResolver.get_activated_by_boon(run, offered_boon_id)


static func get_display_name(synergy_id: StringName) -> String:
	var synergy: SynergyData = SynergyCatalog.get_by_id(synergy_id)
	return "SINERGIA DESCONOCIDA" if synergy == null else synergy.display_name


static func get_requirements_text(synergy_id: StringName) -> String:
	var synergy: SynergyData = SynergyCatalog.get_by_id(synergy_id)
	return "Requisitos desconocidos" if synergy == null else synergy.requirements_text


static func get_required_boons(synergy_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var synergy: SynergyData = SynergyCatalog.get_by_id(synergy_id)
	if synergy == null:
		return result
	for source_id: StringName in synergy.required_source_ids:
		var source_text: String = String(source_id)
		if source_text.begins_with("boon:"):
			result.append(StringName(source_text.trim_prefix("boon:")))
	return result


static func get_description(synergy_id: StringName) -> String:
	var synergy: SynergyData = SynergyCatalog.get_by_id(synergy_id)
	return "Sinergia desconocida." if synergy == null else synergy.description


static func get_effect_text(synergy_id: StringName) -> String:
	var synergy: SynergyData = SynergyCatalog.get_by_id(synergy_id)
	return "Efecto desconocido." if synergy == null else synergy.effect_text

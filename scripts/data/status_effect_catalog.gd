class_name StatusEffectCatalog
extends RefCounted

const BURN: StatusEffectData = preload("res://data/status_effects/burn.tres")
const WEAKEN: StatusEffectData = preload("res://data/status_effects/weaken.tres")
const ARMOR_BREAK: StatusEffectData = preload("res://data/status_effects/armor_break.tres")
const REGEN: StatusEffectData = preload("res://data/status_effects/regen.tres")
const GUARD: StatusEffectData = preload("res://data/status_effects/guard.tres")
## Afinidades elementales Fase 1 — mismo mecanismo DOT que BURN (Brasa).
## WET (Marea) ya se asigna a enemigos de Ember Marsh; CHILLED (Escarcha) y
## SHOCK (Tormenta) quedan disponibles y funcionales, sin asignar a ningún
## bioma todavía. Ver scripts/combat/affinity_resolver.gd.
const WET: StatusEffectData = preload("res://data/status_effects/wet.tres")
const CHILLED: StatusEffectData = preload("res://data/status_effects/chilled.tres")
const SHOCK: StatusEffectData = preload("res://data/status_effects/shock.tres")
## Cierre de Fase 1: los dos elementos que solo tenían WEAK/RESIST en
## AffinityResolver (Miasma, Ceniza) ahora tienen su propio status. DECAY es
## DoT + reduce curación recibida (CombatStatusController.get_effective_healing).
## CURSE aumenta el daño recibido de cualquier fuente, no solo de tipo Ceniza
## (CombatStatusController.get_effective_incoming_damage). Sin asignar a
## ningún bioma todavía, mismo criterio que CHILLED/SHOCK.
const DECAY: StatusEffectData = preload("res://data/status_effects/decay.tres")
const CURSE: StatusEffectData = preload("res://data/status_effects/curse.tres")

const ALL: Array[StatusEffectData] = [BURN, WEAKEN, ARMOR_BREAK, REGEN, GUARD, WET, CHILLED, SHOCK, DECAY, CURSE]


static func get_all() -> Array[StatusEffectData]:
	return ALL.duplicate()


static func get_by_id(status_id: StringName) -> StatusEffectData:
	for status_data: StatusEffectData in ALL:
		if status_data.status_id == status_id:
			return status_data
	return null


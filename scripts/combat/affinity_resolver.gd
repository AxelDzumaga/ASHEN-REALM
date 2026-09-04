class_name AffinityResolver
extends RefCounted

## Conjunto inicial deliberadamente pequeño. Wireado al daño vivo desde
## combat.gd (_resolve_elemental_damage) — ver también get_effective_incoming_damage
## en CombatStatusController para el modificador de CURSE, que se aplica encima
## de esta resolución elemental.
const PHYSICAL: StringName = &"physical"
const EMBER: StringName = &"ember"
const TIDE: StringName = &"tide"
const ASH: StringName = &"ash"
const MIASMA: StringName = &"miasma"
## Afinidades elementales Fase 1 (Brasa/Marea ya asignadas a enemigos; Escarcha
## y Tormenta quedan definidas y disponibles, sin asignar a ningún bioma todavía).
const FROST: StringName = &"frost"
const STORM: StringName = &"storm"
const SUPPORTED_TYPES: Array[StringName] = [PHYSICAL, EMBER, TIDE, ASH, MIASMA, FROST, STORM]

const RESIST_PERCENT: int = 75
const WEAK_PERCENT: int = 125


static func sanitize_type(value: StringName) -> StringName:
	return value if value in SUPPORTED_TYPES else PHYSICAL


static func resolve_damage_preview(
	base_damage: int,
	damage_type: StringName,
	resistance_tags: Array[StringName],
	weakness_tags: Array[StringName],
	immunity_tags: Array[StringName],
) -> Dictionary:
	var safe_damage: int = maxi(0, base_damage)
	var safe_type: StringName = sanitize_type(damage_type)
	if safe_type in immunity_tags:
		return {"damage": 0, "relation": &"immune", "percent": 0}
	if safe_type in resistance_tags and safe_type not in weakness_tags:
		return {"damage": roundi(safe_damage * RESIST_PERCENT / 100.0), "relation": &"resists", "percent": RESIST_PERCENT}
	if safe_type in weakness_tags and safe_type not in resistance_tags:
		return {"damage": roundi(safe_damage * WEAK_PERCENT / 100.0), "relation": &"weak", "percent": WEAK_PERCENT}
	return {"damage": safe_damage, "relation": &"normal", "percent": 100}


static func preview_status_interaction(status_id: StringName, target_status_tags: Array[StringName]) -> Dictionary:
	# Demostración única y no activa: MOJADO reduce un turno de QUEMADURA,
	# sin modificar stacks ni introducir una matriz elemental.
	if status_id == &"burn" and &"wet" in target_status_tags:
		return {"rule_id": &"wet_reduces_burn_duration", "duration_delta": -1, "stack_delta": 0}
	return {"rule_id": &"none", "duration_delta": 0, "stack_delta": 0}


static func get_type_label(value: StringName) -> String:
	match sanitize_type(value):
		EMBER:
			return "BRASA"
		TIDE:
			return "MAREA"
		ASH:
			return "CENIZA"
		MIASMA:
			return "MIASMA"
		FROST:
			return "ESCARCHA"
		STORM:
			return "TORMENTA"
		_:
			return "FÍSICO"

class_name DamageEvent
extends RefCounted

## Combat Domain M4 — daño ya aplicado (amount viene de apply_damage(), que
## ya clampea a la vida real perdida — nunca se recalcula la fórmula acá).
## affinity_relation usa los valores de AffinityResolver (&"weak"/&"resists"/
## &"immune"/&"normal") cuando la afinidad efectivamente se evaluó para esta
## fuente de daño; queda "" (sin evaluar) para fuentes que hoy no pasan por
## _resolve_elemental_damage (skills, compañero — asimetría preexistente,
## documentada en el handoff M3, no introducida ni corregida acá).

var action_id: int
var source_actor: CombatActor
var target_actor: CombatActor
var amount: int
var hp_before: int
var hp_after: int
var is_critical: bool
var affinity_relation: StringName
var caused_death: bool


func _init(
	p_action_id: int,
	p_source_actor: CombatActor,
	p_target_actor: CombatActor,
	p_amount: int,
	p_hp_before: int,
	p_hp_after: int,
	p_is_critical: bool = false,
	p_affinity_relation: StringName = &"",
) -> void:
	action_id = p_action_id
	source_actor = p_source_actor
	target_actor = p_target_actor
	amount = p_amount
	hp_before = p_hp_before
	hp_after = p_hp_after
	is_critical = p_is_critical
	affinity_relation = p_affinity_relation
	caused_death = p_hp_before > 0 and p_hp_after <= 0

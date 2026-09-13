class_name HealEvent
extends RefCounted

## Combat Domain M4 — actual_amount es lo que CombatActor.heal()/RunState.heal()
## realmente aplicó (ya clampeado a vida máxima, ya con Decay aplicado vía
## CombatStatusController.get_effective_healing) — nunca el monto teórico
## pedido. requested_amount queda para poder derivar overheal
## (requested_amount - actual_amount) sin una fórmula nueva.

var action_id: int
var source_actor: CombatActor
var target_actor: CombatActor
var requested_amount: int
var actual_amount: int
var hp_before: int
var hp_after: int


func _init(
	p_action_id: int,
	p_source_actor: CombatActor,
	p_target_actor: CombatActor,
	p_requested_amount: int,
	p_actual_amount: int,
	p_hp_before: int,
	p_hp_after: int,
) -> void:
	action_id = p_action_id
	source_actor = p_source_actor
	target_actor = p_target_actor
	requested_amount = p_requested_amount
	actual_amount = p_actual_amount
	hp_before = p_hp_before
	hp_after = p_hp_after

class_name ReactionEvent
extends RefCounted

## Combat Domain M4 — reporta una reacción que el sistema de estados YA
## resolvió (CombatStatusController.last_reaction), nunca la recalcula.
## Cubre las dos reacciones deterministas actuales: WET+CHILLED (bonus de
## stacks) y WET+SHOCK (salto en cadena a un segundo target). Ver handoff
## M4 sección 17 — no se autoriza contenido/mecánica nueva.

var action_id: int
var source_actor: CombatActor
var target_actor: CombatActor
var reaction_id: StringName
var triggering_status_id: StringName
var resulting_status_id: StringName
var bonus_stacks: int


func _init(
	p_action_id: int,
	p_source_actor: CombatActor,
	p_target_actor: CombatActor,
	p_reaction_id: StringName,
	p_triggering_status_id: StringName,
	p_resulting_status_id: StringName,
	p_bonus_stacks: int = 0,
) -> void:
	action_id = p_action_id
	source_actor = p_source_actor
	target_actor = p_target_actor
	reaction_id = p_reaction_id
	triggering_status_id = p_triggering_status_id
	resulting_status_id = p_resulting_status_id
	bonus_stacks = p_bonus_stacks

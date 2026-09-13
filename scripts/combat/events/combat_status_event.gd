class_name StatusEvent
extends RefCounted

## Combat Domain M4 — una sola clase para APPLIED y TICK (mismo shape,
## distinguido por kind) en vez de dos tipos separados — ver handoff M4
## sección 16. stacks/remaining_duration son snapshots tomados en el
## momento de aplicar/tiquear, nunca se re-leen después de un
## StatusEffectInstance que sigue mutando el resto del combate. tick_damage/
## tick_healing reusan exactamente los dos campos que
## CombatStatusController.TickResult ya calculaba.

enum Kind {
	APPLIED,
	TICK,
}

var action_id: int
var kind: Kind
var source_actor: CombatActor
var target_actor: CombatActor
var status_id: StringName
var stacks: int
var remaining_duration: int
var tick_damage: int
var tick_healing: int


func _init(
	p_action_id: int,
	p_kind: Kind,
	p_source_actor: CombatActor,
	p_target_actor: CombatActor,
	p_status_id: StringName,
	p_stacks: int,
	p_remaining_duration: int,
	p_tick_damage: int = 0,
	p_tick_healing: int = 0,
) -> void:
	action_id = p_action_id
	kind = p_kind
	source_actor = p_source_actor
	target_actor = p_target_actor
	status_id = p_status_id
	stacks = p_stacks
	remaining_duration = p_remaining_duration
	tick_damage = p_tick_damage
	tick_healing = p_tick_healing

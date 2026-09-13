class_name ActionEvent
extends RefCounted

## Combat Domain M4 — reporta que una acción real empezó a resolverse: quién,
## qué tipo de acción, con qué skill/acción de IA (si aplica), y contra qué
## targets ya resueltos. Presentation-independent: sin texto localizado, sin
## nombres de VFX/animación, sin referencias a nodos de escena.
##
## targets es una COPIA (duplicate()) del array resuelto — nunca la misma
## referencia mutable que combat.gd sigue usando después de construir el
## evento, para que el evento siga siendo un snapshot fiel aunque el equipo
## cambie más tarde en el combate (ver handoff M4 sección 25/26).

var action_id: int
var source_actor: CombatActor
var action_kind: StringName
var action_data_id: StringName
var targets: Array[CombatActor]


func _init(
	p_action_id: int,
	p_source_actor: CombatActor,
	p_action_kind: StringName,
	p_action_data_id: StringName,
	p_targets: Array[CombatActor],
) -> void:
	action_id = p_action_id
	source_actor = p_source_actor
	action_kind = p_action_kind
	action_data_id = p_action_data_id
	targets = p_targets.duplicate()

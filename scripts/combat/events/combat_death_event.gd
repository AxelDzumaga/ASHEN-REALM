class_name DeathEvent
extends RefCounted

## Combat Domain M4 — una transición viva -> muerto (hp_before > 0 y
## hp_after <= 0) es naturalmente única porque no existe revive; no depende
## de ninguna bandera de presentación (death_presented sigue siendo
## responsabilidad exclusiva de combat.gd para animación/idempotencia
## visual, no de este evento). source_actor queda null cuando el dominio no
## puede probar una causa (p. ej. un tick de estado sin atacante conocido) —
## nunca se inventa atribución.

var action_id: int
var actor: CombatActor
var source_actor: CombatActor


func _init(p_action_id: int, p_actor: CombatActor, p_source_actor: CombatActor = null) -> void:
	action_id = p_action_id
	actor = p_actor
	source_actor = p_source_actor

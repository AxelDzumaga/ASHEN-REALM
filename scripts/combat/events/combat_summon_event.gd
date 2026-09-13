class_name SummonEvent
extends RefCounted

## Combat Domain M4 — reporta actores efectivamente agregados por
## _run_boss_summon_action(). summoned_actors es una COPIA (duplicate());
## BossEncounterController/BossRuntimeState siguen siendo la autoridad de
## cuántos/cuándo se puede invocar — este evento solo reporta el resultado
## ya decidido.

var action_id: int
var source_actor: CombatActor
var summoned_actors: Array[CombatActor]


func _init(p_action_id: int, p_source_actor: CombatActor, p_summoned_actors: Array[CombatActor]) -> void:
	action_id = p_action_id
	source_actor = p_source_actor
	summoned_actors = p_summoned_actors.duplicate()

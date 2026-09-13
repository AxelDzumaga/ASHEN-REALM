class_name BossPhaseEvent
extends RefCounted

## Combat Domain M4 — reporta una transición de fase ya decidida por
## BossEncounterController.check_phase_transition() (TransitionResult).
## BossEncounterController sigue siendo la única autoridad de fase; este
## evento no vuelve a evaluar el umbral de HP.

var action_id: int
var boss_actor: CombatActor
var previous_phase: BossPhaseData
var current_phase: BossPhaseData
var crossed_phases: int


func _init(
	p_action_id: int,
	p_boss_actor: CombatActor,
	p_previous_phase: BossPhaseData,
	p_current_phase: BossPhaseData,
	p_crossed_phases: int,
) -> void:
	action_id = p_action_id
	boss_actor = p_boss_actor
	previous_phase = p_previous_phase
	current_phase = p_current_phase
	crossed_phases = p_crossed_phases

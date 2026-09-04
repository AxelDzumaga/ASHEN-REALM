class_name BossRuntimeState
extends RefCounted

var current_phase_index: int = 0
var triggered_phase_ids: Array[StringName] = []
var pending_summon_phase_index: int = -1
var pending_summon_count: int = 0
var summon_completed: bool = false
var counter_armed: bool = false
var encounter_finished: bool = false


func mark_phase_triggered(phase: BossPhaseData, index: int) -> void:
	if phase == null:
		return
	current_phase_index = index
	if phase.phase_id not in triggered_phase_ids:
		triggered_phase_ids.append(phase.phase_id)
	if phase.summon_data != null and phase.summon_count > 0 and not summon_completed:
		pending_summon_phase_index = index
		pending_summon_count = phase.summon_count


func mark_summon_completed() -> void:
	summon_completed = true
	pending_summon_phase_index = -1
	pending_summon_count = 0


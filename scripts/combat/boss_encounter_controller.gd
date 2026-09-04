class_name BossEncounterController
extends RefCounted

class TransitionResult:
	extends RefCounted
	var previous_phase: BossPhaseData
	var current_phase: BossPhaseData
	var crossed_phases: int = 0

var data: BossEncounterData
var runtime: BossRuntimeState
var _boss_ref: WeakRef


func _init(encounter_data: BossEncounterData, boss_actor: CombatActor) -> void:
	data = encounter_data
	runtime = BossRuntimeState.new()
	_boss_ref = weakref(boss_actor)
	var initial_phase: BossPhaseData = data.get_phase(0) if data != null else null
	if initial_phase != null:
		runtime.mark_phase_triggered(initial_phase, 0)


func get_boss_actor() -> CombatActor:
	if _boss_ref == null:
		return null
	return _boss_ref.get_ref() as CombatActor


func owns_actor(actor: CombatActor) -> bool:
	return actor != null and actor == get_boss_actor()


func get_current_phase() -> BossPhaseData:
	return data.get_phase(runtime.current_phase_index) if data != null and runtime != null else null


func get_active_ai_profile(fallback: EnemyAIData) -> EnemyAIData:
	var phase: BossPhaseData = get_current_phase()
	return phase.ai_profile_override if phase != null and phase.ai_profile_override != null else fallback


func get_attack_multiplier() -> float:
	var phase: BossPhaseData = get_current_phase()
	return phase.attack_multiplier if phase != null else 1.0


func get_defense_bonus() -> int:
	var phase: BossPhaseData = get_current_phase()
	return phase.defense_bonus if phase != null else 0


func check_phase_transition() -> TransitionResult:
	var boss_actor: CombatActor = get_boss_actor()
	if data == null or runtime == null or boss_actor == null or not boss_actor.is_alive() or runtime.encounter_finished:
		return null
	var result: TransitionResult = TransitionResult.new()
	result.previous_phase = get_current_phase()
	var health_percent: float = float(boss_actor.get_current_hp()) * 100.0 / float(boss_actor.get_max_hp())
	var final_index: int = runtime.current_phase_index
	for phase_index: int in range(runtime.current_phase_index + 1, data.phases.size()):
		var candidate: BossPhaseData = data.phases[phase_index]
		if candidate != null and health_percent <= float(candidate.hp_threshold_percent):
			final_index = phase_index
			result.crossed_phases += 1
			runtime.mark_phase_triggered(candidate, phase_index)
	if final_index == runtime.current_phase_index and result.crossed_phases == 0:
		return null
	runtime.current_phase_index = final_index
	result.current_phase = get_current_phase()
	return result


func get_forced_action(actor: CombatActor) -> EnemyActionData:
	if not owns_actor(actor) or runtime.pending_summon_count <= 0 or runtime.summon_completed:
		return null
	return data.summon_action


func get_pending_summon_phase() -> BossPhaseData:
	return data.get_phase(runtime.pending_summon_phase_index) if data != null and runtime != null else null


func get_pending_summon_count() -> int:
	return runtime.pending_summon_count if runtime != null else 0


func mark_summon_completed() -> void:
	if runtime != null:
		runtime.mark_summon_completed()


func is_counter_action(action: EnemyActionData) -> bool:
	return action != null and data != null and not data.counter_action_id.is_empty() and action.action_id == data.counter_action_id


func arm_counter() -> void:
	if runtime != null:
		runtime.counter_armed = true


func can_counter_basic(target: CombatActor) -> bool:
	return runtime != null and runtime.counter_armed and owns_actor(target) and target.is_alive()


func consume_counter_multiplier(target: CombatActor) -> float:
	if not can_counter_basic(target):
		return 0.0
	runtime.counter_armed = false
	return data.counter_damage_multiplier


func get_excluded_action_ids(actor: CombatActor) -> Array[StringName]:
	var excluded: Array[StringName] = []
	if owns_actor(actor) and runtime.counter_armed and data != null and not data.counter_action_id.is_empty():
		excluded.append(data.counter_action_id)
	return excluded


func finish_encounter() -> void:
	if runtime != null:
		runtime.encounter_finished = true
		runtime.counter_armed = false
		runtime.pending_summon_count = 0

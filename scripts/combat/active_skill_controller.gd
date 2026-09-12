class_name ActiveSkillController
extends RefCounted

var skill: ActiveSkillData
var run_state: RunState
var runtime_state: SkillRuntimeState
var cooldown_remaining: int:
	get:
		return runtime_state.cooldown_remaining
	set(value):
		runtime_state.cooldown_remaining = maxi(0, value)
var used_this_combat: bool:
	get:
		return runtime_state.used_this_combat
	set(value):
		runtime_state.used_this_combat = value
var guard_active: bool = false
var last_heal_amount: int = 0
var last_guard_reduction: int = 0
var last_guard_consumed: bool = false
var temporary_defense_bonus: int = 0
## Opcional — CombatSkillController.set_player_actor() lo propaga después de
## construir. Solo se usa para que DECAY reduzca la curación de skills tipo
## HEAL; null es un no-op seguro (full_run_simulation.gd nunca lo asigna).
var player_actor: CombatActor
var _stored_embers_applied: bool = false
var _simulation_overrides: Dictionary = {}


func _init(active_skill: ActiveSkillData, active_run: RunState, simulation_overrides: Dictionary = {}) -> void:
	skill = active_skill
	run_state = active_run
	_simulation_overrides = simulation_overrides.duplicate(true)
	runtime_state = SkillRuntimeState.new(skill.id)
	reset_for_combat()


func reset_for_combat() -> void:
	runtime_state.reset()
	guard_active = false
	last_heal_amount = 0
	last_guard_reduction = 0
	last_guard_consumed = false
	_stored_embers_applied = false
	temporary_defense_bonus = 0


func can_use(available_energy: int) -> bool:
	if skill == null or run_state == null or not skill.enabled:
		return false
	if available_energy < get_effective_energy_cost() or cooldown_remaining > 0:
		return false
	match skill.skill_type:
		ActiveSkillData.SkillType.DEFENSE:
			return not guard_active
		ActiveSkillData.SkillType.HEAL:
			return (skill.cooldown_type != ActiveSkillData.CooldownType.ONCE_PER_COMBAT or not used_this_combat) and run_state.current_health < run_state.max_health
		_:
			return true


func activate() -> void:
	cooldown_remaining = skill.cooldown_turns
	last_heal_amount = 0
	last_guard_reduction = 0
	_stored_embers_applied = false
	match skill.skill_type:
		ActiveSkillData.SkillType.DEFENSE:
			guard_active = true
		ActiveSkillData.SkillType.HEAL:
			used_this_combat = skill.cooldown_type == ActiveSkillData.CooldownType.ONCE_PER_COMBAT
			var heal_percent: float = SkillAugmentResolver.effective_heal_percent(skill, run_state)
			var heal_amount: int = maxi(1, floori(float(run_state.max_health) * heal_percent))
			heal_amount = CombatStatusController.get_effective_healing(player_actor, heal_amount)
			last_heal_amount = run_state.heal(heal_amount)
			temporary_defense_bonus = SkillAugmentResolver.renewal_defense(run_state)
	runtime_state.ready_announced = false


## Combat Domain M1 — renombrado desde on_basic_attack_completed(): el
## cooldown avanza por turno del dueño, no por elegir ataque básico
## específicamente. Ver CombatSkillController.advance_cooldowns().
func advance_cooldown() -> void:
	if cooldown_remaining > 0:
		cooldown_remaining = maxi(0, cooldown_remaining - 1)


func consume_ready_notification(available_energy: int) -> bool:
	if not can_use(available_energy) or runtime_state.ready_announced:
		return false
	runtime_state.ready_announced = true
	return true


func get_status_text(available_energy: int) -> String:
	if skill.skill_type == ActiveSkillData.SkillType.HEAL and used_this_combat:
		return "USADA"
	if skill.skill_type == ActiveSkillData.SkillType.DEFENSE and guard_active:
		return "ACTIVA · PRÓXIMO GOLPE"
	if cooldown_remaining > 0:
		return "RECARGA %d" % cooldown_remaining
	if available_energy < get_effective_energy_cost():
		return "BRASA %d / %d" % [available_energy, get_effective_energy_cost()]
	if skill.skill_type == ActiveSkillData.SkillType.HEAL and run_state.current_health >= run_state.max_health:
		return "VIDA COMPLETA"
	return "LISTA"


func calculate_skill_damage(effective_attack: int, enemy_defense: int, enemy_health: int, enemy_max_health: int) -> int:
	if skill.skill_type != ActiveSkillData.SkillType.DAMAGE:
		return 0
	var multiplier: float = SkillAugmentResolver.effective_damage_multiplier(skill, run_state)
	var skill_attack: int = maxi(1, roundi(float(effective_attack) * multiplier))
	var base_damage: int = CombatMath.calculate_damage(skill_attack, enemy_defense)
	var execution: float = SkillAugmentResolver.execution_multiplier(run_state, enemy_health, enemy_max_health)
	var resolved_damage: int = maxi(1, roundi(float(base_damage) * execution))
	return EquipmentEffectResolver.apply_skill_damage(resolved_damage, run_state)


func apply_guard_to_damage(incoming_damage: int) -> int:
	last_guard_reduction = 0
	last_guard_consumed = false
	_stored_embers_applied = false
	if not guard_active or incoming_damage <= 0:
		return incoming_damage
	guard_active = false
	last_guard_consumed = true
	var guard_reduction: float = SkillAugmentResolver.effective_guard_reduction(skill, run_state)
	var reduction_percent: int = clampi(roundi(guard_reduction * 100.0), 0, 99)
	var remaining_percent: int = 100 - reduction_percent
	var reduced_damage: int = maxi(1, ceili(float(incoming_damage * remaining_percent) / 100.0))
	last_guard_reduction = incoming_damage - reduced_damage
	return reduced_damage


func get_active_effect_text() -> String:
	var effects: Array[String] = []
	if guard_active:
		effects.append("ASHEN GUARD")
	if temporary_defense_bonus > 0:
		effects.append("ASHEN RENEWAL +%d DEF" % temporary_defense_bonus)
	return " · ".join(effects)


func get_effective_energy_cost() -> int:
	var costs: Dictionary = _simulation_overrides.get("skill_costs", {})
	if costs.has(String(skill.id)):
		return maxi(0, int(costs[String(skill.id)]))
	return SkillAugmentResolver.effective_energy_cost(skill, run_state)


func consume_stored_embers_energy() -> int:
	if not last_guard_consumed or _stored_embers_applied:
		return 0
	_stored_embers_applied = true
	return SkillAugmentResolver.stored_embers_energy(run_state)


func consume_counter_guard_damage() -> int:
	if not last_guard_consumed:
		return 0
	last_guard_consumed = false
	return SkillAugmentResolver.counter_guard_damage(run_state)


func get_temporary_defense_bonus() -> int:
	return temporary_defense_bonus


func debug_reset_cooldown() -> void:
	cooldown_remaining = 0

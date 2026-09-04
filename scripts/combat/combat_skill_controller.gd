class_name CombatSkillController
extends RefCounted

const MAX_ENERGY: int = 100
const BASIC_ATTACK_ENERGY: int = 25
const DAMAGE_RECEIVED_ENERGY: int = 10
const COMBAT_CARRYOVER_FRACTION: float = 0.20

var current_energy: int = 0
var skills: Array[ActiveSkillController] = []
var _run_state: RunState
var _simulation_overrides: Dictionary = {}


func _init(skill_ids: Array[StringName], run_state: RunState, simulation_overrides: Dictionary = {}) -> void:
	_run_state = run_state
	_simulation_overrides = simulation_overrides.duplicate(true)
	if _run_state != null:
		current_energy = clampi(_run_state.combat_energy_carryover, 0, MAX_ENERGY)
		_run_state.combat_energy_carryover = 0
	for skill_id: StringName in skill_ids:
		if skill_id.is_empty():
			continue
		var skill_data: ActiveSkillData = ActiveSkillCatalog.get_by_id(skill_id)
		if skill_data != null and skill_data.enabled:
			skills.append(ActiveSkillController.new(skill_data, run_state, _simulation_overrides))


## Propaga el CombatActor del jugador a cada skill ya construida — ver el
## comentario en ActiveSkillController.player_actor sobre por qué no es un
## parámetro de constructor.
func set_player_actor(actor: CombatActor) -> void:
	for controller: ActiveSkillController in skills:
		controller.player_actor = actor


func get_by_id(skill_id: StringName) -> ActiveSkillController:
	for controller: ActiveSkillController in skills:
		if controller.skill.id == skill_id:
			return controller
	return null


func can_use(controller: ActiveSkillController) -> bool:
	return controller != null and controller.can_use(current_energy)


func try_use(controller: ActiveSkillController) -> bool:
	if not can_use(controller):
		return false
	current_energy = maxi(0, current_energy - controller.get_effective_energy_cost())
	controller.activate()
	_refresh_ready_flags()
	return true


func on_basic_attack_completed() -> int:
	for controller: ActiveSkillController in skills:
		controller.on_basic_attack_completed()
	return add_energy(int(_simulation_overrides.get("basic_energy", BASIC_ATTACK_ENERGY)))


func on_damage_received(damage: int) -> int:
	return add_energy(DAMAGE_RECEIVED_ENERGY) if damage > 0 else 0


func add_energy(amount: int) -> int:
	var previous_energy: int = current_energy
	var biome: BiomeData = _run_state.biome_data if _run_state != null else null
	var equipment_multiplier: float = 1.0 + (_run_state.equipment_ember_gain_bonus if _run_state != null else 0.0)
	var effective_amount: int = BiomeModifierResolver.effective_energy_gain(amount, biome, equipment_multiplier)
	current_energy = clampi(current_energy + effective_amount, 0, MAX_ENERGY)
	_refresh_ready_flags()
	return current_energy - previous_energy


func consume_ready_skill() -> ActiveSkillController:
	var first_ready: ActiveSkillController
	for controller: ActiveSkillController in skills:
		if controller.consume_ready_notification(current_energy):
			if first_ready == null:
				first_ready = controller
	return first_ready


func store_combat_carryover(enabled: bool = true) -> int:
	if _run_state == null:
		return 0
	var retained: int = floori(float(current_energy) * COMBAT_CARRYOVER_FRACTION) if enabled else 0
	_run_state.combat_energy_carryover = clampi(retained, 0, MAX_ENERGY)
	return _run_state.combat_energy_carryover


func get_guard_controller() -> ActiveSkillController:
	for controller: ActiveSkillController in skills:
		if controller.guard_active:
			return controller
	return null


func get_temporary_defense_bonus() -> int:
	var total: int = 0
	for controller: ActiveSkillController in skills:
		total += controller.get_temporary_defense_bonus()
	return total


func get_active_effect_controllers() -> Array[ActiveSkillController]:
	var result: Array[ActiveSkillController] = []
	for controller: ActiveSkillController in skills:
		if controller.guard_active or controller.get_temporary_defense_bonus() > 0:
			result.append(controller)
	return result


func debug_fill_energy() -> void:
	current_energy = MAX_ENERGY
	_refresh_ready_flags()


func debug_reset_cooldowns() -> void:
	for controller: ActiveSkillController in skills:
		controller.cooldown_remaining = 0
	_refresh_ready_flags()


func _refresh_ready_flags() -> void:
	for controller: ActiveSkillController in skills:
		if not controller.can_use(current_energy):
			controller.runtime_state.ready_announced = false

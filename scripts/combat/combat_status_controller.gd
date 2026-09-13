class_name CombatStatusController
extends RefCounted

## Reacciones cruzadas Fase 1 — WET (Marea) es el catalizador de las otras
## dos: Escarcha sobre un objetivo Empapado acumula más Congelado (buildup),
## Tormenta sobre un objetivo Empapado hace que Electrocutado salte a otro
## objetivo (un solo salto, no cascada — ver _chain_shock). Ninguna de las
## dos toca CombatMath: son puramente stacks/objetivo adicionales sobre el
## mismo mecanismo de apply_status ya usado por BURN/WET/CHILLED/SHOCK.
const WET_FROST_BONUS_STACKS: int = 1

var _simulation_overrides: Dictionary = {}


func _init(simulation_overrides: Dictionary = {}) -> void:
	_simulation_overrides = simulation_overrides.duplicate(true)

class TickResult:
	extends RefCounted
	var status: StatusEffectInstance
	var damage: int = 0
	var healing: int = 0
	## Combat Domain M4 — snapshots tomados en process_turn_start() en el
	## momento exacto de cada aplicación, para que combat.gd pueda construir
	## un StatusEvent(kind=TICK) sin volver a leer get_current_hp() después
	## (que ya reflejaría ticks posteriores del mismo turno).
	var hp_before: int = 0
	var hp_after: int = 0

	func _init(effect: StatusEffectInstance) -> void:
		status = effect


## Combat Domain M4 — información mínima de la última reacción resuelta por
## apply_status(), para que combat.gd pueda construir un ReactionEvent sin
## recalcular ni duplicar la lógica de reacción (mismo patrón ya usado en
## este proyecto: ActiveSkillController.last_guard_reduction,
## BoonController.was_inferno_triggered(), etc. — un flag de "último
## resultado" consultado por el llamador inmediatamente después de invocar
## el método que lo produjo). No cambia reglas de reacción, stacks, daño,
## duración ni RNG — solo anota los mismos dos chequeos que apply_status()
## ya hacía (WET+CHILLED, WET+SHOCK).
class LastReactionInfo:
	extends RefCounted
	var occurred: bool = false
	var reaction_id: StringName = &""
	var source_actor: CombatActor
	var target_actor: CombatActor
	var triggering_status_id: StringName = &""
	var resulting_status_id: StringName = &""
	var bonus_stacks: int = 0

var last_reaction: LastReactionInfo = LastReactionInfo.new()


func apply_status(
	target_actor: CombatActor,
	status_id: StringName,
	source_actor: CombatActor,
	stacks: int = 1,
	duration_override: int = -1,
	chain_candidates: Array[CombatActor] = [],
) -> StatusEffectInstance:
	# Combat Domain M4 — se resetea al principio de cada llamada para que un
	# consultante que revisa last_reaction justo después de ESTA llamada
	# nunca vea el resultado de una llamada anterior no relacionada.
	last_reaction = LastReactionInfo.new()
	if target_actor == null or not target_actor.is_alive():
		return null
	var status_data: StatusEffectData = StatusEffectCatalog.get_by_id(status_id)
	if status_data == null or not can_apply_status(target_actor, status_data):
		return null
	var target_was_wet: bool = target_actor.has_status(&"wet")
	var duration_bonuses: Dictionary = _simulation_overrides.get("status_duration_bonuses", {})
	var stack_bonuses: Dictionary = _simulation_overrides.get("status_stack_bonuses", {})
	stacks += int(stack_bonuses.get(String(status_id), 0))
	if status_id == &"chilled" and target_was_wet:
		stacks += WET_FROST_BONUS_STACKS
		last_reaction = LastReactionInfo.new()
		last_reaction.occurred = true
		last_reaction.reaction_id = &"wet_frost_bonus"
		last_reaction.source_actor = source_actor
		last_reaction.target_actor = target_actor
		last_reaction.triggering_status_id = &"wet"
		last_reaction.resulting_status_id = &"chilled"
		last_reaction.bonus_stacks = WET_FROST_BONUS_STACKS
	var resolved_duration: int = duration_override
	var duration_bonus: int = int(duration_bonuses.get(String(status_id), 0))
	if duration_bonus != 0:
		resolved_duration = (status_data.base_duration if duration_override < 0 else duration_override) + duration_bonus
	var instance: StatusEffectInstance
	var existing: StatusEffectInstance = target_actor.get_status(status_id)
	if existing != null:
		existing.apply_again(
			stacks,
			resolved_duration,
			source_actor.actor_id if source_actor != null else &"",
			source_actor,
		)
		instance = existing
	else:
		var created: StatusEffectInstance = StatusEffectInstance.new(
			status_data,
			source_actor.actor_id if source_actor != null else &"",
			source_actor,
			stacks,
			resolved_duration,
		)
		if created.active:
			target_actor.add_status_instance(created)
			instance = created
	if instance != null and status_id == &"shock" and target_was_wet:
		_chain_shock(source_actor, chain_candidates)
	return instance


## Un solo salto determinista al primer objetivo vivo sin Electrocutado ya
## activo — chain_candidates llega vacío del recursivo (candidates.slice()
## nunca se pasa dos veces), así que no hay riesgo de cascada infinita.
func _chain_shock(source_actor: CombatActor, candidates: Array[CombatActor]) -> void:
	for candidate: CombatActor in candidates:
		if candidate == null or not candidate.is_alive() or candidate.has_status(&"shock"):
			continue
		apply_status(candidate, &"shock", source_actor, 1, -1, [])
		# Combat Domain M4 — se pisa last_reaction DESPUÉS de la llamada
		# recursiva a propósito: esa llamada ya reseteó/pudo setear su
		# propio last_reaction en base al estado del candidato, y acá se
		# reemplaza por el hecho real que le importa a quien llamó al
		# apply_status(&"shock", ...) de más afuera — el salto en cadena.
		last_reaction = LastReactionInfo.new()
		last_reaction.occurred = true
		last_reaction.reaction_id = &"wet_shock_chain"
		last_reaction.source_actor = source_actor
		last_reaction.target_actor = candidate
		last_reaction.triggering_status_id = &"wet"
		last_reaction.resulting_status_id = &"shock"
		return


func can_apply_status(_target_actor: CombatActor, _status_data: StatusEffectData) -> bool:
	# Hook único para futuras inmunidades/resistencias; ETAPA 40 aplica todo de forma determinista.
	return true


func remove_status(actor: CombatActor, status_id: StringName) -> bool:
	return actor != null and actor.remove_status_instance(status_id)


func clear_expired_statuses(actor: CombatActor) -> void:
	if actor == null:
		return
	actor.clear_expired_statuses()


func clear_all(actor: CombatActor) -> void:
	if actor != null:
		actor.clear_all_statuses()


func process_turn_start(actor: CombatActor) -> Array[TickResult]:
	var results: Array[TickResult] = []
	if actor == null or not actor.is_alive():
		return results
	for status_data: StatusEffectData in StatusEffectCatalog.get_all():
		var instance: StatusEffectInstance = actor.get_status(status_data.status_id)
		if instance == null:
			continue
		if not instance.active or instance.data.duration_type != StatusEffectData.DurationType.TURNS:
			continue
		instance.processed_this_turn = true
		if instance.data.trigger != StatusEffectData.Trigger.TURN_START:
			continue
		var result: TickResult = TickResult.new(instance)
		result.hp_before = actor.get_current_hp()
		if instance.data.status_id == &"regen":
			if actor.is_alive():
				result.healing = actor.heal(get_effective_healing(actor, instance.data.magnitude_per_stack * instance.stacks))
		elif instance.data.category == StatusEffectData.Category.DOT:
			# Mismo mecanismo para BURN (Brasa) y las afinidades elementales
			# nuevas (WET/CHILLED/SHOCK/DECAY) — cualquier status DOT tiquea daño
			# acá, no hace falta un caso hardcodeado por status_id. CURSE también
			# amplifica el tick: es daño recibido igual que cualquier otro.
			var scales: Dictionary = _simulation_overrides.get("effect_scales", {})
			var scale: float = maxf(0.0, float(scales.get(String(instance.data.status_id), 1.0)))
			var tick_damage: int = maxi(0, roundi(float(instance.data.magnitude_per_stack * instance.stacks) * scale))
			result.damage = actor.apply_damage(get_effective_incoming_damage(actor, tick_damage))
		result.hp_after = actor.get_current_hp()
		results.append(result)
		if not actor.is_alive():
			break
	return results


func process_turn_end(actor: CombatActor) -> void:
	if actor == null:
		return
	for instance: StatusEffectInstance in actor.get_statuses():
		if instance.data.duration_type == StatusEffectData.DurationType.TURNS and instance.processed_this_turn:
			instance.processed_this_turn = false
			instance.consume_duration()
	clear_expired_statuses(actor)


func consume_hit_status(actor: CombatActor, status_id: StringName) -> bool:
	if actor == null:
		return false
	var instance: StatusEffectInstance = actor.get_status(status_id)
	if instance == null or instance.data.duration_type != StatusEffectData.DurationType.HITS:
		return false
	instance.consume_duration()
	clear_expired_statuses(actor)
	return true


func get_effective_attack(actor: CombatActor, base_attack: int) -> int:
	var result: int = maxi(0, base_attack)
	if result == 0:
		return 0
	var weaken: StatusEffectInstance = actor.get_status(&"weaken") if actor != null else null
	if weaken != null:
		var reduction_percent: int = clampi(weaken.data.magnitude_per_stack * weaken.stacks, 0, 90)
		result = maxi(1, ceili(float(result * (100 - reduction_percent)) / 100.0))
	return result


func get_effective_defense(actor: CombatActor, base_defense: int) -> int:
	var result: int = maxi(0, base_defense)
	var armor_break: StatusEffectInstance = actor.get_status(&"armor_break") if actor != null else null
	if armor_break != null:
		result = maxi(0, result - armor_break.data.magnitude_per_stack * armor_break.stacks)
	return result


## CURSE: +% de daño recibido de cualquier fuente (no solo del tipo Ceniza —
## a diferencia de WEAK/RESIST en AffinityResolver, que solo reaccionan al
## elemento del ataque). Se aplica en combat.gd justo antes de cada
## apply_damage(), después de la resolución elemental — daño 0 (inmune) se
## queda en 0, no se ve afectado por la maldición.
func get_effective_incoming_damage(actor: CombatActor, incoming_damage: int) -> int:
	var result: int = maxi(0, incoming_damage)
	if result == 0 or actor == null:
		return result
	var curse: StatusEffectInstance = actor.get_status(&"curse")
	if curse == null:
		return result
	var increase_percent: int = maxi(0, curse.data.magnitude_per_stack * curse.stacks)
	return maxi(1, ceili(float(result * (100 + increase_percent)) / 100.0))


## DECAY: -% de curación recibida. Estática porque se llama desde
## ActiveSkillController y BoonController, que no guardan una instancia de
## este controller (solo combat.gd la tiene) — mismo dato (StatusEffectData
## por stack), sin duplicar la fuente de verdad.
static func get_effective_healing(actor: CombatActor, base_healing: int) -> int:
	var result: int = maxi(0, base_healing)
	if result == 0 or actor == null:
		return result
	var decay: StatusEffectInstance = actor.get_status(&"decay")
	if decay == null:
		return result
	var reduction_percent: int = clampi(decay.data.secondary_magnitude_per_stack * decay.stacks, 0, 90)
	return maxi(0, floori(float(result * (100 - reduction_percent)) / 100.0))

extends Node

## Combat Domain M4 — sección 38 del handoff: pruebas directas de
## CombatEventStream y de la forma/campos de los 8 tipos de evento, sin
## Combat2D. Mismo patrón que combat_target_resolver_test.gd (M3): actores
## construidos directamente, sin escena real.
##
## Sección 37: regresión de reacciones — confirma que CombatStatusController
## sigue produciendo exactamente la misma mecánica (stacks/duración/salto)
## que antes de M4, y que last_reaction refleja esa mecánica sin duplicar
## ni cambiar sus reglas.

var _failures: Array[String] = []


func _ready() -> void:
	_test_action_id_starts_at_one_and_increments()
	_test_no_action_id_sentinel()
	_test_emit_event_fires_exactly_once()
	_test_stream_retains_no_history()
	_test_action_event_targets_is_snapshot()
	_test_damage_event_caused_death_transition()
	_test_damage_event_no_death_when_already_dead()
	_test_heal_event_fields()
	_test_status_event_kinds()
	_test_reaction_event_fields()
	_test_death_event_source_nullable()
	_test_boss_phase_event_fields()
	_test_summon_event_targets_is_snapshot()
	_test_reaction_wet_chilled_bonus()
	_test_reaction_wet_shock_chain()
	_test_reaction_reset_between_calls()
	print("[EVENT_STREAM_TEST] failures=%s" % JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(label: String, condition: bool) -> void:
	print("[EVENT_STREAM_TEST] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


func _actor(id: String, team: CombatActor.Team, hp: int = 10, max_hp: int = 10) -> CombatActor:
	return CombatActor.new(StringName(id), id, team, CombatActor.ActorType.NORMAL_ENEMY, max_hp, hp, 5, 1)


func _test_action_id_starts_at_one_and_increments() -> void:
	var stream: CombatEventStream = CombatEventStream.new()
	var first: int = stream.next_action_id()
	var second: int = stream.next_action_id()
	var third: int = stream.next_action_id()
	_check("action_id_starts_at_one", first == 1)
	_check("action_id_monotonic", second == 2 and third == 3)


func _test_no_action_id_sentinel() -> void:
	_check("no_action_id_is_zero", CombatEventStream.NO_ACTION_ID == 0)


func _test_emit_event_fires_exactly_once() -> void:
	var stream: CombatEventStream = CombatEventStream.new()
	var received: Array[RefCounted] = []
	stream.event_emitted.connect(func(event: RefCounted) -> void: received.append(event))
	var actor: CombatActor = _actor("a", CombatActor.Team.PLAYER)
	var event: ActionEvent = ActionEvent.new(1, actor, &"basic_attack", &"", [actor])
	stream.emit_event(event)
	_check("emit_event_fires_exactly_once", received.size() == 1)
	_check("emit_event_passes_same_object", received[0] == event)


func _test_stream_retains_no_history() -> void:
	var stream: CombatEventStream = CombatEventStream.new()
	var actor: CombatActor = _actor("a", CombatActor.Team.PLAYER)
	stream.emit_event(ActionEvent.new(stream.next_action_id(), actor, &"basic_attack", &"", [actor]))
	stream.emit_event(ActionEvent.new(stream.next_action_id(), actor, &"basic_attack", &"", [actor]))
	# CombatEventStream no expone ningún getter de historial — la única
	# superficie pública es next_action_id()/emit_event()/event_emitted.
	# Confirmamos indirectamente: un segundo listener conectado DESPUÉS de
	# ambos emit_event() no recibe nada retroactivo.
	var late_listener_received: Array[RefCounted] = []
	stream.event_emitted.connect(func(event: RefCounted) -> void: late_listener_received.append(event))
	_check("stream_retains_no_history", late_listener_received.is_empty())


func _test_action_event_targets_is_snapshot() -> void:
	var caster: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var enemy: CombatActor = _actor("e", CombatActor.Team.ENEMY)
	var live_targets: Array[CombatActor] = [enemy]
	var event: ActionEvent = ActionEvent.new(1, caster, &"basic_attack", &"", live_targets)
	live_targets.append(_actor("e2", CombatActor.Team.ENEMY))
	_check("action_event_targets_is_snapshot", event.targets.size() == 1)
	_check("action_event_targets_content", event.targets[0] == enemy)


func _test_damage_event_caused_death_transition() -> void:
	var source: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var target: CombatActor = _actor("e", CombatActor.Team.ENEMY)
	var event: DamageEvent = DamageEvent.new(1, source, target, 10, 10, 0)
	_check("damage_event_caused_death_true", event.caused_death)
	var alive_event: DamageEvent = DamageEvent.new(1, source, target, 5, 10, 5)
	_check("damage_event_caused_death_false_when_alive", not alive_event.caused_death)


func _test_damage_event_no_death_when_already_dead() -> void:
	var source: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var target: CombatActor = _actor("e", CombatActor.Team.ENEMY)
	# hp_before ya es 0 (target ya estaba muerto) — un segundo golpe sobre un
	# cadáver nunca debe reportar caused_death=true otra vez.
	var event: DamageEvent = DamageEvent.new(1, source, target, 5, 0, 0)
	_check("damage_event_no_duplicate_death_on_corpse", not event.caused_death)


func _test_heal_event_fields() -> void:
	var actor: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var event: HealEvent = HealEvent.new(1, actor, actor, 30, 18, 82, 100)
	_check("heal_event_requested_amount", event.requested_amount == 30)
	_check("heal_event_actual_amount_clamped", event.actual_amount == 18)
	_check("heal_event_hp_before", event.hp_before == 82)
	_check("heal_event_hp_after", event.hp_after == 100)


func _test_status_event_kinds() -> void:
	var source: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var target: CombatActor = _actor("e", CombatActor.Team.ENEMY)
	var applied: StatusEvent = StatusEvent.new(1, StatusEvent.Kind.APPLIED, source, target, &"burn", 2, 3)
	_check("status_event_applied_kind", applied.kind == StatusEvent.Kind.APPLIED)
	_check("status_event_applied_no_tick_amounts_required", applied.tick_damage == 0 and applied.tick_healing == 0)
	var tick: StatusEvent = StatusEvent.new(CombatEventStream.NO_ACTION_ID, StatusEvent.Kind.TICK, source, target, &"burn", 2, 2, 7, 0)
	_check("status_event_tick_kind", tick.kind == StatusEvent.Kind.TICK)
	_check("status_event_tick_uses_no_action_id", tick.action_id == CombatEventStream.NO_ACTION_ID)
	_check("status_event_tick_damage", tick.tick_damage == 7)


func _test_reaction_event_fields() -> void:
	var source: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var target: CombatActor = _actor("e", CombatActor.Team.ENEMY)
	var event: ReactionEvent = ReactionEvent.new(1, source, target, &"wet_frost_bonus", &"wet", &"chilled", 1)
	_check("reaction_event_reaction_id", event.reaction_id == &"wet_frost_bonus")
	_check("reaction_event_triggering", event.triggering_status_id == &"wet")
	_check("reaction_event_resulting", event.resulting_status_id == &"chilled")
	_check("reaction_event_bonus_stacks", event.bonus_stacks == 1)


func _test_death_event_source_nullable() -> void:
	var actor: CombatActor = _actor("e", CombatActor.Team.ENEMY)
	var with_source: DeathEvent = DeathEvent.new(1, actor, _actor("p", CombatActor.Team.PLAYER))
	_check("death_event_source_present", with_source.source_actor != null)
	var without_source: DeathEvent = DeathEvent.new(CombatEventStream.NO_ACTION_ID, actor)
	_check("death_event_source_nullable", without_source.source_actor == null)
	_check("death_event_no_action_id_allowed", without_source.action_id == CombatEventStream.NO_ACTION_ID)


func _test_boss_phase_event_fields() -> void:
	var boss: CombatActor = _actor("boss", CombatActor.Team.ENEMY)
	var event: BossPhaseEvent = BossPhaseEvent.new(CombatEventStream.NO_ACTION_ID, boss, null, null, 2)
	_check("boss_phase_event_crossed_phases", event.crossed_phases == 2)
	_check("boss_phase_event_boss_actor", event.boss_actor == boss)


func _test_summon_event_targets_is_snapshot() -> void:
	var boss: CombatActor = _actor("boss", CombatActor.Team.ENEMY)
	var summoned: Array[CombatActor] = [_actor("m1", CombatActor.Team.ENEMY)]
	var event: SummonEvent = SummonEvent.new(1, boss, summoned)
	summoned.append(_actor("m2", CombatActor.Team.ENEMY))
	_check("summon_event_targets_is_snapshot", event.summoned_actors.size() == 1)


## Sección 37 — la reacción WET+CHILLED debe seguir agregando exactamente
## WET_FROST_BONUS_STACKS de más (mecánica sin cambios) y last_reaction debe
## reflejar exactamente ese hecho, no uno inventado.
func _test_reaction_wet_chilled_bonus() -> void:
	var statuses: CombatStatusController = CombatStatusController.new()
	var source: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var target: CombatActor = _actor("e", CombatActor.Team.ENEMY, 100, 100)
	statuses.apply_status(target, &"wet", source)
	var chilled: StatusEffectInstance = statuses.apply_status(target, &"chilled", source, 1)
	_check("wet_chilled_stacks_include_bonus", chilled.stacks == 1 + CombatStatusController.WET_FROST_BONUS_STACKS)
	_check("wet_chilled_reaction_occurred", statuses.last_reaction.occurred)
	_check("wet_chilled_reaction_id", statuses.last_reaction.reaction_id == &"wet_frost_bonus")
	_check("wet_chilled_reaction_target", statuses.last_reaction.target_actor == target)
	_check("wet_chilled_reaction_source", statuses.last_reaction.source_actor == source)
	_check("wet_chilled_reaction_bonus_stacks", statuses.last_reaction.bonus_stacks == CombatStatusController.WET_FROST_BONUS_STACKS)


## Sección 37 — WET+SHOCK sigue saltando a un único candidato vivo sin
## Electrocutado ya activo (un solo salto, no cascada); last_reaction debe
## reflejar el salto real ocurrido en _chain_shock(), no el de la llamada
## recursiva interna a apply_status().
func _test_reaction_wet_shock_chain() -> void:
	var statuses: CombatStatusController = CombatStatusController.new()
	var source: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var target: CombatActor = _actor("e1", CombatActor.Team.ENEMY, 100, 100)
	var chain_candidate: CombatActor = _actor("e2", CombatActor.Team.ENEMY, 100, 100)
	var already_shocked: CombatActor = _actor("e3", CombatActor.Team.ENEMY, 100, 100)
	statuses.apply_status(already_shocked, &"shock", source)
	statuses.apply_status(target, &"wet", source)
	statuses.apply_status(target, &"shock", source, 1, -1, [already_shocked, chain_candidate])
	_check("wet_shock_target_has_shock", target.has_status(&"shock"))
	_check("wet_shock_chain_skips_already_shocked", already_shocked.get_status(&"shock").stacks == 1)
	_check("wet_shock_chain_jumps_to_candidate", chain_candidate.has_status(&"shock"))
	_check("wet_shock_reaction_occurred", statuses.last_reaction.occurred)
	_check("wet_shock_reaction_id", statuses.last_reaction.reaction_id == &"wet_shock_chain")
	_check("wet_shock_reaction_target_is_chain_candidate", statuses.last_reaction.target_actor == chain_candidate)
	_check("wet_shock_reaction_not_original_target", statuses.last_reaction.target_actor != target)


## Un apply_status() no relacionado (sin WET) debe resetear last_reaction —
## un consultante inmediatamente después nunca debe ver el resultado de una
## llamada anterior sin relación.
func _test_reaction_reset_between_calls() -> void:
	var statuses: CombatStatusController = CombatStatusController.new()
	var source: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var target: CombatActor = _actor("e", CombatActor.Team.ENEMY, 100, 100)
	statuses.apply_status(target, &"wet", source)
	statuses.apply_status(target, &"chilled", source, 1)
	_check("reaction_present_before_reset", statuses.last_reaction.occurred)
	statuses.apply_status(target, &"burn", source, 1)
	_check("reaction_reset_after_unrelated_call", not statuses.last_reaction.occurred)

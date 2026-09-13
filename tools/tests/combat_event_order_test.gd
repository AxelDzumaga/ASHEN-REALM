extends Node

## Combat Domain M4 — secciones 39 y 40 del handoff: orden/agrupación de
## eventos emitidos por un Combat2D real (no aislado), y cobertura de boss
## (ataque normal, Warden's Rebuke con su propio action_id, transición de
## fase, invocación). Mismo patrón de reflexión que combat_action_atomicity_test.gd
## (M3) y combat_team_defeat_test.gd (M2) — funciones privadas que NO tocan
## CombatTurnController se llaman directamente vía .call(); las que sí
## (_run_companion_turn, _run_enemy_turn) se ejercitan dejando que la ronda
## real corra (_on_attack_pressed + esperar a PLAYER_INPUT), igual que
## ashen_warden_phase3_curse_test.gd.

const COMBAT_SCENE := preload("res://scenes/combat/combat.tscn")
const CALL_EMBERS_ACTION: EnemyActionData = preload("res://data/enemy_actions/call_embers.tres")

var _failures: Array[String] = []
var _seed: int = 900001
var _all_events: Array[RefCounted] = []


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"combat_event_order")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	await _test_basic_attack_event_order()
	await _test_forced_crit_damage_event()
	await _test_affinity_relation_on_damage_event()
	await _test_burning_strike_multi_effect_shares_action_id()
	await _test_death_event_no_duplicate_on_burning_strike_overkill()
	await _test_multi_target_grouping()
	await _test_status_tick_event()
	await _test_status_tick_death_event()
	await _test_companion_turn_action_id_sharing()
	await _test_enemy_turn_action_id_sharing()
	await _test_warden_counter_own_action_id()
	await _test_boss_phase_transition_event()
	await _test_boss_summon_event()
	_test_no_unknown_event_types_across_all_rounds()
	print("[EVENT_ORDER_TEST] failures=%s" % JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(label: String, condition: bool) -> void:
	print("[EVENT_ORDER_TEST] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


func _next_seed() -> int:
	_seed += 1
	return _seed


func _start_normal_combat(with_companion: bool = false) -> Control:
	RunManager.start_new_run(_next_seed())
	RunManager.current_run.biome_data = BiomeCatalog.ASHEN_WASTES
	RunManager.current_run.biome_id = BiomeCatalog.ASHEN_WASTES.id
	RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	if with_companion:
		RunManager.current_run.equipped_companion_id = CompanionCatalog.EMBER_HOUND_ID
	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(BiomeCatalog.ASHEN_WASTES, false, false)
	add_child(combat)
	await _wait_for_player_input(combat, 800)
	return combat


func _start_boss_combat(biome: BiomeData, with_companion: bool = false) -> Control:
	RunManager.start_new_run(_next_seed())
	RunManager.current_run.biome_data = biome
	RunManager.current_run.biome_id = biome.id
	RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	if with_companion:
		RunManager.current_run.equipped_companion_id = CompanionCatalog.EMBER_HOUND_ID
	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(biome, true, false)
	add_child(combat)
	await _wait_for_player_input(combat, 900)
	return combat


func _wait_for_player_input(combat: Control, maximum_frames: int) -> void:
	var frames: int = 0
	while int(combat.get("_phase")) != 1 and not bool(combat.get("_result_resolved")) and frames < maximum_frames:
		await get_tree().process_frame
		frames += 1


func _end_combat(combat: Control) -> void:
	combat.queue_free()
	await get_tree().process_frame
	RunManager.current_run = null


func _listen(combat: Control) -> Array[RefCounted]:
	var events: Array[RefCounted] = []
	var stream: CombatEventStream = combat.get("_event_stream")
	stream.event_emitted.connect(func(event: RefCounted) -> void:
		events.append(event)
		_all_events.append(event)
	)
	return events


func _of_type(events: Array[RefCounted], type_check: Callable) -> Array:
	return events.filter(type_check)


## §39 — ataque básico normal: exactamente 1 ActionEvent(basic_attack) + 1
## DamageEvent, mismo action_id, sin equipo/boons que agreguen efectos extra.
func _test_basic_attack_event_order() -> void:
	var combat: Control = await _start_normal_combat()
	var events: Array[RefCounted] = _listen(combat)
	var player: CombatActor = combat.get("player_actor")
	var enemy: CombatActor = combat.get("enemy_actor")
	var enemy_hp_before: int = enemy.get_current_hp()
	var resolved: bool = await combat.call("_run_player_basic_action", enemy)
	_check("basic_attack_no_terminal_flow", not resolved)
	_check("basic_attack_exactly_one_action_event", _of_type(events, func(e): return e is ActionEvent).size() == 1)
	var action_event: ActionEvent = events[0]
	_check("basic_attack_is_first_event", action_event is ActionEvent)
	_check("basic_attack_action_kind", action_event.action_kind == &"basic_attack")
	_check("basic_attack_source_is_player", action_event.source_actor == player)
	_check("basic_attack_targets_enemy", action_event.targets == [enemy])
	var damage_events: Array = _of_type(events, func(e): return e is DamageEvent)
	_check("basic_attack_exactly_one_damage_event", damage_events.size() == 1)
	var damage_event: DamageEvent = damage_events[0]
	_check("basic_attack_damage_shares_action_id", damage_event.action_id == action_event.action_id)
	_check("basic_attack_damage_hp_before_matches", damage_event.hp_before == enemy_hp_before)
	_check("basic_attack_damage_hp_after_matches_actual", damage_event.hp_after == enemy.get_current_hp())
	await _end_combat(combat)


## §39 — crítico forzado: el flag is_critical del DamageEvent debe reflejarlo.
func _test_forced_crit_damage_event() -> void:
	var combat: Control = await _start_normal_combat()
	RunManager.current_run.equipment_crit_chance = 1.0
	RunManager.current_run.equipment_crit_damage_bonus = 0.0
	var events: Array[RefCounted] = _listen(combat)
	var enemy: CombatActor = combat.get("enemy_actor")
	await combat.call("_run_player_basic_action", enemy)
	var damage_events: Array = _of_type(events, func(e): return e is DamageEvent)
	_check("crit_damage_event_present", damage_events.size() >= 1)
	_check("crit_damage_event_flagged_critical", damage_events[0].is_critical)
	await _end_combat(combat)


## §39 — afinidad: DamageEvent.affinity_relation refleja exactamente la
## relación ya evaluada por AffinityResolver (nunca recalculada acá).
func _test_affinity_relation_on_damage_event() -> void:
	var combat: Control = await _start_normal_combat()
	RunManager.current_run.equipped_weapon_id = &"ember_fang"
	var events: Array[RefCounted] = _listen(combat)
	var enemy: CombatActor = combat.get("enemy_actor")
	var weak_enemy_data := EnemyData.new()
	weak_enemy_data.weakness_tags = [&"ember"]
	enemy.source_data = weak_enemy_data
	await combat.call("_run_player_basic_action", enemy)
	var damage_events: Array = _of_type(events, func(e): return e is DamageEvent)
	_check("affinity_damage_event_present", damage_events.size() >= 1)
	_check("affinity_relation_is_weak", damage_events[0].affinity_relation == &"weak")
	await _end_combat(combat)


## §39 — Burning Strike: golpe principal + bonus de Burning Strike + burn
## aplicado, todos bajo el MISMO action_id, en el orden de ejecución real.
func _test_burning_strike_multi_effect_shares_action_id() -> void:
	var combat: Control = await _start_normal_combat()
	RunManager.current_run.add_boon(&"burning_strike")
	# after_player_attack() solo dispara Burning Strike cada 3er ataque
	# (_attack_count % 3 == 0) — se fuerza el contador para no depender de
	# repetir el ataque 3 veces en este test de forma/orden.
	combat.get("_boons").set("_attack_count", 2)
	var events: Array[RefCounted] = _listen(combat)
	var enemy: CombatActor = combat.get("enemy_actor")
	enemy.set_current_hp(enemy.get_max_hp())
	await combat.call("_run_player_basic_action", enemy)
	var action_events: Array = _of_type(events, func(e): return e is ActionEvent)
	_check("burning_strike_one_action_event", action_events.size() == 1)
	var action_id: int = action_events[0].action_id
	var damage_events: Array = _of_type(events, func(e): return e is DamageEvent)
	_check("burning_strike_two_damage_events", damage_events.size() == 2)
	for damage_event: DamageEvent in damage_events:
		_check("burning_strike_damage_shares_action_id", damage_event.action_id == action_id)
	var status_events: Array = _of_type(events, func(e): return e is StatusEvent and e.kind == StatusEvent.Kind.APPLIED)
	var burn_events: Array = status_events.filter(func(e): return e.status_id == &"burn")
	_check("burning_strike_burn_applied_event_present", burn_events.size() == 1)
	_check("burning_strike_burn_shares_action_id", burn_events[0].action_id == action_id)
	# Orden real: ActionEvent, DamageEvent(golpe principal), DamageEvent(bonus), StatusEvent(burn).
	_check("burning_strike_event_order", events[0] is ActionEvent and events[1] is DamageEvent and events[2] is DamageEvent and events[3] is StatusEvent)
	await _end_combat(combat)


## §16 override — un golpe de Burning Strike que llega DESPUÉS de que el
## golpe principal ya mató al objetivo no debe reportar un segundo DeathEvent
## (hp_before de ese segundo golpe ya es 0, caused_death debe quedar false).
func _test_death_event_no_duplicate_on_burning_strike_overkill() -> void:
	var combat: Control = await _start_normal_combat()
	RunManager.current_run.add_boon(&"burning_strike")
	RunManager.current_run.equipment_crit_chance = 1.0
	var events: Array[RefCounted] = _listen(combat)
	var enemy: CombatActor = combat.get("enemy_actor")
	enemy.set_current_hp(1)
	await combat.call("_run_player_basic_action", enemy)
	_check("overkill_enemy_is_dead", not enemy.is_alive())
	var death_events: Array = _of_type(events, func(e): return e is DeathEvent)
	_check("overkill_exactly_one_death_event", death_events.size() == 1)
	_check("overkill_death_event_targets_enemy", death_events.is_empty() or death_events[0].actor == enemy)
	await _end_combat(combat)


## §39/§44 — multi-target: 1 ActionEvent + N DamageEvent, mismo action_id,
## cada target vivo afectado exactamente una vez, orden estable.
func _test_multi_target_grouping() -> void:
	var combat: Control = await _start_normal_combat()
	var first_enemy: CombatActor = combat.get("enemy_actor")
	var enemy_data: EnemyData = preload("res://data/enemies/ash_crawler.tres")
	var second_enemy: CombatActor = CombatActor.from_enemy(&"enemy_synthetic_1", enemy_data, CombatActor.ActorType.NORMAL_ENEMY)
	second_enemy.formation_slot = 1
	var enemy_actors: Array = combat.get("enemy_actors")
	enemy_actors.append(second_enemy)
	var events: Array[RefCounted] = _listen(combat)
	var skill_data: ActiveSkillData = ActiveSkillData.new()
	skill_data.id = &"test_all_enemies_nuke"
	skill_data.display_name = "Test Nuke"
	skill_data.skill_type = ActiveSkillData.SkillType.DAMAGE
	skill_data.target_type = ActiveSkillData.TargetType.ALL_ENEMIES
	skill_data.energy_cost = 50
	skill_data.cooldown_turns = 2
	skill_data.damage_multiplier = 1.0
	skill_data.enabled = true
	var controller: ActiveSkillController = ActiveSkillController.new(skill_data, RunManager.current_run)
	var targets: Array[CombatActor] = [first_enemy, second_enemy]
	var resolved: bool = await combat.call("_execute_active_skill_multi_target", controller, targets)
	_check("multi_target_no_terminal_flow", not resolved)
	var action_events: Array = _of_type(events, func(e): return e is ActionEvent)
	_check("multi_target_exactly_one_action_event", action_events.size() == 1)
	_check("multi_target_action_targets_both", action_events[0].targets.size() == 2)
	var damage_events: Array = _of_type(events, func(e): return e is DamageEvent)
	_check("multi_target_exactly_two_damage_events", damage_events.size() == 2)
	for damage_event: DamageEvent in damage_events:
		_check("multi_target_damage_shares_action_id", damage_event.action_id == action_events[0].action_id)
	_check("multi_target_first_damage_target", damage_events[0].target_actor == first_enemy)
	_check("multi_target_second_damage_target", damage_events[1].target_actor == second_enemy)
	await _end_combat(combat)


## §39 — tick de estado de inicio de turno: StatusEvent(kind=TICK) con
## NO_ACTION_ID (ningún action_id lo causó — es pasivo), tick_damage real.
func _test_status_tick_event() -> void:
	var combat: Control = await _start_normal_combat()
	var player: CombatActor = combat.get("player_actor")
	var statuses: CombatStatusController = combat.get("_statuses")
	statuses.apply_status(player, &"burn", combat.get("enemy_actor"), 1)
	var events: Array[RefCounted] = _listen(combat)
	var hp_before: int = player.get_current_hp()
	await combat.call("_process_actor_turn_start", player)
	var tick_events: Array = _of_type(events, func(e): return e is StatusEvent and e.kind == StatusEvent.Kind.TICK)
	_check("status_tick_event_emitted", tick_events.size() == 1)
	var tick_event: StatusEvent = tick_events[0]
	_check("status_tick_uses_no_action_id", tick_event.action_id == CombatEventStream.NO_ACTION_ID)
	_check("status_tick_status_id", tick_event.status_id == &"burn")
	_check("status_tick_damage_matches_hp_loss", tick_event.tick_damage == hp_before - player.get_current_hp())
	await _end_combat(combat)


## §39 — si el tick de inicio de turno mata al actor, se emite un DeathEvent
## (hp_before>0, hp_after<=0), también con NO_ACTION_ID.
func _test_status_tick_death_event() -> void:
	var combat: Control = await _start_normal_combat()
	var player: CombatActor = combat.get("player_actor")
	var enemy: CombatActor = combat.get("enemy_actor")
	var statuses: CombatStatusController = combat.get("_statuses")
	player.set_current_hp(1)
	statuses.apply_status(player, &"burn", enemy, 5)
	var events: Array[RefCounted] = _listen(combat)
	var died: bool = await combat.call("_process_actor_turn_start", player)
	_check("status_tick_death_actor_died", died)
	var death_events: Array = _of_type(events, func(e): return e is DeathEvent)
	_check("status_tick_death_event_emitted", death_events.size() == 1)
	_check("status_tick_death_uses_no_action_id", death_events.is_empty() or death_events[0].action_id == CombatEventStream.NO_ACTION_ID)
	_check("status_tick_death_actor_is_player", death_events.is_empty() or death_events[0].actor == player)
	await _end_combat(combat)


## §39 — turno de compañero: se deja correr una ronda real (mismo patrón que
## ashen_warden_phase3_curse_test.gd) porque _run_companion_turn() sí avanza
## CombatTurnController internamente — llamarla por reflexión directamente
## desestabilizaría el estado del controller sin beneficio adicional.
func _test_companion_turn_action_id_sharing() -> void:
	var combat: Control = await _start_normal_combat(true)
	var companion_actor: CombatActor = combat.get("companion_actor")
	_check("companion_present_for_turn_test", companion_actor != null and companion_actor.is_alive())
	if companion_actor == null:
		return
	var events: Array[RefCounted] = _listen(combat)
	combat.call("_on_attack_pressed")
	await _wait_for_player_input(combat, 900)
	var companion_action_events: Array = _of_type(events, func(e): return e is ActionEvent and e.source_actor == companion_actor)
	_check("companion_turn_exactly_one_action_event", companion_action_events.size() == 1)
	var action_event: ActionEvent = companion_action_events[0]
	_check("companion_turn_action_kind_valid", action_event.action_kind == &"companion_ability" or action_event.action_kind == &"companion_attack")
	var companion_damage_events: Array = _of_type(events, func(e): return e is DamageEvent and e.source_actor == companion_actor)
	_check("companion_turn_has_damage_event", companion_damage_events.size() == 1)
	_check("companion_turn_damage_shares_action_id", companion_damage_events[0].action_id == action_event.action_id)
	await _end_combat(combat)


## §39 — turno de enemigo: mismo motivo que el de compañero, se deja correr
## la ronda real en vez de llamar _run_enemy_turn() directamente.
func _test_enemy_turn_action_id_sharing() -> void:
	var combat: Control = await _start_normal_combat()
	var enemy: CombatActor = combat.get("enemy_actor")
	var events: Array[RefCounted] = _listen(combat)
	combat.call("_on_attack_pressed")
	await _wait_for_player_input(combat, 900)
	var enemy_action_events: Array = _of_type(events, func(e): return e is ActionEvent and e.action_kind == &"enemy_action")
	_check("enemy_turn_exactly_one_action_event", enemy_action_events.size() == 1)
	var enemy_damage_events: Array = _of_type(events, func(e): return e is DamageEvent and e.source_actor == enemy)
	_check("enemy_turn_has_damage_event", enemy_damage_events.size() >= 1)
	for damage_event: DamageEvent in enemy_damage_events:
		_check("enemy_turn_damage_shares_action_id", damage_event.action_id == enemy_action_events[0].action_id)
	await _end_combat(combat)


## §40 — Warden's Rebuke DEBE recibir un action_id nuevo, distinto del
## ataque básico que lo disparó. _resolve_warden_counter() no toca
## CombatTurnController (verificado en el handoff), así que se puede llamar
## vía reflexión inmediatamente después del ataque básico, sin dejar correr
## una ronda completa.
func _test_warden_counter_own_action_id() -> void:
	var combat: Control = await _start_boss_combat(BiomeCatalog.ASHEN_WASTES)
	var boss_actor: CombatActor = combat.get("_boss_actor")
	var boss_controller: BossEncounterController = combat.get("_boss_controller")
	boss_controller.runtime.counter_armed = true
	var events: Array[RefCounted] = _listen(combat)
	await combat.call("_run_player_basic_action", boss_actor)
	var action_events: Array = _of_type(events, func(e): return e is ActionEvent)
	_check("warden_counter_two_action_events", action_events.size() == 2)
	if action_events.size() == 2:
		_check("warden_counter_first_is_basic_attack", action_events[0].action_kind == &"basic_attack")
		_check("warden_counter_second_is_boss_counter", action_events[1].action_kind == &"boss_counter")
		_check("warden_counter_has_new_action_id", action_events[1].action_id != action_events[0].action_id)
	var counter_damage_events: Array = _of_type(events, func(e): return e is DamageEvent and e.source_actor == boss_actor)
	_check("warden_counter_damage_event_present", counter_damage_events.size() == 1)
	if action_events.size() == 2:
		_check("warden_counter_damage_shares_counter_action_id", counter_damage_events[0].action_id == action_events[1].action_id)
	await _end_combat(combat)


## §40 — transición de fase real de un boss de catálogo (Sunken Pyre, fase
## "pyre_opens" al 70% de HP) disparada bajando el HP directamente y
## llamando _check_boss_phase_transition() — sin recorrer 60 turnos.
func _test_boss_phase_transition_event() -> void:
	var combat: Control = await _start_boss_combat(BiomeCatalog.EMBER_MARSH)
	var boss_actor: CombatActor = combat.get("_boss_actor")
	var boss_controller: BossEncounterController = combat.get("_boss_controller")
	_check("boss_phase_test_correct_boss", boss_controller.data.boss_id == &"sunken_pyre")
	boss_actor.set_current_hp(roundi(float(boss_actor.get_max_hp()) * 0.65))
	var events: Array[RefCounted] = _listen(combat)
	await combat.call("_check_boss_phase_transition")
	var phase_events: Array = _of_type(events, func(e): return e is BossPhaseEvent)
	_check("boss_phase_event_emitted_exactly_once", phase_events.size() == 1)
	if not phase_events.is_empty():
		var phase_event: BossPhaseEvent = phase_events[0]
		_check("boss_phase_event_correct_phase", phase_event.current_phase.phase_id == &"pyre_opens")
		_check("boss_phase_event_boss_actor_matches", phase_event.boss_actor == boss_actor)
		_check("boss_phase_event_uses_no_action_id", phase_event.action_id == CombatEventStream.NO_ACTION_ID)
	await _end_combat(combat)


## §40 — invocación de boss: ActionEvent(boss_summon) + SummonEvent, mismo
## action_id, summoned_actors coincide exactamente con lo agregado a
## enemy_actors. Reusa la transición de fase real (pyre_opens) para dejar
## pending_summon_phase_index/pending_summon_count en el estado que
## _run_boss_summon_action() espera, sin fabricar datos sintéticos.
func _test_boss_summon_event() -> void:
	var combat: Control = await _start_boss_combat(BiomeCatalog.EMBER_MARSH)
	var boss_actor: CombatActor = combat.get("_boss_actor")
	var boss_controller: BossEncounterController = combat.get("_boss_controller")
	boss_actor.set_current_hp(roundi(float(boss_actor.get_max_hp()) * 0.65))
	await combat.call("_check_boss_phase_transition")
	var enemies_before: int = (combat.get("enemy_actors") as Array).size()
	var events: Array[RefCounted] = _listen(combat)
	var ai_state: EnemyAIRuntimeState = EnemyAIRuntimeState.new()
	await combat.call("_run_boss_summon_action", boss_actor, CALL_EMBERS_ACTION, ai_state)
	var action_events: Array = _of_type(events, func(e): return e is ActionEvent and e.action_kind == &"boss_summon")
	_check("boss_summon_action_event_emitted", action_events.size() == 1)
	var summon_events: Array = _of_type(events, func(e): return e is SummonEvent)
	_check("boss_summon_event_emitted", summon_events.size() == 1)
	if action_events.size() == 1 and summon_events.size() == 1:
		_check("boss_summon_shares_action_id", summon_events[0].action_id == action_events[0].action_id)
		_check("boss_summon_count_matches_data", summon_events[0].summoned_actors.size() == 2)
		var enemy_actors_after: Array = combat.get("enemy_actors")
		_check("boss_summon_actually_added_enemies", enemy_actors_after.size() == enemies_before + 2)
		var all_present: bool = true
		for summoned_actor: CombatActor in summon_events[0].summoned_actors:
			if not enemy_actors_after.has(summoned_actor):
				all_present = false
		_check("boss_summon_summoned_actors_are_real_enemy_actors", all_present)
	await _end_combat(combat)


## §47 — ningún evento capturado en toda la corrida de este archivo es de un
## tipo fuera de los 8 autorizados (en particular: no hay Victory/Defeat ni
## Energy/Cooldown, porque esas clases simplemente no existen en el dominio).
func _test_no_unknown_event_types_across_all_rounds() -> void:
	var all_known: bool = true
	for event: RefCounted in _all_events:
		if not (
			event is ActionEvent or event is DamageEvent or event is HealEvent
			or event is StatusEvent or event is ReactionEvent or event is DeathEvent
			or event is BossPhaseEvent or event is SummonEvent
		):
			all_known = false
	_check("no_unknown_event_types_emitted", all_known)
	_check("at_least_some_events_were_captured", not _all_events.is_empty())

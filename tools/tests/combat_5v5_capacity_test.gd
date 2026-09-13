extends Node

## Combat Domain M5 — secciones 40-46 del handoff: capacidad N-actor/5v5
## contra un Combat2D real, con actores sintéticos (sin contenido de
## producción nuevo). Mismo patrón de reflexión que
## combat_action_atomicity_test.gd (M3)/combat_team_defeat_test.gd (M2)/
## combat_event_order_test.gd (M4).
##
## _ally_data_override (combat.gd, M5) es el seam de inyección de test para
## el lado jugador — producción sigue pasando 0/1 CompanionData real. El
## lado enemigo no tiene un seam equivalente todavía, así que se usa el
## mismo patrón ya establecido en M3/M4 (_add_synthetic_enemy: agregar
## CombatActor.from_enemy() directamente a enemy_actors antes de que la
## ronda entre en su bloque de Enemy Team).

const COMBAT_SCENE := preload("res://scenes/combat/combat.tscn")
const ASH_CRAWLER: EnemyData = preload("res://data/enemies/ash_crawler.tres")
const WARDEN: EnemyData = preload("res://data/enemies/bosses/ashen_warden.tres")
const CALL_EMBERS_ACTION: EnemyActionData = preload("res://data/enemy_actions/call_embers.tres")

var _failures: Array[String] = []
var _seed: int = 950001


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"combat_5v5_capacity")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	await _test_5v5_turn_sequence()
	await _test_5v5_multi_target_grouping()
	await _test_companion_runtime_isolation()
	await _test_player_down_routing()
	await _test_boss_cap_no_sixth_actor()
	await _test_5v5_team_defeat_both_sides()
	await _test_no_crash_full_5v5_round()
	print("[COMBAT_5V5_TEST] failures=%s" % JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(label: String, condition: bool) -> void:
	print("[COMBAT_5V5_TEST] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


func _next_seed() -> int:
	_seed += 1
	return _seed


func _synthetic_ally_data(id: String, ability_every_actions: int = 3) -> CompanionData:
	var data: CompanionData = CompanionData.new()
	data.companion_id = StringName(id)
	data.display_name = id
	data.max_hp = 40
	data.attack = 8
	data.defense = 2
	data.ability_id = StringName("%s_ability" % id)
	data.ability_name = "%s ABILITY" % id
	data.ability_every_actions = ability_every_actions
	data.ability_status_id = &""
	return data


func _wait_for_player_input(combat: Control, maximum_frames: int) -> void:
	var frames: int = 0
	while int(combat.get("_phase")) != 1 and not bool(combat.get("_result_resolved")) and frames < maximum_frames:
		await get_tree().process_frame
		frames += 1


func _end_combat(combat: Control) -> void:
	combat.queue_free()
	await get_tree().process_frame
	RunManager.current_run = null


## Arma un combate normal con `ally_count` AI_ALLY sintéticos (vía
## _ally_data_override, construidos por el propio combat.gd) y agrega
## `extra_enemy_count` enemigos sintéticos más al único enemigo real ya
## generado — Player Team y Enemy Team terminan en `1 + ally_count` y
## `1 + extra_enemy_count` respectivamente.
func _start_synthetic_combat(ally_count: int, extra_enemy_count: int, is_boss: bool = false, biome: BiomeData = null) -> Control:
	RunManager.start_new_run(_next_seed())
	if biome == null:
		biome = BiomeCatalog.ASHEN_WASTES
	RunManager.current_run.biome_data = biome
	RunManager.current_run.biome_id = biome.id
	RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	var combat: Control = COMBAT_SCENE.instantiate()
	var ally_data_list: Array[CompanionData] = []
	for ally_index: int in range(ally_count):
		ally_data_list.append(_synthetic_ally_data("a%d" % (ally_index + 1)))
	combat.set("_ally_data_override", ally_data_list)
	combat.configure(biome, is_boss, false)
	add_child(combat)
	await _wait_for_player_input(combat, 900)
	var enemy_actors: Array = combat.get("enemy_actors")
	# CombatRules.find_available_formation_slots() en vez de enemy_actors.size():
	# en un combate de boss, _initialize_boss_encounter() ya reasignó
	# formation_slot=1 al boss DESPUÉS de la asignación inicial por índice —
	# usar .size() a ciegas colisionaría con ese slot 1 ya ocupado.
	var occupied_slots: Array[int] = []
	for occupying_actor: CombatActor in enemy_actors:
		occupied_slots.append(occupying_actor.formation_slot)
	var free_slots: Array[int] = CombatRules.find_available_formation_slots(occupied_slots, extra_enemy_count)
	for extra_index: int in range(extra_enemy_count):
		var extra: CombatActor = CombatActor.from_enemy(
			StringName("enemy_synthetic_%d" % extra_index), ASH_CRAWLER, CombatActor.ActorType.NORMAL_ENEMY,
		)
		extra.formation_slot = free_slots[extra_index]
		enemy_actors.append(extra)
	if extra_enemy_count > 0:
		# §49 — a diferencia del lado jugador (§23/§24, sin vista dedicada
		# por diseño en M5), el lado enemigo SÍ debe quedar funcionalmente
		# visible: _build_enemy_slots() ya es la función real que
		# combat.gd usa para reconstruir EnemyCombatSlot/CombatCharacterView
		# tras un boss summon (_activate_boss_formation()) — se reusa acá
		# para que los enemigos sintéticos agregados post-setup puedan
		# actuar (atacar) en un round real sin visual_view nulo.
		combat.call("_build_enemy_slots")
	return combat


## §40 — orden de ronda 5v5: Player Team P0,A1,A2,A3,A4 vs Enemy Team
## E0,E1,E2,E3,E4, cada uno exactamente una vez, orden estable. Se conecta
## el listener recién en el primer PLAYER_INPUT (el turno de P0 ya empezó,
## ver comentario abajo) y se deja correr UNA ronda completa real.
func _test_5v5_turn_sequence() -> void:
	var combat: Control = await _start_synthetic_combat(4, 4)
	var player_actors: Array = combat.get("player_actors")
	var enemy_actors: Array = combat.get("enemy_actors")
	_check("turn_sequence_player_team_is_five", player_actors.size() == 5)
	_check("turn_sequence_enemy_team_is_five", enemy_actors.size() == 5)
	var turn_controller: CombatTurnController = combat.get("_turn_controller")
	var observed_order: Array[StringName] = []
	# El turno de P0 (ronda 1) ya arrancó antes de que este test pueda
	# conectarse (start() dispara _select_next_actor() de forma síncrona,
	# sin ningún await de por medio) — por eso la secuencia observada
	# empieza en A1 y termina con P0 reapareciendo al inicio de la ronda 2,
	# en vez de con P0 al principio. Eso todavía prueba el contrato completo:
	# cada actor exactamente una vez, orden estable, y el wraparound a P0
	# confirma que la ronda 1 se cerró limpio.
	turn_controller.actor_turn_started.connect(func(actor: CombatActor) -> void: observed_order.append(actor.actor_id))
	combat.call("_on_attack_pressed")
	await _wait_for_player_input(combat, 900)
	var expected_order: Array[StringName] = [
		&"companion_0", &"companion_1", &"companion_2", &"companion_3",
		&"enemy_0", &"enemy_synthetic_0", &"enemy_synthetic_1", &"enemy_synthetic_2", &"enemy_synthetic_3",
		&"player_0",
	]
	_check("turn_sequence_matches_expected_order", observed_order == expected_order)
	await _end_combat(combat)


## §32/§33 — multi-target 5v5: una skill sintética ALL_ENEMIES contra 5
## enemigos vivos aplica el efecto una vez a cada uno, un solo costo/cooldown,
## y M4 agrupa 1 ActionEvent + 5 DamageEvent bajo el mismo action_id.
func _test_5v5_multi_target_grouping() -> void:
	var combat: Control = await _start_synthetic_combat(0, 4)
	var enemy_actors: Array[CombatActor] = combat.get("enemy_actors")
	_check("multi_target_5v5_enemy_team_is_five", enemy_actors.size() == 5)
	var events: Array[RefCounted] = []
	var stream: CombatEventStream = combat.get("_event_stream")
	stream.event_emitted.connect(func(event: RefCounted) -> void: events.append(event))
	var skill_loadout: CombatSkillController = combat.get("_skill_loadout")
	skill_loadout.debug_fill_energy()
	var skill_data: ActiveSkillData = ActiveSkillData.new()
	skill_data.id = &"test_5v5_nuke"
	skill_data.display_name = "Test 5v5 Nuke"
	skill_data.skill_type = ActiveSkillData.SkillType.DAMAGE
	skill_data.target_type = ActiveSkillData.TargetType.ALL_ENEMIES
	skill_data.energy_cost = 50
	skill_data.cooldown_turns = 2
	skill_data.damage_multiplier = 1.0
	skill_data.enabled = true
	var controller: ActiveSkillController = ActiveSkillController.new(skill_data, RunManager.current_run)
	var hp_before: Array[int] = []
	for enemy: CombatActor in enemy_actors:
		hp_before.append(enemy.get_current_hp())
	var energy_before: int = skill_loadout.current_energy
	var used: bool = skill_loadout.try_use(controller)
	_check("multi_target_5v5_try_use_succeeded", used)
	_check("multi_target_5v5_cost_paid_once", energy_before - skill_loadout.current_energy == skill_data.energy_cost)
	_check("multi_target_5v5_cooldown_activated_once", controller.cooldown_remaining == skill_data.cooldown_turns)
	var resolved: bool = await combat.call("_execute_active_skill_multi_target", controller, enemy_actors.duplicate())
	_check("multi_target_5v5_no_terminal_flow", not resolved)
	var all_damaged: bool = true
	for index: int in range(enemy_actors.size()):
		if enemy_actors[index].get_current_hp() >= hp_before[index]:
			all_damaged = false
	_check("multi_target_5v5_all_five_damaged_once", all_damaged)
	var action_events: Array = events.filter(func(e): return e is ActionEvent)
	_check("multi_target_5v5_exactly_one_action_event", action_events.size() == 1)
	_check("multi_target_5v5_action_targets_all_five", action_events[0].targets.size() == 5)
	var damage_events: Array = events.filter(func(e): return e is DamageEvent)
	_check("multi_target_5v5_exactly_five_damage_events", damage_events.size() == 5)
	var same_action_id: bool = true
	for damage_event: DamageEvent in damage_events:
		if damage_event.action_id != action_events[0].action_id:
			same_action_id = false
	_check("multi_target_5v5_damage_shares_action_id", same_action_id)
	await _end_combat(combat)


## §14/§41 — dos AI_ALLY con cadences distintas no deben pisarse el
## CompanionRuntimeState entre sí. Se deja correr UNA ronda real (ambos
## actúan) y se confirma que cada actor_id avanzó su propio contador.
func _test_companion_runtime_isolation() -> void:
	var combat: Control = await _start_synthetic_combat(2, 0)
	var companion_runtimes: Dictionary = combat.get("_companion_runtimes")
	var player_actors: Array[CombatActor] = combat.get("player_actors")
	var ally1: CombatActor = player_actors[1]
	var ally2: CombatActor = player_actors[2]
	_check("isolation_two_distinct_runtime_objects", companion_runtimes[ally1.actor_id] != companion_runtimes[ally2.actor_id])
	_check("isolation_both_start_at_zero", companion_runtimes[ally1.actor_id].actions_completed == 0 and companion_runtimes[ally2.actor_id].actions_completed == 0)
	combat.call("_on_attack_pressed")
	await _wait_for_player_input(combat, 900)
	_check("isolation_ally1_acted_exactly_once", companion_runtimes[ally1.actor_id].actions_completed == 1)
	_check("isolation_ally2_acted_exactly_once", companion_runtimes[ally2.actor_id].actions_completed == 1)
	await _end_combat(combat)


## §21/§22/§42 — el bug auditado: un 3er+ Player Team actor muriendo no debe
## marcar death_presented en otro actor, y una muerte real posterior del
## protagonista debe seguir presentándose con normalidad.
func _test_player_down_routing() -> void:
	var combat: Control = await _start_synthetic_combat(2, 0)
	var player_actor: CombatActor = combat.get("player_actor")
	var player_actors: Array[CombatActor] = combat.get("player_actors")
	var ally1: CombatActor = player_actors[1]
	var ally2: CombatActor = player_actors[2]
	_check("routing_all_start_unpresented", not player_actor.death_presented and not ally1.death_presented and not ally2.death_presented)
	# §23 — ally2 (2do aliado sintético) nunca recibe visual_view propio
	# (solo el primer aliado hereda companion_view) — esto ejercita
	# exactamente el camino "sin vista dedicada" sin crashear.
	_check("routing_ally2_has_no_dedicated_view", ally2.visual_view == null)
	await combat.call("_present_player_team_actor_down", ally2)
	_check("routing_ally2_death_presented", ally2.death_presented)
	_check("routing_player_not_presented_after_ally2_death", not player_actor.death_presented)
	_check("routing_ally1_not_presented_after_ally2_death", not ally1.death_presented)
	await combat.call("_present_player_team_actor_down", player_actor)
	_check("routing_player_death_still_presents_normally", player_actor.death_presented)
	await _end_combat(combat)


## §18/§19/§43 — Enemy Team ya en el tope (boss + 4 = 5): un intento de
## invocación no debe crear un sexto actor, no debe emitir ActionEvent ni
## SummonEvent (nada pasó de verdad), y el turno del boss debe resolverse
## sin error. Usa el boss real Sunken Pyre (Ember Marsh) — su fase 2 real
## ("pyre_opens", 70% HP) ya trae summon_data configurado de catálogo
## (mismo boss/mecanismo que combat_event_order_test.gd en M4) — nunca se
## muta un BossPhaseData cargado, que quedaría corrupto para el resto del
## proceso.
func _test_boss_cap_no_sixth_actor() -> void:
	var combat: Control = await _start_synthetic_combat(0, 0, true, BiomeCatalog.EMBER_MARSH)
	var boss_actor: CombatActor = combat.get("_boss_actor")
	var boss_controller: BossEncounterController = combat.get("_boss_controller")
	_check("boss_cap_boss_present", boss_actor != null)
	if boss_actor == null:
		await _end_combat(combat)
		return
	var enemy_actors: Array = combat.get("enemy_actors")
	var occupied_slots: Array[int] = []
	for occupying_actor: CombatActor in enemy_actors:
		occupied_slots.append(occupying_actor.formation_slot)
	# El boss ya ocupa formation_slot=1 (_initialize_boss_encounter()) —
	# find_available_formation_slots() evita colisionar con él, a
	# diferencia de asignar por enemy_actors.size() a ciegas.
	var free_slots: Array[int] = CombatRules.find_available_formation_slots(occupied_slots, 4)
	for extra_index: int in range(4):
		var extra: CombatActor = CombatActor.from_enemy(
			StringName("enemy_cap_filler_%d" % extra_index), ASH_CRAWLER, CombatActor.ActorType.MINION,
		)
		extra.formation_slot = free_slots[extra_index]
		enemy_actors.append(extra)
	_check("boss_cap_enemy_team_at_five", enemy_actors.size() == 5)
	boss_actor.set_current_hp(roundi(float(boss_actor.get_max_hp()) * 0.65))
	await combat.call("_check_boss_phase_transition")
	_check("boss_cap_pending_summon_ready", boss_controller.get_pending_summon_phase() != null)
	var events: Array[RefCounted] = []
	var stream: CombatEventStream = combat.get("_event_stream")
	stream.event_emitted.connect(func(event: RefCounted) -> void: events.append(event))
	var ai_state: EnemyAIRuntimeState = EnemyAIRuntimeState.new()
	await combat.call("_run_boss_summon_action", boss_actor, CALL_EMBERS_ACTION, ai_state)
	_check("boss_cap_no_sixth_actor_added", (combat.get("enemy_actors") as Array).size() == 5)
	_check("boss_cap_no_action_event_emitted", events.filter(func(e): return e is ActionEvent).is_empty())
	_check("boss_cap_no_summon_event_emitted", events.filter(func(e): return e is SummonEvent).is_empty())
	var seen_formation_slots: Array[int] = []
	var no_duplicate_slots: bool = true
	for actor: CombatActor in (combat.get("enemy_actors") as Array[CombatActor]):
		if actor.formation_slot in seen_formation_slots:
			no_duplicate_slots = false
		seen_formation_slots.append(actor.formation_slot)
	_check("boss_cap_no_duplicate_formation_slot", no_duplicate_slots)
	await _end_combat(combat)


## §37/§45 — derrota/victoria a 5 actores por lado: solo el último actor de
## cada equipo determina el resultado, nunca uno intermedio.
func _test_5v5_team_defeat_both_sides() -> void:
	var combat: Control = await _start_synthetic_combat(4, 4)
	var player_actors: Array[CombatActor] = combat.get("player_actors")
	var enemy_actors: Array[CombatActor] = combat.get("enemy_actors")
	_check("defeat_5v5_player_team_is_five", player_actors.size() == 5)
	_check("defeat_5v5_enemy_team_is_five", enemy_actors.size() == 5)
	for index: int in range(4):
		player_actors[index].set_current_hp(0)
		_check(
			"defeat_5v5_player_not_defeated_after_%d_deaths" % (index + 1),
			not CombatTeamUtils.is_defeated(player_actors),
		)
	player_actors[4].set_current_hp(0)
	_check("defeat_5v5_player_defeated_after_fifth_death", CombatTeamUtils.is_defeated(player_actors))
	for index: int in range(4):
		enemy_actors[index].set_current_hp(0)
		_check(
			"defeat_5v5_enemy_not_defeated_after_%d_deaths" % (index + 1),
			not CombatTeamUtils.is_defeated(enemy_actors),
		)
	enemy_actors[4].set_current_hp(0)
	_check("defeat_5v5_enemy_defeated_after_fifth_death", CombatTeamUtils.is_defeated(enemy_actors))
	await _end_combat(combat)


## §46 — fixture de ingeniería: 5v5 real completo (construcción, un round
## completo, targeting, intents, eventos M4, sin crash/deadlock). Se corre
## tanto headless como no-headless (ver runner) contra el mismo archivo.
func _test_no_crash_full_5v5_round() -> void:
	var combat: Control = await _start_synthetic_combat(4, 4)
	var player_actors: Array = combat.get("player_actors")
	var enemy_actors: Array = combat.get("enemy_actors")
	_check("no_crash_setup_player_team_five", player_actors.size() == 5)
	_check("no_crash_setup_enemy_team_five", enemy_actors.size() == 5)
	var validation_events: Array[RefCounted] = []
	var stream: CombatEventStream = combat.get("_event_stream")
	stream.event_emitted.connect(func(event: RefCounted) -> void: validation_events.append(event))
	combat.call("_on_attack_pressed")
	await _wait_for_player_input(combat, 900)
	_check("no_crash_reached_next_player_input", int(combat.get("_phase")) == 1)
	_check("no_crash_combat_not_resolved", not bool(combat.get("_result_resolved")))
	_check("no_crash_events_were_emitted", not validation_events.is_empty())
	await _end_combat(combat)

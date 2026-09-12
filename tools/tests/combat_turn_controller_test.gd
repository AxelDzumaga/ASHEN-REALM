extends Node

## Combat Domain M1 — pruebas de dominio directas para CombatTurnController,
## sin necesidad de instanciar Combat2D (sección 26 del handoff M1). Los
## CombatActor se construyen directamente, igual que
## enemy_intent_runtime_test.gd::_run_planner_contract_tests().

var _failures: Array[String] = []


func _ready() -> void:
	_test_one_v_one()
	_test_player_and_companion_vs_one()
	_test_player_and_companion_vs_multiple()
	_test_dead_companion_skipped()
	_test_dead_enemy_skipped()
	_test_actor_killed_before_scheduled_turn_skipped()
	_test_actor_cannot_act_twice_same_round()
	_test_stable_enemy_order()
	_test_round_increments_exactly_once()
	_test_pauses_on_player_without_forcing_advance()
	_test_new_actor_mid_round_excluded_this_round()
	_test_terminal_stop_mid_round()
	_test_all_actors_ineligible_does_not_hang()
	_test_double_complete_fails_safely()
	_test_start_validation()
	print("[TURN_CONTROLLER_TEST] failures=%s" % JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _actor(id: String, team: CombatActor.Team, kind: CombatActor.ActorType, hp: int = 10) -> CombatActor:
	return CombatActor.new(StringName(id), id, team, kind, 10, hp, 5, 1)


func _check(label: String, condition: bool) -> void:
	print("[TURN_CONTROLLER_TEST] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


## A. 1 jugador vs 1 enemigo.
func _test_one_v_one() -> void:
	var player: CombatActor = _actor("p", CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER)
	var enemy: CombatActor = _actor("e1", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var controller: CombatTurnController = CombatTurnController.new()
	controller.start([player], [enemy])
	_check("1v1_starts_with_player", controller.current_actor == player)
	_check("1v1_round_1", controller.current_round == 1)
	controller.complete_current_turn()
	_check("1v1_then_enemy", controller.current_actor == enemy)
	controller.complete_current_turn()
	_check("1v1_next_round_is_player_again", controller.current_actor == player and controller.current_round == 2)


## B. jugador + compañero vs 1 enemigo.
func _test_player_and_companion_vs_one() -> void:
	var player: CombatActor = _actor("p", CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER)
	var companion: CombatActor = _actor("c", CombatActor.Team.PLAYER, CombatActor.ActorType.COMPANION)
	var enemy: CombatActor = _actor("e1", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var controller: CombatTurnController = CombatTurnController.new()
	controller.start([player, companion], [enemy])
	var order: Array[CombatActor] = [controller.current_actor]
	controller.complete_current_turn()
	order.append(controller.current_actor)
	controller.complete_current_turn()
	order.append(controller.current_actor)
	_check("b_order_is_player_companion_enemy", order == [player, companion, enemy])


## C. jugador + compañero vs múltiples enemigos.
func _test_player_and_companion_vs_multiple() -> void:
	var player: CombatActor = _actor("p", CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER)
	var companion: CombatActor = _actor("c", CombatActor.Team.PLAYER, CombatActor.ActorType.COMPANION)
	var e1: CombatActor = _actor("e1", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var e2: CombatActor = _actor("e2", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var controller: CombatTurnController = CombatTurnController.new()
	controller.start([player, companion], [e1, e2])
	var order: Array[CombatActor] = [controller.current_actor]
	for _index: int in 3:
		controller.complete_current_turn()
		order.append(controller.current_actor)
	_check("c_order_is_player_companion_e1_e2", order == [player, companion, e1, e2])
	controller.complete_current_turn()
	_check("c_round_2_starts_with_player", controller.current_actor == player and controller.current_round == 2)


## D. compañero muerto: se salta por completo, ni siquiera recibe un turno.
func _test_dead_companion_skipped() -> void:
	var player: CombatActor = _actor("p", CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER)
	var companion: CombatActor = _actor("c", CombatActor.Team.PLAYER, CombatActor.ActorType.COMPANION, 0)
	var enemy: CombatActor = _actor("e1", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var controller: CombatTurnController = CombatTurnController.new()
	var started_actors: Array[CombatActor] = []
	controller.actor_turn_started.connect(func(actor: CombatActor) -> void: started_actors.append(actor))
	controller.start([player, companion], [enemy])
	controller.complete_current_turn()
	_check("d_dead_companion_never_started", companion not in started_actors)
	_check("d_goes_straight_to_enemy", controller.current_actor == enemy)


## E. enemigo muerto entre varios: se salta, el resto mantiene su orden.
func _test_dead_enemy_skipped() -> void:
	var player: CombatActor = _actor("p", CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER)
	var e1: CombatActor = _actor("e1", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY, 0)
	var e2: CombatActor = _actor("e2", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var controller: CombatTurnController = CombatTurnController.new()
	controller.start([player], [e1, e2])
	controller.complete_current_turn()
	_check("e_dead_enemy_skipped_goes_to_e2", controller.current_actor == e2)


## F. actor vivo al snapshot pero muerto antes de que le toque: se salta en
## el momento de selección, sin turno propio.
func _test_actor_killed_before_scheduled_turn_skipped() -> void:
	var player: CombatActor = _actor("p", CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER)
	var e1: CombatActor = _actor("e1", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var e2: CombatActor = _actor("e2", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var controller: CombatTurnController = CombatTurnController.new()
	controller.start([player], [e1, e2])
	controller.complete_current_turn()
	_check("f_e1_is_current", controller.current_actor == e1)
	e2.set_current_hp(0)
	controller.complete_current_turn()
	_check("f_e2_died_before_turn_skips_to_round_2", controller.current_actor == player and controller.current_round == 2)


## G. ningún actor puede actuar dos veces en la misma ronda.
func _test_actor_cannot_act_twice_same_round() -> void:
	var player: CombatActor = _actor("p", CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER)
	var companion: CombatActor = _actor("c", CombatActor.Team.PLAYER, CombatActor.ActorType.COMPANION)
	var e1: CombatActor = _actor("e1", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var e2: CombatActor = _actor("e2", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var controller: CombatTurnController = CombatTurnController.new()
	controller.start([player, companion], [e1, e2])
	var seen_this_round: Array[CombatActor] = [controller.current_actor]
	var duplicate_found: bool = false
	for _index: int in 3:
		controller.complete_current_turn()
		if controller.current_round > 1:
			break
		if controller.current_actor in seen_this_round:
			duplicate_found = true
		seen_this_round.append(controller.current_actor)
	_check("g_no_actor_repeats_within_round", not duplicate_found and seen_this_round.size() == 4)


## H. orden estable de enemigos a través de rondas.
func _test_stable_enemy_order() -> void:
	var player: CombatActor = _actor("p", CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER)
	var e1: CombatActor = _actor("e1", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var e2: CombatActor = _actor("e2", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var e3: CombatActor = _actor("e3", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var controller: CombatTurnController = CombatTurnController.new()
	controller.start([player], [e1, e2, e3])
	var round1_enemy_order: Array[CombatActor] = []
	controller.complete_current_turn()
	round1_enemy_order.append(controller.current_actor)
	controller.complete_current_turn()
	round1_enemy_order.append(controller.current_actor)
	controller.complete_current_turn()
	round1_enemy_order.append(controller.current_actor)
	controller.complete_current_turn()
	var round2_enemy_order: Array[CombatActor] = []
	controller.complete_current_turn()
	round2_enemy_order.append(controller.current_actor)
	controller.complete_current_turn()
	round2_enemy_order.append(controller.current_actor)
	controller.complete_current_turn()
	round2_enemy_order.append(controller.current_actor)
	_check("h_enemy_order_stable_round_1", round1_enemy_order == [e1, e2, e3])
	_check("h_enemy_order_stable_round_2", round2_enemy_order == [e1, e2, e3])


## No corresponde a una letra explícita del handoff, pero cubre sección 7:
## un actor agregado a mitad de la ronda enemiga (mismo array por
## referencia, como un summon de jefe) no debe recibir turno en ESTA ronda.
func _test_new_actor_mid_round_excluded_this_round() -> void:
	var player: CombatActor = _actor("p", CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER)
	var e1: CombatActor = _actor("e1", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var enemy_team: Array[CombatActor] = [e1]
	var controller: CombatTurnController = CombatTurnController.new()
	controller.start([player], enemy_team)
	controller.complete_current_turn()
	_check("summon_e1_is_current", controller.current_actor == e1)
	var summoned: CombatActor = _actor("minion", CombatActor.Team.ENEMY, CombatActor.ActorType.MINION)
	enemy_team.append(summoned)
	controller.complete_current_turn()
	_check("summon_not_acted_same_round", controller.current_actor == player and controller.current_round == 2)
	controller.complete_current_turn()
	_check("summon_e1_acts_next_round", controller.current_actor == e1)
	controller.complete_current_turn()
	_check("summon_acts_next_round", controller.current_actor == summoned)


## I. la ronda avanza exactamente una vez por vuelta completa.
func _test_round_increments_exactly_once() -> void:
	var player: CombatActor = _actor("p", CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER)
	var enemy: CombatActor = _actor("e1", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var controller: CombatTurnController = CombatTurnController.new()
	var rounds_seen: Array[int] = []
	controller.round_started.connect(func(round_number: int) -> void: rounds_seen.append(round_number))
	controller.start([player], [enemy])
	controller.complete_current_turn()  # player -> enemy (aún ronda 1)
	controller.complete_current_turn()  # enemy -> ronda 2, player
	controller.complete_current_turn()  # player -> enemy (aún ronda 2)
	controller.complete_current_turn()  # enemy -> ronda 3, player
	_check("i_rounds_increment_by_one_each_time", rounds_seen == [1, 2, 3])


## J. el controller se detiene en el actor jugador hasta que se le avise —
## leerlo repetidas veces sin llamar complete_current_turn() no lo avanza.
func _test_pauses_on_player_without_forcing_advance() -> void:
	var player: CombatActor = _actor("p", CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER)
	var enemy: CombatActor = _actor("e1", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var controller: CombatTurnController = CombatTurnController.new()
	controller.start([player], [enemy])
	var still_player_1: CombatActor = controller.current_actor
	var still_player_2: CombatActor = controller.current_actor
	_check("j_reading_current_actor_does_not_advance", still_player_1 == player and still_player_2 == player)


## L. detener el combate a mitad de turno no deja acción/bloque/ronda
## fantasma: no emite actor_turn_ended para el turno abandonado.
func _test_terminal_stop_mid_round() -> void:
	var player: CombatActor = _actor("p", CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER)
	var enemy: CombatActor = _actor("e1", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var controller: CombatTurnController = CombatTurnController.new()
	# GDScript captura variables locales simples (bool/int) por valor en una
	# lambda — reasignarlas adentro no se ve afuera. Un array sí es un tipo
	# por referencia: .append() muta el mismo objeto que ve el test.
	var stopped_signal_count: Array[int] = [0]
	var ended_signal_count: Array[int] = [0]
	controller.combat_sequence_stopped.connect(func() -> void: stopped_signal_count[0] += 1)
	controller.actor_turn_ended.connect(func(_actor_arg: CombatActor) -> void: ended_signal_count[0] += 1)
	controller.start([player], [enemy])
	controller.complete_current_turn()
	_check("l_enemy_is_current_before_stop", controller.current_actor == enemy)
	var ended_count_before_stop: int = ended_signal_count[0]
	controller.stop()
	_check("l_stopped", controller.is_stopped())
	_check("l_current_actor_cleared", controller.current_actor == null)
	_check("l_stopped_signal_fired", stopped_signal_count[0] == 1)
	_check("l_no_phantom_turn_ended_for_abandoned_actor", ended_signal_count[0] == ended_count_before_stop)


## M. si ningún actor es elegible en ningún equipo, el controller se detiene
## solo — no cuelga el juego.
func _test_all_actors_ineligible_does_not_hang() -> void:
	var dead_player: CombatActor = _actor("p", CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER, 0)
	var dead_enemy: CombatActor = _actor("e1", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY, 0)
	var controller: CombatTurnController = CombatTurnController.new()
	controller.start([dead_player], [dead_enemy])
	_check("m_stops_instead_of_hanging", controller.is_stopped() and controller.current_actor == null)


## N. completar un turno inexistente (sin turno activo, p.ej. tras stop() o
## llamado dos veces seguidas sobre el mismo estado ya terminado) falla en
## silencio — no crashea ni corrompe el estado ya detenido.
func _test_double_complete_fails_safely() -> void:
	var player: CombatActor = _actor("p", CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER)
	var enemy: CombatActor = _actor("e1", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)
	var controller: CombatTurnController = CombatTurnController.new()
	controller.start([player], [enemy])
	controller.stop()
	_check("n_stopped_before_double_complete", controller.is_stopped())
	controller.complete_current_turn()
	_check("n_double_complete_after_stop_stays_stopped", controller.is_stopped())
	_check("n_double_complete_after_stop_current_actor_still_null", controller.current_actor == null)
	controller.complete_current_turn()
	_check("n_repeated_invalid_complete_stays_safe", controller.is_stopped() and controller.current_actor == null)


func _test_start_validation() -> void:
	var empty_player: Array[CombatActor] = []
	var enemy_only: Array[CombatActor] = [_actor("e1", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY)]
	var controller: CombatTurnController = CombatTurnController.new()
	controller.start(empty_player, enemy_only)
	_check("start_rejects_empty_player_team", controller.is_stopped() and controller.current_actor == null)
	var player_only: Array[CombatActor] = [_actor("p", CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER)]
	var empty_enemy: Array[CombatActor] = []
	var controller2: CombatTurnController = CombatTurnController.new()
	controller2.start(player_only, empty_enemy)
	_check("start_rejects_empty_enemy_team", controller2.is_stopped() and controller2.current_actor == null)

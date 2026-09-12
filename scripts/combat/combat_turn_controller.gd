class_name CombatTurnController
extends RefCounted

## Combat Domain M1 — autoridad de secuenciación de turnos, independiente de
## presentación. Ver docs/claude_context/ASHEN_REALM_TECHNICAL_HANDOFF.md
## sección "Combat Domain M1" para el contrato completo.
##
## Responsabilidad exclusiva: decidir QUIÉN actúa a continuación (ronda,
## bloque de equipo, orden estable, elegibilidad, avance). NO decide QUÉ
## hace ese actor (eso sigue siendo responsabilidad de Combat2D / IA
## existente) ni resuelve daño/recompensas/UI.
##
## Modelo pull, no push: no hay _process(), timers ni polling interno.
## Combat2D avanza el controller llamando complete_current_turn() cuando la
## acción lógica del actor actual terminó; las señales son solo para
## observabilidad (tests, hooks de presentación), no para conducir la
## lógica del propio controller.

signal round_started(round_number: int)
signal team_block_started(team: TeamBlock)
signal actor_turn_started(actor: CombatActor)
signal actor_turn_ended(actor: CombatActor)
signal combat_sequence_stopped()

enum TeamBlock {
	PLAYER,
	ENEMY,
}

var current_round: int = 0
var current_team: TeamBlock = TeamBlock.PLAYER
var current_actor: CombatActor

## Referencias directas (no copias) a los arrays que posee Combat2D.
## GDScript pasa Array por referencia: si Combat2D le agrega un minion a
## enemy_actors a mitad de ronda, este controller lo ve recién en el
## próximo _begin_block() de ese equipo (ver _select_next_actor) — nunca
## dentro del bloque ya congelado, que es exactamente el comportamiento que
## _run_enemy_round() ya tenía antes de esta extracción.
var _player_team_ref: Array[CombatActor] = []
var _enemy_team_ref: Array[CombatActor] = []
var _block_actors: Array[CombatActor] = []
var _block_index: int = -1
var _stopped: bool = true


func start(player_team: Array[CombatActor], enemy_team: Array[CombatActor]) -> void:
	if player_team == null or player_team.is_empty():
		push_error("CombatTurnController.start: player_team must not be empty.")
		_stopped = true
		current_actor = null
		return
	if enemy_team == null or enemy_team.is_empty():
		push_error("CombatTurnController.start: enemy_team must not be empty.")
		_stopped = true
		current_actor = null
		return
	_player_team_ref = player_team
	_enemy_team_ref = enemy_team
	_stopped = false
	current_round = 1
	round_started.emit(current_round)
	current_team = TeamBlock.PLAYER
	_block_actors = _player_team_ref.duplicate()
	_block_index = -1
	team_block_started.emit(current_team)
	_select_next_actor()


## Combat2D llama esto cuando la acción lógica del actor actual (jugador,
## aliado IA o enemigo IA) terminó de resolverse — nunca antes. El
## controller no distingue "jugador" de "IA": eso lo decide el llamador
## comparando current_actor contra sus propias referencias (player_actor,
## companion_actor). Ver sección 8/9/10 del handoff M1.
func complete_current_turn() -> void:
	if _stopped or current_actor == null:
		push_error("CombatTurnController.complete_current_turn: no hay turno activo que completar.")
		return
	var finished_actor: CombatActor = current_actor
	current_actor = null
	actor_turn_ended.emit(finished_actor)
	_select_next_actor()


## Combat2D llama esto exactamente donde hoy marca _result_resolved = true
## (dentro de _finish_victory / _finish_defeat). El controller no conoce ni
## decide reglas de victoria/derrota — solo dejar de avanzar cuando se le
## avisa que el combate ya terminó. Abandona el turno en curso sin emitir
## actor_turn_ended (sección 11: "no remaining actor action").
func stop() -> void:
	if _stopped:
		return
	_stopped = true
	current_actor = null
	combat_sequence_stopped.emit()


func is_stopped() -> bool:
	return _stopped


func _select_next_actor() -> void:
	if _stopped:
		return
	# A lo sumo dos transiciones de bloque (equipo actual agotado -> otro
	# equipo agotado) alcanzan para detectar "nadie elegible en todo el
	# combate" sin recursión ni loop no acotado — ver sección 36/M1 #26.M.
	var blocks_checked: int = 0
	while blocks_checked <= 2:
		_block_index += 1
		while _block_index < _block_actors.size():
			var candidate: CombatActor = _block_actors[_block_index]
			if _is_eligible(candidate):
				current_actor = candidate
				actor_turn_started.emit(candidate)
				return
			_block_index += 1
		if current_team == TeamBlock.PLAYER:
			current_team = TeamBlock.ENEMY
		else:
			current_team = TeamBlock.PLAYER
			current_round += 1
			round_started.emit(current_round)
		_block_actors = (_player_team_ref if current_team == TeamBlock.PLAYER else _enemy_team_ref).duplicate()
		_block_index = -1
		team_block_started.emit(current_team)
		blocks_checked += 1
	# Ningún actor elegible en ningún equipo: no hay nada que secuenciar.
	# Esto no debería ocurrir en juego real (Combat2D ya llama a stop() al
	# detectar victoria/derrota antes de que el bloque quede vacío), pero
	# el controller no debe colgar el juego si sucede igual.
	stop()


func _is_eligible(actor: CombatActor) -> bool:
	return actor != null and actor.is_alive()

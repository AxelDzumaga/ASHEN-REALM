class_name CombatEventStream
extends RefCounted

## Combat Domain M4 — un solo stream transitorio por encuentro. Reporta QUÉ
## PASÓ, nunca decide nada: no muta CombatActor/RunState, no conoce
## CombatTurnController (jamás llama complete_current_turn()/start()/
## stop()), no dispara _finish_victory()/_finish_defeat()/combat_won/
## combat_lost. Esas autoridades existentes no cambian (ver handoff M4).
##
## Sin historial: no retiene los eventos que emite. Un futuro combat log
## sería su propio consumidor con su propio buffer acotado, escuchando
## event_emitted — el dominio no acumula memoria por él.
##
## emisión síncrona: event_emitted.emit() llama a los handlers conectados
## en el mismo call stack, en el mismo frame — no es un mecanismo de
## secuenciación asíncrona. Ver combat.gd para el único handler
## presentation-side conectado hoy.

signal event_emitted(event: RefCounted)

const NO_ACTION_ID: int = 0

var _next_action_id: int = 0


func next_action_id() -> int:
	_next_action_id += 1
	return _next_action_id


func emit_event(event: RefCounted) -> void:
	event_emitted.emit(event)

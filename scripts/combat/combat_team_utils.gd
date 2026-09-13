class_name CombatTeamUtils
extends RefCounted

## Combat Domain M2 — una sola definición de "equipo con vida"/"equipo
## derrotado" para Array[CombatActor], en vez de que cada llamador
## reimplemente el mismo loop (combat.gd tenía get_alive_player_actors()
## sobre is_targetable() y get_alive_enemy_actors() sobre is_alive() —
## equivalentes hoy porque CombatActor.targetable solo se apaga junto con
## is_alive(), nunca al revés, pero dos loops separados para el mismo
## concepto igual). No es un objeto con estado — Array[CombatActor] plano
## sigue siendo el modelo de equipo (ver handoff M2): no hay metadata de
## equipo (buffs de equipo, recursos compartidos) que justifique envolverlo.


static func living_actors(team: Array[CombatActor]) -> Array[CombatActor]:
	var alive: Array[CombatActor] = []
	for actor: CombatActor in team:
		if actor != null and actor.is_alive():
			alive.append(actor)
	return alive


static func has_living_actor(team: Array[CombatActor]) -> bool:
	for actor: CombatActor in team:
		if actor != null and actor.is_alive():
			return true
	return false


static func is_defeated(team: Array[CombatActor]) -> bool:
	return not has_living_actor(team)

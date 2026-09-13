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


## Combat Domain M5 — validación mínima de composición de equipo (sección 9
## del handoff M5). Detecta errores de contenido/construcción esperables
## (equipo sobredimensionado, IDs/slots duplicados, actor en el equipo
## equivocado) como fallas observables, no como crasheos — un
## push_error()/assert ya sería suficiente para "corrupción de programador
## imposible", pero un llamador (test o futura validación de contenido)
## puede querer inspeccionar TODOS los problemas de una composición de una
## sola vez, de ahí ValidationResult en vez de un solo bool/error.
class ValidationResult:
	extends RefCounted
	var valid: bool = true
	var errors: Array[String] = []

	func _fail(message: String) -> void:
		valid = false
		errors.append(message)


static func validate_team(team: Array[CombatActor], expected_team: CombatActor.Team) -> ValidationResult:
	var result: ValidationResult = ValidationResult.new()
	if team.size() > CombatRules.MAX_TEAM_SIZE:
		result._fail("team size %d exceeds MAX_TEAM_SIZE %d" % [team.size(), CombatRules.MAX_TEAM_SIZE])
	var seen_actor_ids: Array[StringName] = []
	var seen_formation_slots: Array[int] = []
	for actor: CombatActor in team:
		if actor == null:
			result._fail("team contains a null actor")
			continue
		if actor.team != expected_team:
			result._fail("actor %s has team %s, expected %s" % [actor.actor_id, actor.team, expected_team])
		if actor.actor_id in seen_actor_ids:
			result._fail("duplicate actor_id %s" % actor.actor_id)
		else:
			seen_actor_ids.append(actor.actor_id)
		if actor.formation_slot < 0 or actor.formation_slot >= CombatRules.MAX_TEAM_SIZE:
			result._fail("actor %s formation_slot %d outside 0..%d" % [actor.actor_id, actor.formation_slot, CombatRules.MAX_TEAM_SIZE - 1])
		elif actor.formation_slot in seen_formation_slots:
			result._fail("duplicate formation_slot %d within team" % actor.formation_slot)
		else:
			seen_formation_slots.append(actor.formation_slot)
	return result

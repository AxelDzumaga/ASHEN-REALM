class_name CombatTargetResolver
extends RefCounted

## Combat Domain M3 — resolución de targets, presentation-independent.
## Autoridad de equipo viene de Array[CombatActor] (ally_team/enemy_team,
## normalmente player_actors/enemy_actors), nunca de ActorType — COMPANION
## y PLAYER son el mismo equipo, BOSS y MINION son el mismo equipo (ver
## handoff M2 sección 31 y M3 sección 38). ControllerType tampoco entra acá:
## a quién le toca actuar es un problema de CombatTurnController, a quién
## puede apuntar una acción es un problema de este resolver.
##
## No hay selección automática de aliado: SINGLE_ALLY requiere un
## explicit_target ya elegido por el llamador (hoy Combat2D no tiene UI de
## selección de aliado, así que ese camino siempre devuelve
## TARGET_SELECTION_REQUIRED — eso es correcto, no un bug, hasta que esa UI
## exista). SINGLE_ENEMY preserva el comportamiento actual: Combat2D sigue
## decidiendo el enemigo actualmente seleccionado/por defecto ANTES de
## llamar acá; este resolver solo valida ese explicit_target, nunca lo
## reemplaza en silencio por otro (ver handoff M3 sección 7).

enum Status {
	OK,
	INVALID_TARGET,
	TARGET_SELECTION_REQUIRED,
	NO_VALID_TARGETS,
}

class Resolution:
	extends RefCounted
	var status: Status = Status.OK
	var targets: Array[CombatActor] = []

	func ok() -> bool:
		return status == Status.OK


static func resolve(
	target_type: ActiveSkillData.TargetType,
	acting_actor: CombatActor,
	ally_team: Array[CombatActor],
	enemy_team: Array[CombatActor],
	explicit_target: CombatActor = null,
) -> Resolution:
	match target_type:
		ActiveSkillData.TargetType.SELF:
			return _resolve_self(acting_actor)
		ActiveSkillData.TargetType.SINGLE_ENEMY:
			return _resolve_single_explicit(explicit_target, enemy_team)
		ActiveSkillData.TargetType.SINGLE_ALLY:
			return _resolve_single_explicit(explicit_target, ally_team)
		ActiveSkillData.TargetType.ALL_ENEMIES:
			return _resolve_all(enemy_team)
		ActiveSkillData.TargetType.ALL_ALLIES:
			return _resolve_all(ally_team)
		_:
			# TargetType es un enum cerrado con 5 valores — esta rama solo
			# se alcanzaría si el enum creciera sin actualizar este match.
			# Corrupción de programador, no una invalidación esperable de
			# juego real: falla observable, no un fallback silencioso.
			push_error("CombatTargetResolver: unsupported TargetType %s" % target_type)
			return _fail(Status.NO_VALID_TARGETS)


static func _resolve_self(acting_actor: CombatActor) -> Resolution:
	if acting_actor == null or not acting_actor.is_alive():
		return _fail(Status.INVALID_TARGET)
	var result: Resolution = Resolution.new()
	result.targets = [acting_actor]
	return result


static func _resolve_single_explicit(explicit_target: CombatActor, team: Array[CombatActor]) -> Resolution:
	if explicit_target == null:
		return _fail(Status.TARGET_SELECTION_REQUIRED)
	if not explicit_target.is_alive() or explicit_target not in team:
		return _fail(Status.INVALID_TARGET)
	var result: Resolution = Resolution.new()
	result.targets = [explicit_target]
	return result


static func _resolve_all(team: Array[CombatActor]) -> Resolution:
	var living: Array[CombatActor] = CombatTeamUtils.living_actors(team)
	if living.is_empty():
		return _fail(Status.NO_VALID_TARGETS)
	var result: Resolution = Resolution.new()
	result.targets = living
	return result


static func _fail(status: Status) -> Resolution:
	var result: Resolution = Resolution.new()
	result.status = status
	return result

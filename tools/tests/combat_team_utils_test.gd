extends Node

## Combat Domain M2 — sección 42 del handoff: CombatTeamUtils sobre
## Array[CombatActor] construidos directamente, sin Combat2D.

var _failures: Array[String] = []


func _ready() -> void:
	_test_living_team()
	_test_dead_team()
	_test_mixed_team()
	_test_empty_team()
	_test_null_actor_in_team()
	print("[TEAM_UTILS_TEST] failures=%s" % JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _actor(id: String, hp: int) -> CombatActor:
	return CombatActor.new(StringName(id), id, CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER, 10, hp, 5, 1)


func _check(label: String, condition: bool) -> void:
	print("[TEAM_UTILS_TEST] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


func _test_living_team() -> void:
	var team: Array[CombatActor] = [_actor("a", 10), _actor("b", 5)]
	_check("living_team_has_living_actor", CombatTeamUtils.has_living_actor(team))
	_check("living_team_not_defeated", not CombatTeamUtils.is_defeated(team))
	_check("living_team_living_actors_size", CombatTeamUtils.living_actors(team).size() == 2)


func _test_dead_team() -> void:
	var team: Array[CombatActor] = [_actor("a", 0), _actor("b", 0)]
	_check("dead_team_has_no_living_actor", not CombatTeamUtils.has_living_actor(team))
	_check("dead_team_is_defeated", CombatTeamUtils.is_defeated(team))
	_check("dead_team_living_actors_empty", CombatTeamUtils.living_actors(team).is_empty())


func _test_mixed_team() -> void:
	var alive_actor: CombatActor = _actor("a", 1)
	var dead_actor: CombatActor = _actor("b", 0)
	var team: Array[CombatActor] = [dead_actor, alive_actor]
	_check("mixed_team_has_living_actor", CombatTeamUtils.has_living_actor(team))
	_check("mixed_team_not_defeated", not CombatTeamUtils.is_defeated(team))
	var living: Array[CombatActor] = CombatTeamUtils.living_actors(team)
	_check("mixed_team_living_actors_only_alive", living.size() == 1 and living[0] == alive_actor)


func _test_empty_team() -> void:
	var team: Array[CombatActor] = []
	_check("empty_team_has_no_living_actor", not CombatTeamUtils.has_living_actor(team))
	_check("empty_team_is_defeated", CombatTeamUtils.is_defeated(team))
	_check("empty_team_living_actors_empty", CombatTeamUtils.living_actors(team).is_empty())


func _test_null_actor_in_team() -> void:
	var team: Array[CombatActor] = [null, _actor("a", 1)]
	_check("null_actor_no_crash_has_living", CombatTeamUtils.has_living_actor(team))
	_check("null_actor_no_crash_living_actors", CombatTeamUtils.living_actors(team).size() == 1)
	var all_null_team: Array[CombatActor] = [null, null]
	_check("all_null_team_is_defeated", CombatTeamUtils.is_defeated(all_null_team))

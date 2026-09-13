extends Node

## Combat Domain M5 — sección 39 del handoff: CombatTeamUtils.validate_team(),
## sin Combat2D. Mismo patrón que combat_team_utils_test.gd (M2).

var _failures: Array[String] = []


func _ready() -> void:
	_test_size_one_valid()
	_test_size_five_valid()
	_test_size_six_rejected()
	_test_duplicate_actor_id_rejected()
	_test_duplicate_formation_slot_rejected()
	_test_formation_slot_negative_rejected()
	_test_formation_slot_five_rejected()
	_test_wrong_team_enum_rejected()
	_test_null_actor_rejected()
	_test_valid_team_has_no_errors()
	print("[TEAM_VALIDATION_TEST] failures=%s" % JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(label: String, condition: bool) -> void:
	print("[TEAM_VALIDATION_TEST] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


func _actor(id: String, slot: int, team: CombatActor.Team = CombatActor.Team.PLAYER) -> CombatActor:
	var actor: CombatActor = CombatActor.new(StringName(id), id, team, CombatActor.ActorType.NORMAL_ENEMY, 10, 10, 5, 1)
	actor.formation_slot = slot
	return actor


func _test_size_one_valid() -> void:
	var team: Array[CombatActor] = [_actor("p0", 0)]
	var result: CombatTeamUtils.ValidationResult = CombatTeamUtils.validate_team(team, CombatActor.Team.PLAYER)
	_check("size_one_valid", result.valid)


func _test_size_five_valid() -> void:
	var team: Array[CombatActor] = [
		_actor("p0", 0), _actor("a1", 1), _actor("a2", 2), _actor("a3", 3), _actor("a4", 4),
	]
	var result: CombatTeamUtils.ValidationResult = CombatTeamUtils.validate_team(team, CombatActor.Team.PLAYER)
	_check("size_five_valid", result.valid)


func _test_size_six_rejected() -> void:
	var team: Array[CombatActor] = [
		_actor("p0", 0), _actor("a1", 1), _actor("a2", 2), _actor("a3", 3), _actor("a4", 4), _actor("a5", 4),
	]
	var result: CombatTeamUtils.ValidationResult = CombatTeamUtils.validate_team(team, CombatActor.Team.PLAYER)
	_check("size_six_rejected", not result.valid)


func _test_duplicate_actor_id_rejected() -> void:
	var team: Array[CombatActor] = [_actor("dupe", 0), _actor("dupe", 1)]
	var result: CombatTeamUtils.ValidationResult = CombatTeamUtils.validate_team(team, CombatActor.Team.PLAYER)
	_check("duplicate_actor_id_rejected", not result.valid)


func _test_duplicate_formation_slot_rejected() -> void:
	var team: Array[CombatActor] = [_actor("p0", 2), _actor("a1", 2)]
	var result: CombatTeamUtils.ValidationResult = CombatTeamUtils.validate_team(team, CombatActor.Team.PLAYER)
	_check("duplicate_formation_slot_rejected", not result.valid)


func _test_formation_slot_negative_rejected() -> void:
	var team: Array[CombatActor] = [_actor("p0", -1)]
	var result: CombatTeamUtils.ValidationResult = CombatTeamUtils.validate_team(team, CombatActor.Team.PLAYER)
	_check("formation_slot_negative_rejected", not result.valid)


func _test_formation_slot_five_rejected() -> void:
	var team: Array[CombatActor] = [_actor("p0", 5)]
	var result: CombatTeamUtils.ValidationResult = CombatTeamUtils.validate_team(team, CombatActor.Team.PLAYER)
	_check("formation_slot_five_rejected", not result.valid)


func _test_wrong_team_enum_rejected() -> void:
	var team: Array[CombatActor] = [_actor("e0", 0, CombatActor.Team.ENEMY)]
	var result: CombatTeamUtils.ValidationResult = CombatTeamUtils.validate_team(team, CombatActor.Team.PLAYER)
	_check("wrong_team_enum_rejected", not result.valid)


func _test_null_actor_rejected() -> void:
	var team: Array[CombatActor] = [_actor("p0", 0), null]
	var result: CombatTeamUtils.ValidationResult = CombatTeamUtils.validate_team(team, CombatActor.Team.PLAYER)
	_check("null_actor_rejected", not result.valid)


func _test_valid_team_has_no_errors() -> void:
	var team: Array[CombatActor] = [_actor("p0", 0), _actor("a1", 1)]
	var result: CombatTeamUtils.ValidationResult = CombatTeamUtils.validate_team(team, CombatActor.Team.PLAYER)
	_check("valid_team_has_no_errors", result.errors.is_empty())

extends Node

## Combat Domain M3 — sección 42 del handoff: pruebas directas de
## CombatTargetResolver, sin Combat2D. Actores construidos directamente,
## mismo patrón que combat_turn_controller_test.gd.

var _failures: Array[String] = []


func _ready() -> void:
	_test_self()
	_test_single_enemy_valid()
	_test_single_enemy_wrong_team()
	_test_single_enemy_dead()
	_test_single_enemy_missing_explicit_target()
	_test_single_ally_valid()
	_test_single_ally_wrong_team()
	_test_single_ally_dead()
	_test_single_ally_missing_explicit_target()
	_test_all_enemies_multiple()
	_test_all_enemies_dead_excluded()
	_test_all_enemies_no_living_targets()
	_test_all_allies_multiple()
	_test_all_allies_dead_excluded()
	print("[TARGET_RESOLVER_TEST] failures=%s" % JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _actor(id: String, team: CombatActor.Team, hp: int = 10) -> CombatActor:
	return CombatActor.new(StringName(id), id, team, CombatActor.ActorType.NORMAL_ENEMY, 10, hp, 5, 1)


func _check(label: String, condition: bool) -> void:
	print("[TARGET_RESOLVER_TEST] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


func _test_self() -> void:
	var caster: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var result: CombatTargetResolver.Resolution = CombatTargetResolver.resolve(
		ActiveSkillData.TargetType.SELF, caster, [caster], [],
	)
	_check("self_ok", result.ok())
	_check("self_resolves_to_caster", result.targets == [caster])


func _test_single_enemy_valid() -> void:
	var caster: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var enemy: CombatActor = _actor("e1", CombatActor.Team.ENEMY)
	var result: CombatTargetResolver.Resolution = CombatTargetResolver.resolve(
		ActiveSkillData.TargetType.SINGLE_ENEMY, caster, [caster], [enemy], enemy,
	)
	_check("single_enemy_valid_ok", result.ok())
	_check("single_enemy_valid_targets", result.targets == [enemy])


func _test_single_enemy_wrong_team() -> void:
	var caster: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var ally: CombatActor = _actor("c", CombatActor.Team.PLAYER)
	var enemy: CombatActor = _actor("e1", CombatActor.Team.ENEMY)
	# ally no está en enemy_team, aunque esté vivo — debe rechazarse.
	var result: CombatTargetResolver.Resolution = CombatTargetResolver.resolve(
		ActiveSkillData.TargetType.SINGLE_ENEMY, caster, [caster, ally], [enemy], ally,
	)
	_check("single_enemy_wrong_team_rejected", not result.ok())
	_check("single_enemy_wrong_team_status", result.status == CombatTargetResolver.Status.INVALID_TARGET)


func _test_single_enemy_dead() -> void:
	var caster: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var dead_enemy: CombatActor = _actor("e1", CombatActor.Team.ENEMY, 0)
	var result: CombatTargetResolver.Resolution = CombatTargetResolver.resolve(
		ActiveSkillData.TargetType.SINGLE_ENEMY, caster, [caster], [dead_enemy], dead_enemy,
	)
	_check("single_enemy_dead_rejected", not result.ok())
	_check("single_enemy_dead_status", result.status == CombatTargetResolver.Status.INVALID_TARGET)


func _test_single_enemy_missing_explicit_target() -> void:
	var caster: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var enemy: CombatActor = _actor("e1", CombatActor.Team.ENEMY)
	var result: CombatTargetResolver.Resolution = CombatTargetResolver.resolve(
		ActiveSkillData.TargetType.SINGLE_ENEMY, caster, [caster], [enemy], null,
	)
	_check("single_enemy_missing_target_requires_selection", result.status == CombatTargetResolver.Status.TARGET_SELECTION_REQUIRED)


func _test_single_ally_valid() -> void:
	var caster: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var ally: CombatActor = _actor("c", CombatActor.Team.PLAYER)
	var result: CombatTargetResolver.Resolution = CombatTargetResolver.resolve(
		ActiveSkillData.TargetType.SINGLE_ALLY, caster, [caster, ally], [], ally,
	)
	_check("single_ally_valid_ok", result.ok())
	_check("single_ally_valid_targets", result.targets == [ally])


func _test_single_ally_wrong_team() -> void:
	var caster: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var enemy: CombatActor = _actor("e1", CombatActor.Team.ENEMY)
	var result: CombatTargetResolver.Resolution = CombatTargetResolver.resolve(
		ActiveSkillData.TargetType.SINGLE_ALLY, caster, [caster], [enemy], enemy,
	)
	_check("single_ally_wrong_team_rejected", not result.ok())
	_check("single_ally_wrong_team_status", result.status == CombatTargetResolver.Status.INVALID_TARGET)


func _test_single_ally_dead() -> void:
	var caster: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var dead_ally: CombatActor = _actor("c", CombatActor.Team.PLAYER, 0)
	var result: CombatTargetResolver.Resolution = CombatTargetResolver.resolve(
		ActiveSkillData.TargetType.SINGLE_ALLY, caster, [caster, dead_ally], [], dead_ally,
	)
	_check("single_ally_dead_rejected", not result.ok())
	_check("single_ally_dead_status", result.status == CombatTargetResolver.Status.INVALID_TARGET)


## Sección 6 del handoff: sin selección explícita, SINGLE_ALLY nunca elige
## "el primer aliado vivo" en su lugar — debe pedir selección.
func _test_single_ally_missing_explicit_target() -> void:
	var caster: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var ally: CombatActor = _actor("c", CombatActor.Team.PLAYER)
	var result: CombatTargetResolver.Resolution = CombatTargetResolver.resolve(
		ActiveSkillData.TargetType.SINGLE_ALLY, caster, [caster, ally], [], null,
	)
	_check("single_ally_missing_target_requires_selection", result.status == CombatTargetResolver.Status.TARGET_SELECTION_REQUIRED)
	_check("single_ally_missing_target_no_auto_pick", result.targets.is_empty())


func _test_all_enemies_multiple() -> void:
	var caster: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var e1: CombatActor = _actor("e1", CombatActor.Team.ENEMY)
	var e2: CombatActor = _actor("e2", CombatActor.Team.ENEMY)
	var result: CombatTargetResolver.Resolution = CombatTargetResolver.resolve(
		ActiveSkillData.TargetType.ALL_ENEMIES, caster, [caster], [e1, e2],
	)
	_check("all_enemies_multiple_ok", result.ok())
	_check("all_enemies_multiple_both_once", result.targets == [e1, e2])


func _test_all_enemies_dead_excluded() -> void:
	var caster: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var e1: CombatActor = _actor("e1", CombatActor.Team.ENEMY)
	var dead_e2: CombatActor = _actor("e2", CombatActor.Team.ENEMY, 0)
	var result: CombatTargetResolver.Resolution = CombatTargetResolver.resolve(
		ActiveSkillData.TargetType.ALL_ENEMIES, caster, [caster], [e1, dead_e2],
	)
	_check("all_enemies_dead_excluded", result.targets == [e1])


func _test_all_enemies_no_living_targets() -> void:
	var caster: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var dead_e1: CombatActor = _actor("e1", CombatActor.Team.ENEMY, 0)
	var result: CombatTargetResolver.Resolution = CombatTargetResolver.resolve(
		ActiveSkillData.TargetType.ALL_ENEMIES, caster, [caster], [dead_e1],
	)
	_check("all_enemies_no_living_targets_fails", result.status == CombatTargetResolver.Status.NO_VALID_TARGETS)


func _test_all_allies_multiple() -> void:
	var caster: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var ally: CombatActor = _actor("c", CombatActor.Team.PLAYER)
	var result: CombatTargetResolver.Resolution = CombatTargetResolver.resolve(
		ActiveSkillData.TargetType.ALL_ALLIES, caster, [caster, ally], [],
	)
	_check("all_allies_multiple_ok", result.ok())
	_check("all_allies_multiple_both_once", result.targets == [caster, ally])


func _test_all_allies_dead_excluded() -> void:
	var caster: CombatActor = _actor("p", CombatActor.Team.PLAYER)
	var dead_ally: CombatActor = _actor("c", CombatActor.Team.PLAYER, 0)
	var result: CombatTargetResolver.Resolution = CombatTargetResolver.resolve(
		ActiveSkillData.TargetType.ALL_ALLIES, caster, [caster, dead_ally], [],
	)
	_check("all_allies_dead_excluded", result.targets == [caster])

extends Node

## Combat Domain M2 — sección 41 del handoff: prueba directa del mapeo
## constructor -> ControllerType, sin necesidad de Combat2D. ActorType debe
## permanecer intacto (sigue describiendo QUÉ es el actor; ControllerType es
## un dato nuevo e independiente sobre QUIÉN lo controla).

var _failures: Array[String] = []


func _ready() -> void:
	_test_from_player()
	_test_from_companion()
	_test_from_enemy_normal()
	_test_from_enemy_boss()
	_test_from_enemy_minion()
	print("[CONTROLLER_TYPE_TEST] failures=%s" % JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(label: String, condition: bool) -> void:
	print("[CONTROLLER_TYPE_TEST] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


func _test_from_player() -> void:
	var run: RunState = RunState.new()
	var actor: CombatActor = CombatActor.from_player(&"player_0", run, null)
	_check("from_player_is_player_controlled", actor.controller_type == CombatActor.ControllerType.PLAYER_CONTROLLED)
	_check("from_player_actor_type_unchanged", actor.actor_type == CombatActor.ActorType.PLAYER)
	_check("from_player_team_unchanged", actor.team == CombatActor.Team.PLAYER)


func _test_from_companion() -> void:
	var companion_data: CompanionData = CompanionCatalog.EMBER_HOUND
	var actor: CombatActor = CombatActor.from_companion(&"companion_0", companion_data)
	_check("from_companion_is_ai_ally", actor.controller_type == CombatActor.ControllerType.AI_ALLY)
	_check("from_companion_actor_type_unchanged", actor.actor_type == CombatActor.ActorType.COMPANION)
	_check("from_companion_team_unchanged", actor.team == CombatActor.Team.PLAYER)


func _test_from_enemy_normal() -> void:
	var enemy_data: EnemyData = preload("res://data/enemies/ash_crawler.tres")
	var actor: CombatActor = CombatActor.from_enemy(&"enemy_0", enemy_data, CombatActor.ActorType.NORMAL_ENEMY)
	_check("from_enemy_normal_is_ai_enemy", actor.controller_type == CombatActor.ControllerType.AI_ENEMY)
	_check("from_enemy_normal_actor_type_unchanged", actor.actor_type == CombatActor.ActorType.NORMAL_ENEMY)
	_check("from_enemy_normal_team_unchanged", actor.team == CombatActor.Team.ENEMY)


func _test_from_enemy_boss() -> void:
	var boss_data: EnemyData = preload("res://data/enemies/bosses/ashen_warden.tres")
	var actor: CombatActor = CombatActor.from_enemy(&"boss_0", boss_data, CombatActor.ActorType.BOSS)
	_check("from_enemy_boss_is_ai_enemy", actor.controller_type == CombatActor.ControllerType.AI_ENEMY)
	_check("from_enemy_boss_actor_type_is_boss", actor.actor_type == CombatActor.ActorType.BOSS)


func _test_from_enemy_minion() -> void:
	# from_enemy() recibe ActorType.MINION como parámetro explícito del
	# llamador (así es como combat.gd etiqueta a los summons de jefe) — no
	# hace falta un EnemyData "de summon" real para probar el mapeo.
	var enemy_data: EnemyData = preload("res://data/enemies/ash_crawler.tres")
	var actor: CombatActor = CombatActor.from_enemy(&"minion_0", enemy_data, CombatActor.ActorType.MINION)
	_check("from_enemy_minion_is_ai_enemy", actor.controller_type == CombatActor.ControllerType.AI_ENEMY)
	_check("from_enemy_minion_actor_type_is_minion", actor.actor_type == CombatActor.ActorType.MINION)

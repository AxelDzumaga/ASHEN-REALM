extends Node

## Prueba de regresión (2026-09-03): demuestra con evidencia de ejecución
## real — no solo lectura de código — que un test que ejecuta gameplay real
## y persiste (deposit_run vía derrota real) queda completamente aislado del
## profile real del jugador (user://profile.json) al usar
## SaveManager.use_isolated_test_profile(). Mismo patrón que
## tools/tests/map3d_defeat_flow_test.gd (el test que originalmente causó
## mutaciones reales), reutilizado acá deliberadamente como "peor caso"
## conocido.

const GAME_SCENE := preload("res://scenes/core/game.tscn")
const REAL_PROFILE_PATH := "user://profile.json"

var _failures: Array[String] = []


func _ready() -> void:
	var real_existed_before: bool = FileAccess.file_exists(REAL_PROFILE_PATH)
	var real_hash_before: String = _hash_file(REAL_PROFILE_PATH)

	SaveManager.use_isolated_test_profile(&"save_isolation_regression")
	var isolated_path: String = SaveManager.save_path
	_check("isolated_path_is_not_real_profile", isolated_path != REAL_PROFILE_PATH)
	var isolated_hash_before: String = _hash_file(isolated_path)

	SaveManager.profile.completed_tutorials.clear()
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))

	var game: Control = GAME_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.call("_launch_map3d_prototype")
	await _frames(3)
	var map: Control = game.get("board_screen")
	var run: RunState = RunManager.current_run
	map.call("_request_external_interaction", &"combat", false, false)
	await _frames(3)
	_check("entered_combat_from_map3d", game.get("current_screen").name == "Combat")
	var combat: Control = game.get("current_screen")
	var frames: int = 0
	while int(combat.get("_phase")) != 1 and frames < 600:
		await get_tree().process_frame
		frames += 1
	var player_actor: CombatActor = combat.get("player_actor")
	player_actor.set_current_hp(0)
	run.current_health = 0
	await combat.call("_finish_defeat")
	await get_tree().create_timer(0.7).timeout
	await _frames(3)

	_check("run_deposited", run.rewards_deposited)
	_check("isolated_total_runs_incremented", SaveManager.profile.total_runs >= 1)
	_check("isolated_total_defeats_incremented", SaveManager.profile.total_defeats >= 1)

	var isolated_hash_after: String = _hash_file(isolated_path)
	_check("isolated_profile_file_exists_after", FileAccess.file_exists(isolated_path))
	_check("isolated_profile_actually_changed", isolated_hash_after != isolated_hash_before)

	var real_existed_after: bool = FileAccess.file_exists(REAL_PROFILE_PATH)
	var real_hash_after: String = _hash_file(REAL_PROFILE_PATH)
	_check("real_profile_existence_unchanged", real_existed_before == real_existed_after)
	_check("real_profile_byte_identical", real_hash_before == real_hash_after)
	_check("save_manager_still_pointed_at_isolated_path", SaveManager.save_path == isolated_path)

	print("SAVE_ISOLATION_REGRESSION " + JSON.stringify({
		"failures": _failures,
		"isolated_path": isolated_path,
		"real_profile_path_absolute": ProjectSettings.globalize_path(REAL_PROFILE_PATH),
		"real_existed_before": real_existed_before,
		"real_existed_after": real_existed_after,
		"real_hash_before": real_hash_before,
		"real_hash_after": real_hash_after,
		"isolated_hash_before": isolated_hash_before,
		"isolated_hash_after": isolated_hash_after,
		"isolated_total_runs": SaveManager.profile.total_runs,
		"isolated_total_defeats": SaveManager.profile.total_defeats,
	}))
	game.queue_free()
	RunManager.current_run = null
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _hash_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_sha256(path)


func _frames(count: int) -> void:
	for _index: int in count:
		await get_tree().process_frame


func _check(key: String, condition: bool) -> void:
	if not condition:
		_failures.append(key)

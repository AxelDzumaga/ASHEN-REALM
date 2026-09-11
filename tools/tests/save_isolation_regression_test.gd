extends Node

## Prueba de regresión (2026-09-03, actualizada 2026-09-10 para Map3D
## Production Runtime §29/§39): demuestra con evidencia de ejecución real —
## no solo lectura de código — que un test que ejecuta gameplay real y
## persiste (deposit_run vía derrota real) queda completamente aislado del
## profile real del jugador (user://profile.json).
##
## Antes usaba el launcher --map3d-prototype como "peor caso" porque ese
## launcher no seleccionaba personaje. Map3D Production Runtime §6 corrigió
## exactamente esa ruta: una derrota en modo prototipo ya NO deposita nada
## (ver map3d_defeat_flow_test.gd y map3d_prototype_data_safety_test.gd),
## así que ya no representa un caso de depósito real. Este test ahora recorre
## el flujo de PRODUCCIÓN normal (selección de personaje real vía
## CharacterProfileRepository, aislado con use_isolated_test_root() — mismo
## patrón que active_run_*_test.gd) para probar la misma invariante donde
## sigue siendo relevante: un depósito real de recompensas nunca toca
## user://profile.json cuando corre bajo aislamiento de test.

const GAME_SCENE := preload("res://scenes/core/game.tscn")
const REAL_PROFILE_PATH := "user://profile.json"

var _failures: Array[String] = []


func _ready() -> void:
	var real_existed_before: bool = FileAccess.file_exists(REAL_PROFILE_PATH)
	var real_hash_before: String = _hash_file(REAL_PROFILE_PATH)

	CharacterProfileRepository.use_isolated_test_root("save_isolation_regression")
	ActiveRunRepository.use_isolated_test_root("save_isolation_regression")

	var game: Control = GAME_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	_press(game, "%StartGameButton")
	await get_tree().process_frame
	var name_edit: LineEdit = game.current_screen.get_node("%NameEdit")
	name_edit.text = "Isolation Hero"
	_press(game, "%ConfirmButton")
	await get_tree().process_frame
	game.call("_on_start_run_requested")
	await get_tree().process_frame

	var isolated_path: String = SaveManager.save_path
	_check("isolated_path_is_not_real_profile", isolated_path != REAL_PROFILE_PATH)
	var isolated_hash_before: String = _hash_file(isolated_path)

	# Real production entry: no --map3d-prototype involved, so this is
	# also live proof of §29 ("no normal path requires the prototype arg")
	# and confirms the real character flow reaches Map3D by default.
	_check("entered_via_map3d", game.get("board_screen").name == "AshenWastesMap3D")
	var run: RunState = RunManager.current_run

	game.call("_on_combat_lost", false, false)
	await get_tree().create_timer(0.1).timeout
	await _frames(3)

	_check("run_result_visible", game.current_screen.name == "RunResult")
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


func _press(game: Control, unique_path: String) -> void:
	var button: BaseButton = game.current_screen.get_node(unique_path)
	button.emit_signal("pressed")


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

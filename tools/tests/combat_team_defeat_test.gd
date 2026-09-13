extends Node

## Combat Domain M2 — secciones 43-45 y 37 del handoff: integración real
## contra Combat2D probando el cambio de semántica de derrota aprobado.
## Mismo patrón de reflexión (.get()/.call() sobre miembros privados) que
## ashen_warden_phase3_curse_test.gd / enemy_intent_runtime_test.gd.
##
## Para forzar de forma determinista quién recibe el golpe del enemigo (sin
## depender de política/RNG de IA), cada escenario reescribe directamente
## intent.target_actor del único enemigo antes de dejar avanzar el turno —
## EnemyIntent.resolve_execution_target() respeta ese target mientras siga
## vivo/targetable, así que esto no requiere tocar EnemyActionResolver.

const COMBAT_SCENE := preload("res://scenes/combat/combat.tscn")
const WARDEN: EnemyData = preload("res://data/enemies/bosses/ashen_warden.tres")

var _failures: Array[String] = []
var _seed: int = 700001


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"combat_team_defeat")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	await _test_companion_dies_protagonist_continues()
	await _test_protagonist_dies_ally_continues_no_deadlock()
	await _test_ally_saved_victory_normalizes_to_one_hp()
	await _test_full_team_death_is_defeat_no_normalization()
	await _test_protagonist_dies_no_companion_is_defeat()
	await _test_surviving_protagonist_hp_unchanged_on_victory()
	await _test_warden_counter_kills_protagonist_ally_continues()
	print("[TEAM_DEFEAT_TEST] failures=%s" % JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(label: String, condition: bool) -> void:
	print("[TEAM_DEFEAT_TEST] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


func _next_seed() -> int:
	_seed += 1
	return _seed


func _start_normal_combat(with_companion: bool) -> Control:
	RunManager.start_new_run(_next_seed())
	RunManager.current_run.biome_data = BiomeCatalog.ASHEN_WASTES
	RunManager.current_run.biome_id = BiomeCatalog.ASHEN_WASTES.id
	RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	if with_companion:
		RunManager.current_run.equipped_companion_id = CompanionCatalog.EMBER_HOUND_ID
	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(BiomeCatalog.ASHEN_WASTES, false, false)
	add_child(combat)
	await _wait_for_player_input(combat)
	return combat


func _wait_for_player_input(combat: Control, maximum_frames: int = 800) -> void:
	var frames: int = 0
	while int(combat.get("_phase")) != 1 and not bool(combat.get("_result_resolved")) and frames < maximum_frames:
		await get_tree().process_frame
		frames += 1


func _force_single_enemy_target(combat: Control, target: CombatActor) -> void:
	var intents: Dictionary = combat.get("_enemy_intents")
	for intent: EnemyIntent in intents.values():
		intent.target_actor = target


func _wait_frames(maximum_frames: int) -> void:
	var frames: int = 0
	while frames < maximum_frames:
		await get_tree().process_frame
		frames += 1


func _wait_until_resolved(combat: Control, maximum_frames: int) -> void:
	var frames: int = 0
	while not bool(combat.get("_result_resolved")) and frames < maximum_frames:
		await get_tree().process_frame
		frames += 1


func _end_combat(combat: Control) -> void:
	combat.queue_free()
	await get_tree().process_frame
	RunManager.end_run()


## §30 / §44.B — el compañero muere, el protagonista sigue vivo: el combate
## debe seguir normalmente (nunca fue el semántica que cambió, pero ahora
## comparte el mismo call site unificado que el caso del protagonista).
func _test_companion_dies_protagonist_continues() -> void:
	var combat: Control = await _start_normal_combat(true)
	var player_actor: CombatActor = combat.get("player_actor")
	var companion_actor: CombatActor = combat.get("companion_actor")
	companion_actor.set_current_hp(1)
	_force_single_enemy_target(combat, companion_actor)
	combat.call("_on_attack_pressed")
	await _wait_for_player_input(combat, 900)
	_check("companion_dies_combat_not_resolved", not bool(combat.get("_result_resolved")))
	_check("companion_dies_companion_dead", not companion_actor.is_alive())
	_check("companion_dies_player_alive", player_actor.is_alive())
	_check("companion_dies_reaches_player_input_again", int(combat.get("_phase")) == 1)
	await _end_combat(combat)


## §28 / §44.C / §9 — protagonista muerto, aliado vivo: el bloque JUGADOR
## nunca vuelve a esperar input (no hay deadlock de "espera a un actor
## muerto"), la barra de acciones queda deshabilitada, y el combate sigue
## resolviéndose solo mediante el aliado IA.
func _test_protagonist_dies_ally_continues_no_deadlock() -> void:
	var combat: Control = await _start_normal_combat(true)
	var player_actor: CombatActor = combat.get("player_actor")
	var companion_actor: CombatActor = combat.get("companion_actor")
	player_actor.set_current_hp(1)
	_force_single_enemy_target(combat, player_actor)
	combat.call("_on_attack_pressed")
	var frames: int = 0
	while player_actor.is_alive() and frames < 900:
		await get_tree().process_frame
		frames += 1
	_check("player_ko_died_as_expected", not player_actor.is_alive())
	_check("player_ko_combat_not_resolved", not bool(combat.get("_result_resolved")))
	_check("player_ko_companion_alive", companion_actor.is_alive())
	var attack_button: Button = combat.get("attack_button")
	_check("player_ko_action_bar_disabled", attack_button.disabled)
	# No debe haber "deadlock esperando input": tras varios frames más, el
	# combate sigue avanzando solo (fase nunca vuelve a PLAYER_INPUT=1) en
	# vez de quedarse congelado en el mismo estado para siempre.
	# _phase por sí solo no sirve para detectar progreso acá: una vez que el
	# protagonista muere, nada vuelve a poner _phase en TRANSITION/
	# PLAYER_INPUT (eso solo pasa dentro de _wait_for_player_action(), que
	# ya no se vuelve a entrar), así que se queda fijo en ENEMY_ACTION
	# aunque el combate siga avanzando con total normalidad ronda a ronda.
	# current_round del controller es la señal real de que no hay deadlock.
	var round_before: int = int(combat.get("_turn_controller").current_round)
	await _wait_frames(120)
	_check(
		"player_ko_never_returns_to_player_input",
		int(combat.get("_phase")) != 1,
	)
	_check(
		"player_ko_no_deadlock_state_progressed",
		bool(combat.get("_result_resolved")) or int(combat.get("_turn_controller").current_round) > round_before,
	)
	await _end_combat(combat)


## §31 / §45.B — victoria salvada por el aliado: el protagonista debe volver
## a exactamente 1 HP, nunca vida completa ni un porcentaje, y RunState debe
## reflejarlo (mismo binding en vivo que usa el checkpoint post-combate).
func _test_ally_saved_victory_normalizes_to_one_hp() -> void:
	var combat: Control = await _start_normal_combat(true)
	var player_actor: CombatActor = combat.get("player_actor")
	var companion_actor: CombatActor = combat.get("companion_actor")
	var enemy_actor: CombatActor = combat.get("enemy_actor")
	player_actor.set_current_hp(1)
	_force_single_enemy_target(combat, player_actor)
	combat.call("_on_attack_pressed")
	var frames: int = 0
	while player_actor.is_alive() and frames < 900:
		await get_tree().process_frame
		frames += 1
	_check("ally_saved_player_died", not player_actor.is_alive())
	_check("ally_saved_companion_alive_after_ko", companion_actor.is_alive())
	# Garantiza que el próximo golpe del aliado termina al enemigo, sin
	# depender de aritmética de daño multi-ronda.
	enemy_actor.set_current_hp(1)
	await _wait_until_resolved(combat, 1800)
	_check("ally_saved_combat_resolved", bool(combat.get("_result_resolved")))
	_check("ally_saved_is_victory_not_defeat", int(combat.get("_phase")) == 5)
	_check("ally_saved_player_hp_normalized_to_one", player_actor.get_current_hp() == 1)
	_check("ally_saved_run_state_hp_is_one", RunManager.current_run.current_health == 1)
	await _end_combat(combat)


## §44.D / §45.C — Player Team completo muerto: derrota real, y la
## normalización a 1 HP NUNCA debe aplicarse en derrota.
func _test_full_team_death_is_defeat_no_normalization() -> void:
	var combat: Control = await _start_normal_combat(true)
	var player_actor: CombatActor = combat.get("player_actor")
	var companion_actor: CombatActor = combat.get("companion_actor")
	# El compañero ya está "muerto" antes de que le toque turno esta ronda —
	# el controller lo saltea sin necesidad de que actúe ni de re-planificar
	# nada para él.
	companion_actor.set_current_hp(0)
	player_actor.set_current_hp(1)
	_force_single_enemy_target(combat, player_actor)
	combat.call("_on_attack_pressed")
	await _wait_until_resolved(combat, 900)
	_check("full_team_death_resolved", bool(combat.get("_result_resolved")))
	_check("full_team_death_is_defeat", int(combat.get("_phase")) == 6)
	_check("full_team_death_player_hp_not_normalized", player_actor.get_current_hp() == 0)
	await _end_combat(combat)


## §44.E — sin compañero equipado, protagonista muerto -> derrota (caso
## base sin cambios, reafirmado bajo la nueva condición a nivel de equipo).
func _test_protagonist_dies_no_companion_is_defeat() -> void:
	var combat: Control = await _start_normal_combat(false)
	var player_actor: CombatActor = combat.get("player_actor")
	player_actor.set_current_hp(1)
	_force_single_enemy_target(combat, player_actor)
	combat.call("_on_attack_pressed")
	await _wait_until_resolved(combat, 900)
	_check("no_companion_defeat_resolved", bool(combat.get("_result_resolved")))
	_check("no_companion_defeat_is_defeat", int(combat.get("_phase")) == 6)
	await _end_combat(combat)


## §45.A — protagonista sobrevive con HP > 0 en una victoria normal: su HP
## no debe alterarse (nada de normalización cuando no hubo KO).
func _test_surviving_protagonist_hp_unchanged_on_victory() -> void:
	var combat: Control = await _start_normal_combat(false)
	var player_actor: CombatActor = combat.get("player_actor")
	var enemy_actor: CombatActor = combat.get("enemy_actor")
	player_actor.set_current_hp(23)
	enemy_actor.set_current_hp(1)
	combat.call("_on_attack_pressed")
	await _wait_until_resolved(combat, 900)
	_check("surviving_victory_resolved", bool(combat.get("_result_resolved")))
	_check("surviving_victory_is_victory", int(combat.get("_phase")) == 5)
	_check("surviving_victory_hp_unchanged", player_actor.get_current_hp() == 23)
	await _end_combat(combat)


## §37 — Warden's Rebuke mata al protagonista pero el aliado sigue vivo: ya
## NO debe terminar el combate. Se invoca _resolve_warden_counter()
## directamente (como weak_resist_verification.gd hace con
## _resolve_elemental_damage()) para no depender de hacer avanzar al jefe
## hasta un contraataque real turno a turno.
func _test_warden_counter_kills_protagonist_ally_continues() -> void:
	RunManager.start_new_run(_next_seed())
	RunManager.current_run.biome_data = BiomeCatalog.ASHEN_WASTES
	RunManager.current_run.biome_id = BiomeCatalog.ASHEN_WASTES.id
	RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	RunManager.current_run.equipped_companion_id = CompanionCatalog.EMBER_HOUND_ID
	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(BiomeCatalog.ASHEN_WASTES, true, false)
	add_child(combat)
	await _wait_for_player_input(combat, 900)
	var player_actor: CombatActor = combat.get("player_actor")
	var companion_actor: CombatActor = combat.get("companion_actor")
	var boss_actor: CombatActor = combat.get("_boss_actor")
	var boss_controller: BossEncounterController = combat.get("_boss_controller")
	boss_controller.runtime.counter_armed = true
	player_actor.set_current_hp(1)
	var resolved_true: bool = await combat.call("_resolve_warden_counter", boss_actor)
	_check("warden_counter_did_not_end_combat", not resolved_true)
	_check("warden_counter_combat_not_resolved", not bool(combat.get("_result_resolved")))
	_check("warden_counter_player_died", not player_actor.is_alive())
	_check("warden_counter_companion_alive", companion_actor.is_alive())
	await _end_combat(combat)

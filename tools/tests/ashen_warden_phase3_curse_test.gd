extends Node

## Verificación end-to-end (2026-09-03): la fase 3 de Ashen Warden
## ("ashen_judgment", threshold 35% HP) dispara ashen_judgment_curse dentro de
## un combate real jugado turno a turno — no en aislamiento con las clases de
## producción sueltas (eso ya se cubrió en stage72_systems_runtime_test.gd).
## Mismo patrón que tools/tests/map3d_defeat_flow_test.gd: escena real,
## métodos/vars privados vía .call()/.get(). Usa SaveManager.use_isolated_test_profile()
## para garantizar que efectivamente no toca el perfil real (antes solo era
## la intención declarada acá, no algo forzado por código).
##
## HISTORIAL DE TUNING (2026-09-03, documentado acá porque el proyecto no
## tiene git — sin esto no quedaría rastro de por qué los números son estos):
## - Corrida original: status_duration=2, cooldown=2, weight=35. Curse nunca
##   pasaba de 1 stack — la ventana de duración expiraba antes de que el
##   cooldown permitiera reaplicar, así que "creciente" nunca se manifestaba
##   en juego real pese a que el mecanismo ADD_STACK ya estaba probado en
##   aislamiento (stage72_systems_runtime_test.gd).
## - Fix 1 (aprobado): status_duration 2→4, cooldown sin cambios. Con 4
##   seeds (392017/128917/754331/903482) el máximo de stacks pasó a variar
##   entre 0 y 2 — mejora real pero sin garantía de solapamiento.
## - Fix 2 (aprobado): weight 35→60 (pool de fase 3 pasa de 150 a 175, no se
##   mantuvo en 150 — aceptado explícitamente, no es un problema). Mismas 4
##   seeds: 0/4 sin disparo (antes 1/4), 1/4 en 1 stack, 2/4 en 2 stacks, 1/4
##   en el cap de 3. weight=60 y status_duration=4 quedan como el tuning
##   final de esta ronda — INITIAL TUNING, no balance definitivo.
## - Criterio de aceptación ajustado en consecuencia (aprobado): el estándar
##   ya NO es "el cap de 3 se alcanza siempre" — es "el mecanismo de
##   acumulación por solapamiento se confirma funcional" (al menos un
##   disparo garantizado por combate + evidencia agregada, ya recolectada
##   fuera de este archivo, de que la mayoría de las corridas conocidas
##   superan 1 stack). Ver _check("curse_stacks_show_accumulation", ...)
##   abajo. La seed comprometida en este archivo (754331) es una de las que
##   alcanza el cap completo, así que el check pasa con margen.

const COMBAT_SCENE := preload("res://scenes/combat/combat.tscn")

var _failures: Array[String] = []
var _stack_history: Array[int] = []
var _curse_trigger_turns: Array[int] = []
var _basic_attack_observations: Array[Dictionary] = []
var _phase3_entered_turn: int = -1
var _phase_log: Array[String] = []


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"ashen_warden_phase3_curse")
	SaveManager.profile = ProfileData.new()
	SaveManager.profile.completed_tutorials.clear()
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	# Seed fijo elegido para que, con los ajustes de attack de abajo, la fase 3
	# dure suficientes turnos como para observar acumulación de stacks y varios
	# golpes de boss_basic_attack — determinista y reproducible.
	RunManager.start_new_run(754331)
	var run: RunState = RunManager.current_run
	run.biome_data = BiomeCatalog.ASHEN_WASTES
	run.biome_id = BiomeCatalog.ASHEN_WASTES.id
	run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	# HP alto para eliminar el azar de si el jugador sobrevive — el objetivo
	# es observar la fase 3 y Curse, no poner en riesgo el resultado del combate.
	run.max_health = 5000
	run.current_health = 5000
	run.attack = 40 # rápido para cruzar fase 1 y 2 sin gastar turnos de más.

	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(BiomeCatalog.ASHEN_WASTES, true, false)
	add_child(combat)
	await _wait_for_player_turn(combat, 600)
	_check("combat_reaches_player_input", int(combat.get("_phase")) == 1)
	_check("boss_is_ashen_warden", combat.get("_boss_actor") != null and combat.get("_boss_actor").display_name == "Ashen Warden")

	var boss_controller: BossEncounterController = combat.get("_boss_controller")
	var boss_actor: CombatActor = combat.get("_boss_actor")
	var player_actor: CombatActor = combat.get("player_actor")
	var statuses: CombatStatusController = combat.get("_statuses")

	var turn := 0
	var max_turns := 60
	while turn < max_turns and not bool(combat.get("_result_resolved")):
		turn += 1
		var current_phase: BossPhaseData = boss_controller.get_current_phase()
		if current_phase != null and current_phase.phase_id == &"ashen_judgment" and _phase3_entered_turn < 0:
			_phase3_entered_turn = turn
			run.attack = 6 # una vez en fase 3, aflojar el ritmo para darle turnos a ashen_judgment_curse.
		_phase_log.append("%d:%s" % [turn, String(current_phase.phase_id) if current_phase != null else "none"])

		var pre_curse: StatusEffectInstance = player_actor.get_status(&"curse")
		var pre_stacks: int = pre_curse.stacks if pre_curse != null else 0
		var hp_before: int = player_actor.get_current_hp()
		var pre_effective_attack: int = statuses.get_effective_attack(boss_actor, maxi(1, roundi(float(boss_actor.get_attack()) * boss_controller.get_attack_multiplier())))
		var pre_effective_defense: int = statuses.get_effective_defense(player_actor, player_actor.get_defense())
		var was_ashen_judgment: bool = current_phase != null and current_phase.phase_id == &"ashen_judgment"

		combat.call("_on_attack_pressed")
		await _wait_for_player_turn(combat, 300)

		var post_curse: StatusEffectInstance = player_actor.get_status(&"curse")
		var post_stacks: int = post_curse.stacks if post_curse != null else 0
		if post_stacks > 0:
			_stack_history.append(post_stacks)
		if post_stacks > pre_stacks:
			_curse_trigger_turns.append(turn)

		var ai_states: Dictionary = combat.get("_enemy_ai_states")
		var boss_state: EnemyAIRuntimeState = ai_states.get(boss_actor.actor_id) as EnemyAIRuntimeState
		if was_ashen_judgment and boss_state != null and boss_state.last_action_id == &"boss_basic_attack":
			var hp_after: int = player_actor.get_current_hp()
			var expected_base: int = CombatMath.calculate_damage(pre_effective_attack, pre_effective_defense)
			var expected_with_curse: int = statuses.get_effective_incoming_damage(player_actor, expected_base)
			_basic_attack_observations.append({
				"turn": turn,
				"pre_stacks": pre_stacks,
				"expected": expected_with_curse,
				"actual": hp_before - hp_after,
			})

	_check("combat_did_not_time_out", turn < max_turns)
	_check("phase3_reached", _phase3_entered_turn > 0)
	_check("curse_triggered_at_least_once", not _curse_trigger_turns.is_empty())
	# Estándar de aceptación real (ver historial de tuning arriba): el
	# mecanismo de acumulación por solapamiento debe manifestarse (>=2
	# stacks), no que el cap de 3 se alcance siempre — eso depende de cuántas
	# veces cae la acción dentro de la ventana de status_duration, que varía
	# por seed y no es (ni debería ser) 100% garantizado por diseño.
	_check("curse_stacks_show_accumulation", _stack_history.max() >= 2 if not _stack_history.is_empty() else false)
	_check("curse_stacks_never_exceed_cap", _stack_history.is_empty() or _stack_history.max() <= 3)

	var basic_attack_matches: bool = true
	var saw_curse_free_hit: bool = false
	var saw_cursed_hit: bool = false
	for observation: Dictionary in _basic_attack_observations:
		if int(observation["actual"]) != int(observation["expected"]):
			basic_attack_matches = false
		if int(observation["pre_stacks"]) == 0:
			saw_curse_free_hit = true
		else:
			saw_cursed_hit = true
	_check("basic_attack_had_observations", not _basic_attack_observations.is_empty())
	_check("basic_attack_damage_matches_curse_multiplier", basic_attack_matches)
	_check("observed_both_cursed_and_uncursed_basic_attacks", saw_curse_free_hit and saw_cursed_hit)

	var combat_resolved_cleanly: bool = bool(combat.get("_result_resolved")) and int(combat.get("_phase")) in [5, 6]
	_check("combat_resolved_cleanly", combat_resolved_cleanly)
	_check("player_survived", player_actor.is_alive())

	print(JSON.stringify({
		"failures": _failures,
		"turns_played": turn,
		"phase3_entered_turn": _phase3_entered_turn,
		"curse_trigger_turns": _curse_trigger_turns,
		"stack_history": _stack_history,
		"max_stacks_reached": _stack_history.max() if not _stack_history.is_empty() else 0,
		"basic_attack_observations": _basic_attack_observations,
		"final_phase": int(combat.get("_phase")),
		"result_resolved": bool(combat.get("_result_resolved")),
		"player_hp": player_actor.get_current_hp(),
		"boss_hp": boss_actor.get_current_hp(),
	}, "  "))

	combat.queue_free()
	RunManager.current_run = null
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _wait_for_player_turn(combat: Control, frame_budget: int) -> void:
	for _index: int in frame_budget:
		if int(combat.get("_phase")) == 1 or bool(combat.get("_result_resolved")):
			return
		await get_tree().process_frame


func _check(key: String, condition: bool) -> void:
	if not condition:
		_failures.append(key)

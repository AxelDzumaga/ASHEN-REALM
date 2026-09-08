extends Node

## L0 (2026-09-08): verifica que Combat arranca con el HP autoritativo real de
## RunState -- no con un default de 100 -- para valores no-default de
## current_health/max_health, y que MapSandboxContext.create_run() aplica las
## bonificaciones de su equipo fijo (antes las guardaba como id sin pasar por
## _apply_equipped_item(), dejando max_health/attack/defense en base pura toda
## la sesión). No reproduce un caso donde el pipeline RunState -> CombatActor
## pierda el valor real -- ese pipeline resultó correcto en auditoría y en
## reproducción manual -- pero deja cubierto el contrato para que una futura
## regresión ahí falle un test en vez de descubrirse en un human playtest.

const COMBAT_SCENE := preload("res://scenes/combat/combat.tscn")
const MapSandboxContextSource = preload("res://scripts/board3d/map_sandbox_context.gd")

var _failures: Array[String] = []


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"combat_hp_continuity")

	await _check_case("case_a_121_of_140", 121, 140)
	await _check_case("case_b_73_of_100", 73, 100)
	await _check_case("case_c_1_of_100", 1, 100)
	await _check_case("case_d_full_health", 140, 140)
	await _check_sandbox_equipment_bonus()
	await _check_combat_damage_writes_back_to_run_state()

	if _failures.is_empty():
		print("combat_hp_continuity_test: PASS")
	else:
		for failure: String in _failures:
			push_error("combat_hp_continuity_test FAILED: %s" % failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(name: String, condition: bool) -> void:
	if not condition:
		_failures.append(name)


## Reproduce el contrato pedido: si RunState.current_health = X inmediatamente
## antes de combate, entonces el CombatActor del jugador debe reportar X al
## arrancar -- nunca un default de 100/base ni max_health.
func _check_case(case_name: String, current: int, max_hp: int) -> void:
	RunManager.start_new_run(700001)
	var run: RunState = RunManager.current_run
	run.max_health = max_hp
	run.current_health = current
	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(run.biome_data, false, false)
	add_child(combat)
	await get_tree().process_frame
	var player_actor: CombatActor = combat.get("player_actor")
	_check(
		"%s: current_hp" % case_name,
		player_actor != null and player_actor.get_current_hp() == current,
	)
	_check(
		"%s: max_hp" % case_name,
		player_actor != null and player_actor.get_max_hp() == max_hp,
	)
	_check(
		"%s: not silently reset to BASE_MAX_HEALTH" % case_name,
		current == RunState.BASE_MAX_HEALTH or (player_actor != null and player_actor.get_current_hp() != RunState.BASE_MAX_HEALTH),
	)
	combat.queue_free()
	await get_tree().process_frame
	RunManager.end_run()


func _check_sandbox_equipment_bonus() -> void:
	var run: RunState = MapSandboxContextSource.create_run()
	var weapon: EquipmentData = EquipmentCatalog.EMBER_FANG
	var armor: EquipmentData = EquipmentCatalog.EMBERGUARD_ARMOR
	var expected_max: int = RunState.BASE_MAX_HEALTH + armor.max_health_bonus
	var expected_attack: int = RunState.BASE_ATTACK + weapon.attack_bonus
	var expected_defense: int = RunState.BASE_DEFENSE + armor.defense_bonus
	var expected_current: int = maxi(1, expected_max - RunState.BASE_CURRENT_HEALTH_OFFSET)
	_check("sandbox_max_health_includes_armor_bonus", run.max_health == expected_max)
	_check("sandbox_attack_includes_weapon_bonus", run.attack == expected_attack)
	_check("sandbox_defense_includes_armor_bonus", run.defense == expected_defense)
	_check("sandbox_current_health_derived_from_boosted_max", run.current_health == expected_current)

	RunManager.current_run = run
	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(run.biome_data, false, false)
	add_child(combat)
	await get_tree().process_frame
	var player_actor: CombatActor = combat.get("player_actor")
	_check(
		"sandbox_combat_reflects_equipment_boosted_hp",
		player_actor != null and player_actor.get_current_hp() == expected_current and player_actor.get_max_hp() == expected_max,
	)
	combat.queue_free()
	await get_tree().process_frame
	RunManager.end_run()


## Confirma la otra mitad del contrato: el daño aplicado en combate debe
## modificar el HP autoritativo real (RunState.current_health), no solo un
## valor de presentacion que se pierde al volver al mapa.
func _check_combat_damage_writes_back_to_run_state() -> void:
	RunManager.start_new_run(700002)
	var run: RunState = RunManager.current_run
	run.max_health = 140
	run.current_health = 121
	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(run.biome_data, false, false)
	add_child(combat)
	await get_tree().process_frame
	var player_actor: CombatActor = combat.get("player_actor")
	player_actor.apply_damage(37)
	_check(
		"combat_damage_reflected_on_actor",
		player_actor.get_current_hp() == 121 - 37,
	)
	_check(
		"combat_damage_written_back_to_run_state",
		RunManager.current_run.current_health == 121 - 37,
	)
	# heal() pasa por BiomeModifierResolver.effective_healing() (biome + equipo),
	# así que el monto real puede no ser exactamente el pedido -- el contrato a
	# probar es que el resultado de heal() sea EXACTAMENTE lo que queda escrito
	# en RunState, no un +10 literal ignorando modificadores de bioma.
	var hp_before_heal: int = RunManager.current_run.current_health
	var healed: int = player_actor.heal(10)
	_check("combat_heal_amount_positive", healed > 0)
	_check(
		"combat_heal_written_back_to_run_state",
		RunManager.current_run.current_health == hp_before_heal + healed,
	)
	combat.queue_free()
	await get_tree().process_frame
	RunManager.end_run()

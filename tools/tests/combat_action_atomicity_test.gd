extends Node

## Combat Domain M3 — secciones 18, 43, 44 y 45 del handoff: atomicidad de
## acción, aplicación multi-target, y regresión de crítico, contra un
## Combat2D real. Mismo patrón de reflexión que otros tests de combate.

const COMBAT_SCENE := preload("res://scenes/combat/combat.tscn")

var _failures: Array[String] = []
var _seed: int = 800001


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"combat_action_atomicity")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	_test_crit_unit_level()
	await _test_insufficient_energy_zero_mutation()
	await _test_on_cooldown_zero_mutation()
	await _test_successful_skill_exactly_once()
	await _test_multi_target_damage_each_once()
	await _test_multi_target_one_cost_one_cooldown()
	await _test_forced_crit_basic_attack()
	await _test_stale_basic_attack_target_no_silent_retarget()
	print("[ACTION_ATOMICITY_TEST] failures=%s" % JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(label: String, condition: bool) -> void:
	print("[ACTION_ATOMICITY_TEST] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


func _next_seed() -> int:
	_seed += 1
	return _seed


func _start_normal_combat() -> Control:
	RunManager.start_new_run(_next_seed())
	RunManager.current_run.biome_data = BiomeCatalog.ASHEN_WASTES
	RunManager.current_run.biome_id = BiomeCatalog.ASHEN_WASTES.id
	RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(BiomeCatalog.ASHEN_WASTES, false, false)
	add_child(combat)
	var frames: int = 0
	while int(combat.get("_phase")) != 1 and frames < 800:
		await get_tree().process_frame
		frames += 1
	return combat


func _end_combat(combat: Control) -> void:
	combat.queue_free()
	await get_tree().process_frame
	RunManager.end_run()


func _synthetic_all_enemies_damage_skill(run: RunState) -> ActiveSkillController:
	var data: ActiveSkillData = ActiveSkillData.new()
	data.id = &"test_all_enemies_nuke"
	data.display_name = "Test Nuke"
	data.skill_type = ActiveSkillData.SkillType.DAMAGE
	data.target_type = ActiveSkillData.TargetType.ALL_ENEMIES
	data.energy_cost = 50
	data.cooldown_turns = 2
	data.damage_multiplier = 1.0
	data.enabled = true
	return ActiveSkillController.new(data, run)


## Fixture sintético — ninguna skill autorada usa ALL_ENEMIES (ver handoff
## M3 sección 9); esto no agrega contenido real ni loadouts jugables.
func _add_synthetic_enemy(combat: Control, id: StringName, formation_slot: int) -> CombatActor:
	var enemy_data: EnemyData = preload("res://data/enemies/ash_crawler.tres")
	var extra: CombatActor = CombatActor.from_enemy(id, enemy_data, CombatActor.ActorType.NORMAL_ENEMY)
	extra.formation_slot = formation_slot
	var enemy_actors: Array = combat.get("enemy_actors")
	enemy_actors.append(extra)
	return extra


## §18 — crítico determinista a nivel unitario, sin necesidad de combate:
## chance=0 nunca critea, chance=1 siempre critea, el multiplicador es
## exacto y determinista.
func _test_crit_unit_level() -> void:
	var run: RunState = RunState.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	run.equipment_crit_chance = 0.0
	_check("crit_never_at_zero_chance", not EquipmentEffectResolver.roll_critical(run, rng))
	run.equipment_crit_chance = 1.0
	_check("crit_always_at_full_chance", EquipmentEffectResolver.roll_critical(run, rng))
	run.equipment_crit_damage_bonus = 0.0
	_check("crit_multiplier_exact", EquipmentEffectResolver.apply_critical_damage(100, run) == 150)


## §43 — target inválido/energía insuficiente: cero mutación de energía,
## cooldown, HP o estado, y el turno no se consume (sigue esperando input).
func _test_insufficient_energy_zero_mutation() -> void:
	var combat: Control = await _start_normal_combat()
	var skill_loadout: CombatSkillController = combat.get("_skill_loadout")
	var ember_slash: ActiveSkillController = skill_loadout.get_by_id(ActiveSkillCatalog.EMBER_SLASH.id)
	skill_loadout.current_energy = 0
	var enemy_actor: CombatActor = combat.get("enemy_actor")
	var enemy_hp_before: int = enemy_actor.get_current_hp()
	var player_hp_before: int = combat.get("player_actor").get_current_hp()
	var cooldown_before: int = ember_slash.cooldown_remaining
	combat.call("_on_skill_requested", ember_slash)
	await get_tree().process_frame
	_check("insufficient_energy_energy_unchanged", skill_loadout.current_energy == 0)
	_check("insufficient_energy_cooldown_unchanged", ember_slash.cooldown_remaining == cooldown_before)
	_check("insufficient_energy_enemy_hp_unchanged", enemy_actor.get_current_hp() == enemy_hp_before)
	_check("insufficient_energy_player_hp_unchanged", combat.get("player_actor").get_current_hp() == player_hp_before)
	_check("insufficient_energy_turn_not_consumed", int(combat.get("_pending_player_action")) == 0)
	_check("insufficient_energy_still_player_input", int(combat.get("_phase")) == 1)
	await _end_combat(combat)


## §43 — en cooldown: mismas garantías de cero mutación.
func _test_on_cooldown_zero_mutation() -> void:
	var combat: Control = await _start_normal_combat()
	var skill_loadout: CombatSkillController = combat.get("_skill_loadout")
	var ember_slash: ActiveSkillController = skill_loadout.get_by_id(ActiveSkillCatalog.EMBER_SLASH.id)
	skill_loadout.debug_fill_energy()
	ember_slash.cooldown_remaining = 3
	var energy_before: int = skill_loadout.current_energy
	var enemy_actor: CombatActor = combat.get("enemy_actor")
	var enemy_hp_before: int = enemy_actor.get_current_hp()
	combat.call("_on_skill_requested", ember_slash)
	await get_tree().process_frame
	_check("on_cooldown_energy_unchanged", skill_loadout.current_energy == energy_before)
	_check("on_cooldown_cooldown_unchanged", ember_slash.cooldown_remaining == 3)
	_check("on_cooldown_enemy_hp_unchanged", enemy_actor.get_current_hp() == enemy_hp_before)
	_check("on_cooldown_turn_not_consumed", int(combat.get("_pending_player_action")) == 0)
	_check("on_cooldown_still_player_input", int(combat.get("_phase")) == 1)
	await _end_combat(combat)


## §43 — skill exitosa: costo exactamente una vez, cooldown activado
## exactamente una vez, efecto exactamente una vez.
func _test_successful_skill_exactly_once() -> void:
	var combat: Control = await _start_normal_combat()
	var skill_loadout: CombatSkillController = combat.get("_skill_loadout")
	var ember_slash: ActiveSkillController = skill_loadout.get_by_id(ActiveSkillCatalog.EMBER_SLASH.id)
	skill_loadout.debug_fill_energy()
	var energy_before: int = skill_loadout.current_energy
	var enemy_actor: CombatActor = combat.get("enemy_actor")
	var enemy_hp_before: int = enemy_actor.get_current_hp()
	combat.call("_on_skill_requested", ember_slash)
	_check("successful_skill_cost_paid_once", energy_before - skill_loadout.current_energy == ActiveSkillCatalog.EMBER_SLASH.energy_cost)
	_check("successful_skill_cooldown_activated_once", ember_slash.cooldown_remaining == ActiveSkillCatalog.EMBER_SLASH.cooldown_turns)
	var frames: int = 0
	while int(combat.get("_phase")) != 1 and not bool(combat.get("_result_resolved")) and frames < 900:
		await get_tree().process_frame
		frames += 1
	_check("successful_skill_effect_applied", enemy_actor.get_current_hp() < enemy_hp_before)
	await _end_combat(combat)


## §20 / §44 — DAMAGE + ALL_ENEMIES: cada enemigo vivo recibe el efecto
## exactamente una vez; un enemigo muerto queda excluido. Llama al camino
## de aplicación directamente (reflexión), la resolución de targets ya está
## cubierta por combat_target_resolver_test.gd.
func _test_multi_target_damage_each_once() -> void:
	var combat: Control = await _start_normal_combat()
	var first_enemy: CombatActor = combat.get("enemy_actor")
	var second_enemy: CombatActor = _add_synthetic_enemy(combat, &"enemy_synthetic_1", 1)
	var dead_third_enemy: CombatActor = _add_synthetic_enemy(combat, &"enemy_synthetic_2", 2)
	dead_third_enemy.set_current_hp(0)
	var skill_loadout: CombatSkillController = combat.get("_skill_loadout")
	var synthetic_skill: ActiveSkillController = _synthetic_all_enemies_damage_skill(RunManager.current_run)
	var first_hp_before: int = first_enemy.get_current_hp()
	var second_hp_before: int = second_enemy.get_current_hp()
	var targets: Array[CombatActor] = [first_enemy, second_enemy]
	var resolved: bool = await combat.call("_execute_active_skill_multi_target", synthetic_skill, targets)
	_check("multi_target_did_not_end_combat", not resolved)
	_check("multi_target_first_enemy_damaged_once", first_enemy.get_current_hp() < first_hp_before)
	_check("multi_target_second_enemy_damaged_once", second_enemy.get_current_hp() < second_hp_before)
	_check("multi_target_dead_enemy_untouched", dead_third_enemy.get_current_hp() == 0)
	await _end_combat(combat)


## §44 — un solo cast de una skill ALL_ENEMIES paga costo/cooldown una sola
## vez sin importar cuántos targets termina afectando. Prueba resolución +
## try_use() directamente (reflexión), sin pasar por _on_skill_requested():
## ese call site emite player_action_committed, que despertaría la
## corrutina de fondo _run_combat() (dejada esperando ese mismo signal por
## _start_normal_combat()) y le haría resolver el turno completo — incluido
## un posible turno enemigo con ganancia de energía por daño recibido —
## contaminando exactamente la medición que este test quiere aislar.
func _test_multi_target_one_cost_one_cooldown() -> void:
	var combat: Control = await _start_normal_combat()
	_add_synthetic_enemy(combat, &"enemy_synthetic_1", 1)
	_add_synthetic_enemy(combat, &"enemy_synthetic_2", 2)
	var skill_loadout: CombatSkillController = combat.get("_skill_loadout")
	skill_loadout.debug_fill_energy()
	var synthetic_controller: ActiveSkillController = _synthetic_all_enemies_damage_skill(RunManager.current_run)
	var resolution: CombatTargetResolver.Resolution = combat.call(
		"_resolve_player_target", ActiveSkillData.TargetType.ALL_ENEMIES, null,
	)
	_check("multi_target_resolution_ok", resolution.ok())
	_check("multi_target_committed_all_three_enemies", resolution.targets.size() == 3)
	var energy_before: int = skill_loadout.current_energy
	var used: bool = skill_loadout.try_use(synthetic_controller)
	_check("multi_target_try_use_succeeded", used)
	_check("multi_target_cost_paid_exactly_once", energy_before - skill_loadout.current_energy == synthetic_controller.skill.energy_cost)
	_check("multi_target_cooldown_activated_exactly_once", synthetic_controller.cooldown_remaining == synthetic_controller.skill.cooldown_turns)
	await _end_combat(combat)


## §16/§18 — el ataque básico forzado a crítico aplica el multiplicador
## exactamente una vez sobre el daño base ya calculado.
func _test_forced_crit_basic_attack() -> void:
	var combat: Control = await _start_normal_combat()
	RunManager.current_run.equipment_crit_chance = 1.0
	RunManager.current_run.equipment_crit_damage_bonus = 0.0
	var enemy_actor: CombatActor = combat.get("enemy_actor")
	var player_attack: int = RunManager.current_run.attack
	var expected_base: int = CombatMath.calculate_damage(player_attack, enemy_actor.get_defense())
	var expected_crit: int = maxi(1, roundi(float(expected_base) * 1.5))
	var enemy_hp_before: int = enemy_actor.get_current_hp()
	combat.call("_on_attack_pressed")
	var frames: int = 0
	while int(combat.get("_phase")) != 1 and not bool(combat.get("_result_resolved")) and frames < 900:
		await get_tree().process_frame
		frames += 1
	var actual_damage: int = enemy_hp_before - enemy_actor.get_current_hp()
	_check("forced_crit_damage_matches_multiplier", actual_damage == expected_crit)
	await _end_combat(combat)


## §7/§36 — target de ataque básico inválido (no pertenece a enemy_actors):
## no se reapunta en silencio a otro enemigo, cero daño a nadie.
func _test_stale_basic_attack_target_no_silent_retarget() -> void:
	var combat: Control = await _start_normal_combat()
	var real_enemy: CombatActor = combat.get("enemy_actor")
	var foreign_actor: CombatActor = CombatActor.new(
		&"foreign", "Foreign", CombatActor.Team.ENEMY, CombatActor.ActorType.NORMAL_ENEMY, 10, 10, 5, 1,
	)
	var real_enemy_hp_before: int = real_enemy.get_current_hp()
	var resolved: bool = await combat.call("_run_player_basic_action", foreign_actor)
	_check("stale_target_did_not_end_combat", not resolved)
	_check("stale_target_real_enemy_untouched", real_enemy.get_current_hp() == real_enemy_hp_before)
	_check("stale_target_foreign_actor_untouched", foreign_actor.get_current_hp() == foreign_actor.get_max_hp())
	await _end_combat(combat)

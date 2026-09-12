extends Node

## Combat Domain M1 — sección 29 del handoff: regresión determinista del bug
## de cooldown confirmado durante el audit. Antes de esta extracción, el
## único punto que decrementaba cooldown_remaining era
## CombatSkillController.on_basic_attack_completed(), y combat.gd solo la
## invocaba en la rama PlayerAction.BASIC_ATTACK — un turno donde el
## jugador usaba una skill (en vez de ataque básico) nunca hacía avanzar el
## cooldown de NINGUNA skill. El contrato correcto: el cooldown avanza en
## cada turno del dueño (el jugador), sin importar qué acción eligió. Este
## test no necesita Combat2D — ejercita CombatSkillController/
## ActiveSkillController directamente, igual que
## enemy_intent_runtime_test.gd hace con EnemyIntentPlanner.

var _failures: Array[String] = []


func _ready() -> void:
	_test_cooldown_advances_on_skill_turn_not_only_basic_attack()
	_test_newly_activated_cooldown_does_not_lose_a_tick_same_turn()
	_test_full_contract_across_mixed_turns()
	print("[COOLDOWN_REGRESSION_TEST] failures=%s" % JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(label: String, condition: bool) -> void:
	print("[COOLDOWN_REGRESSION_TEST] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


## Prueba clave del bug: activar ember_slash y luego simular un turno donde
## el jugador elige OTRA skill (ashen_guard) — NO ataque básico — llamando
## advance_cooldowns(ashen_guard_controller) como hace combat.gd en la rama
## ACTIVE_SKILL. ember_slash debe perder un tick de cooldown igual, porque
## el cooldown depende del turno del dueño, no de elegir ataque básico.
func _test_cooldown_advances_on_skill_turn_not_only_basic_attack() -> void:
	var run: RunState = RunState.new()
	var skills: CombatSkillController = CombatSkillController.new(
		[ActiveSkillCatalog.EMBER_SLASH.id, ActiveSkillCatalog.ASHEN_GUARD.id], run,
	)
	var ember_slash: ActiveSkillController = skills.get_by_id(ActiveSkillCatalog.EMBER_SLASH.id)
	var ashen_guard: ActiveSkillController = skills.get_by_id(ActiveSkillCatalog.ASHEN_GUARD.id)
	skills.debug_fill_energy()
	_check("setup_ember_slash_usable", skills.try_use(ember_slash))
	_check("cooldown_set_after_use", ember_slash.cooldown_remaining == ActiveSkillCatalog.EMBER_SLASH.cooldown_turns)
	# Turno siguiente: el jugador NO elige ataque básico, elige ashen_guard.
	# Esto es exactamente lo que combat.gd llama en la rama ACTIVE_SKILL tras
	# resolver la skill: advance_cooldowns(_committed_skill).
	skills.advance_cooldowns(ashen_guard)
	_check(
		"cooldown_advances_on_non_basic_attack_turn",
		ember_slash.cooldown_remaining == ActiveSkillCatalog.EMBER_SLASH.cooldown_turns - 1,
	)


## El cooldown recién fijado por activate() no debe perder un tick en el
## MISMO turno en que se usó — advance_cooldowns() debe excluir la skill
## recién activada ese turno (section 15 del handoff M1).
func _test_newly_activated_cooldown_does_not_lose_a_tick_same_turn() -> void:
	var run: RunState = RunState.new()
	var skills: CombatSkillController = CombatSkillController.new(
		[ActiveSkillCatalog.EMBER_SLASH.id], run,
	)
	var ember_slash: ActiveSkillController = skills.get_by_id(ActiveSkillCatalog.EMBER_SLASH.id)
	skills.debug_fill_energy()
	skills.try_use(ember_slash)
	_check("cooldown_fresh_after_activate", ember_slash.cooldown_remaining == ActiveSkillCatalog.EMBER_SLASH.cooldown_turns)
	# Mismo turno: combat.gd llama advance_cooldowns(_committed_skill) con
	# _committed_skill == ember_slash (la skill recién usada) — no debe
	# perder un tick ahora.
	skills.advance_cooldowns(ember_slash)
	_check(
		"no_same_turn_tick_loss_for_just_activated_skill",
		ember_slash.cooldown_remaining == ActiveSkillCatalog.EMBER_SLASH.cooldown_turns,
	)


## Contrato completo: alternar turnos de ataque básico y de otra skill hace
## que el cooldown llegue a 0 y la skill vuelva a estar disponible, sin que
## el ataque básico sea un requisito en ningún punto de la secuencia.
func _test_full_contract_across_mixed_turns() -> void:
	var run: RunState = RunState.new()
	var skills: CombatSkillController = CombatSkillController.new(
		[ActiveSkillCatalog.EMBER_SLASH.id, ActiveSkillCatalog.ASHEN_GUARD.id], run,
	)
	var ember_slash: ActiveSkillController = skills.get_by_id(ActiveSkillCatalog.EMBER_SLASH.id)
	var ashen_guard: ActiveSkillController = skills.get_by_id(ActiveSkillCatalog.ASHEN_GUARD.id)
	skills.debug_fill_energy()
	skills.try_use(ember_slash)
	var cooldown_turns: int = ActiveSkillCatalog.EMBER_SLASH.cooldown_turns
	_check("full_contract_starts_on_cooldown", not skills.can_use(ember_slash))
	# Turno 1 tras usarla: el jugador ataca básico (rama BASIC_ATTACK real de
	# combat.gd — on_basic_attack_completed ahora delega en advance_cooldowns()).
	skills.on_basic_attack_completed()
	_check("mixed_turn_1_basic_attack_decrements", ember_slash.cooldown_remaining == cooldown_turns - 1)
	# Turno 2: el jugador usa OTRA skill (ashen_guard), no ataque básico.
	skills.advance_cooldowns(ashen_guard)
	_check("mixed_turn_2_other_skill_decrements", ember_slash.cooldown_remaining == cooldown_turns - 2)
	# Turnos restantes hasta llegar a 0, alternando de nuevo ataque básico.
	while ember_slash.cooldown_remaining > 0:
		skills.on_basic_attack_completed()
	_check("full_contract_reaches_zero_and_usable_again", ember_slash.cooldown_remaining == 0)
	skills.debug_fill_energy()
	_check("full_contract_can_use_again", skills.can_use(ember_slash))

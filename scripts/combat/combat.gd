extends Control

signal combat_won(is_boss: bool, is_elite: bool)
signal combat_lost(is_boss: bool, is_elite: bool)
signal player_action_committed

enum CombatPhase {
	INTRO,
	PLAYER_INPUT,
	PLAYER_ACTION,
	ENEMY_ACTION,
	TRANSITION,
	RESOLVING_VICTORY,
	RESOLVING_DEFEAT,
}

enum PlayerAction {
	NONE,
	BASIC_ATTACK,
	ACTIVE_SKILL,
}

const TURN_DELAY := 0.75
const RESULT_DELAY := 1.1
const DEFAULT_ENEMY_AI: EnemyAIData = preload("res://data/enemy_ai_profiles/brute_primary.tres")
const MAX_ENEMY_ACTORS: int = 3
const VISUAL_SLICE_WRETCH: EnemyData = preload("res://data/enemies/ember_wretch.tres")
const VISUAL_SLICE_CRAWLER: EnemyData = preload("res://data/enemies/ash_crawler.tres")
const VISUAL_SLICE_BRUTE: EnemyData = preload("res://data/enemies/elites/ashbound_brute.tres")
const VISUAL_SLICE_SUPPORT: EnemyData = preload("res://data/enemies/ember_acolyte.tres")

@onready var encounter_label: Label = %EncounterLabel
@onready var biome_rules_label: Label = %BiomeRulesLabel
@onready var combat_stage: CombatStage = %CombatStage
@onready var enemy_formation: Control = %EnemyFormation
@onready var player_name_label: Label = %PlayerNameLabel
@onready var player_caption: Label = %PlayerCaption
@onready var player_health_label: AshenBadge = %PlayerHealthLabel
@onready var player_health_bar: ProgressBar = %PlayerHealthBar
@onready var player_attack_badge: AshenBadge = %PlayerAttackBadge
@onready var player_defense_badge: AshenBadge = %PlayerDefenseBadge
@onready var player_panel: PanelContainer = %PlayerPanel
@onready var player_view: CombatCharacterView = %PlayerCharacterView
@onready var companion_view: CombatCharacterView = %CompanionCharacterView
@onready var companion_panel: PanelContainer = %CompanionPanel
@onready var companion_name_label: Label = %CompanionNameLabel
@onready var companion_health_bar: ProgressBar = %CompanionHealthBar
@onready var companion_stats_label: Label = %CompanionStatsLabel
@onready var companion_status_row: HBoxContainer = %CompanionStatusRow
@onready var enemy_name_label: Label = %EnemyNameLabel
@onready var enemy_health_label: AshenBadge = %EnemyHealthLabel
@onready var enemy_health_bar: ProgressBar = %EnemyHealthBar
@onready var enemy_attack_badge: AshenBadge = %EnemyAttackBadge
@onready var enemy_defense_badge: AshenBadge = %EnemyDefenseBadge
@onready var enemy_intent_badge: AshenBadge = %EnemyIntentBadge
@onready var enemy_status_row: HBoxContainer = %EnemyStatusRow
@onready var enemy_panel: PanelContainer = %EnemyPanel
@onready var enemy_view: CombatCharacterView = %EnemyCharacterView
@onready var turn_label: Label = %TurnLabel
@onready var action_label: Label = %ActionLabel
@onready var action_badge: AshenBadge = %ActionBadge
@onready var active_effects_row: HBoxContainer = %ActiveEffectsLabel
@onready var skill_icon: AshenIcon = %SkillIcon
@onready var skill_name_label: Label = %SkillNameLabel
@onready var skill_description_label: Label = %SkillDescriptionLabel
@onready var skill_augments_label: Label = %SkillAugmentsLabel
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var energy_icon: AshenIcon = %EnergyIcon
@onready var energy_label: Label = %EnergyLabel
@onready var skill_status_label: AshenBadge = %SkillStatusLabel
@onready var attack_icon: AshenIcon = %AttackIcon
@onready var attack_button: Button = %AttackButton
@onready var action_bar: HBoxContainer = %ActionBar
@onready var skill_panel: PanelContainer = %SkillPanel
@onready var action_panel: PanelContainer = %ActionPanel
@onready var vfx: CombatVFXController = %CombatVFX
@onready var choreography: CombatChoreographyController = %CombatChoreography
@onready var skill_debug_panel: Container = %SkillDebugPanel
@onready var debug_fill_energy_button: Button = %DebugFillEnergyButton
@onready var debug_reset_cooldown_button: Button = %DebugResetCooldownButton

var _encounter_enemies: Array[EnemyData] = []
var _encounter_template_id: StringName = &""
var _enemy_slots: Array[EnemyCombatSlot] = []
var player_actor: CombatActor
var companion_actor: CombatActor
var enemy_actor: CombatActor
# ETAPA 37C mantiene una sola selección lógica; enemy_actor es su adapter legacy.
var selected_enemy_actor: CombatActor
var player_actors: Array[CombatActor] = []
var enemy_actors: Array[CombatActor] = []
var _biome: BiomeData
var _is_boss := false
var _is_elite := false
var _boons: BoonController
var _statuses: CombatStatusController
var _synergy_runtime: SynergyRuntimeState
var _equipment_runtime: EquipmentRuntimeState
var _companion_runtime: CompanionRuntimeState
var _enemy_ai_states: Dictionary[StringName, EnemyAIRuntimeState] = {}
var _enemy_intents: Dictionary[StringName, EnemyIntent] = {}
var _intent_plan_sequence: int = 0
var _boss_actor: CombatActor
var _boss_controller: BossEncounterController
var _boss_threshold_markers: BossThresholdMarkers
var _next_minion_runtime_index: int = 0
var _equipment_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _skill_loadout: CombatSkillController
var _focused_skill: ActiveSkillController
var _skill_buttons: Array[CombatSkillButton] = []
var _result_resolved: bool = false
var _phase: CombatPhase = CombatPhase.INTRO
var _pending_player_action: PlayerAction = PlayerAction.NONE
var _committed_target_actor: CombatActor
var _committed_skill: ActiveSkillController
var _last_ember_active: bool = false
var _active_effect_signature: String = ""
var _player_actions_completed: int = 0
var _telemetry_turn_count: int = 0


func configure(biome: BiomeData, is_boss: bool = false, is_elite: bool = false) -> void:
	_biome = biome
	_is_boss = is_boss
	_is_elite = is_elite
	set_meta(&"biome_environment_boss", is_boss)


func _ready() -> void:
	if not RunManager.has_active_run() or _biome == null:
		push_error("Combat requires an active run and biome data.")
		_emit_configuration_failure.call_deferred()
		return
	var active_pool: Array[EnemyData] = _biome.elite_enemy_pool if _is_elite else _biome.normal_enemy_pool
	if (_is_boss and _biome.boss == null) or (not _is_boss and active_pool.is_empty()):
		push_error("Combat requires an active run and an available enemy.")
		_emit_configuration_failure.call_deferred()
		return

	_encounter_enemies = _build_encounter(active_pool)
	var encounter_type: StringName = _get_encounter_type()
	var telemetry_enemy_ids: Array[StringName] = []
	for telemetry_enemy: EnemyData in _encounter_enemies:
		telemetry_enemy_ids.append(telemetry_enemy.id)
	TelemetryManager.track_combat_started(
		RunManager.current_run, encounter_type, telemetry_enemy_ids, _encounter_template_id,
	)
	_initialize_actors()
	_initialize_boss_encounter()
	if _is_boss:
		TelemetryManager.track_boss_started(RunManager.current_run, _biome.boss.id)
	var discovery_category: StringName = CodexCatalog.BOSSES if _is_boss else (CodexCatalog.ELITES if _is_elite else CodexCatalog.ENEMIES)
	var discovery_ids: Array[StringName] = []
	for encountered_enemy: EnemyData in _encounter_enemies:
		if encountered_enemy.id not in discovery_ids:
			discovery_ids.append(encountered_enemy.id)
	DiscoveryTracker.discover_many(discovery_category, discovery_ids)
	_boons = BoonController.new(RunManager.current_run)
	_boons.player_actor = player_actor
	_boons.on_combat_started()
	_statuses = CombatStatusController.new()
	_synergy_runtime = SynergyRuntimeState.new()
	_synergy_runtime.reset_for_combat()
	_equipment_runtime = EquipmentRuntimeState.new()
	var equipment_seed_mix: int = (RunManager.current_run.board_position + 1) * 65537 + RunManager.current_run.combats_won * 4099
	_equipment_rng.seed = absi(RunManager.current_run.board_seed ^ equipment_seed_mix ^ 0x43E)
	EquipmentEffectResolver.apply_combat_start(RunManager.current_run, player_actor, _statuses, _equipment_runtime)
	_last_ember_active = _boons.is_last_ember_active()
	_skill_loadout = CombatSkillController.new(RunManager.current_run.equipped_skill_ids, RunManager.current_run)
	_skill_loadout.set_player_actor(player_actor)
	if DebugConfig.is_visual_slice_enabled():
		_skill_loadout.debug_fill_energy()
	SynergyEffectResolver.apply_combat_start(RunManager.current_run, player_actor, _statuses)
	_focused_skill = _skill_loadout.skills[0] if not _skill_loadout.skills.is_empty() else null
	attack_button.pressed.connect(_on_attack_pressed)
	_build_skill_buttons()
	debug_fill_energy_button.pressed.connect(_on_debug_fill_energy_pressed)
	debug_reset_cooldown_button.pressed.connect(_on_debug_reset_cooldown_pressed)
	skill_debug_panel.visible = DebugConfig.DEBUG_TOOLS_ENABLED
	attack_icon.configure(&"attack", VisualTheme.ATTACK, AshenIcon.DisplaySize.SMALL)
	energy_icon.configure(&"ember", VisualTheme.ENERGY, AshenIcon.DisplaySize.SMALL)
	biome_rules_label.text = BiomeModifierResolver.get_compact_summary(_biome)
	biome_rules_label.modulate = _biome.accent_color.lightened(0.18)
	_set_action_badge(&"combat", "ENCUENTRO", AshenBadge.Variant.DANGER)
	enemy_intent_badge.hide()
	energy_bar.max_value = CombatSkillController.MAX_ENERGY
	player_view.configure_fallback_presence(&"player", VisualTheme.EMBER, _biome.accent_color)
	companion_view.configure_fallback_presence(&"companion", Color("ed5a1f"), _biome.accent_color)
	player_panel.add_theme_stylebox_override("panel", CombatStage.hud_style(Color(0.035, 0.03, 0.035, 0.76), Color(0.9, 0.55, 0.2, 0.72), 1))
	companion_panel.add_theme_stylebox_override("panel", CombatStage.hud_style(Color(0.04, 0.028, 0.025, 0.74), Color(0.93, 0.35, 0.12, 0.72), 1))
	var enemy_hud_accent: Color = VisualTheme.BOSS if _is_boss else (VisualTheme.ELITE if _is_elite else VisualTheme.DANGER)
	var fallback_kind: StringName = &"normal"
	if _is_boss:
		fallback_kind = &"boss"
	elif _is_elite:
		fallback_kind = &"elite"
	enemy_view.configure_fallback_presence(fallback_kind, enemy_hud_accent, _biome.accent_color)
	enemy_panel.add_theme_stylebox_override("panel", CombatStage.hud_style(Color(0.04, 0.025, 0.035, 0.78), enemy_hud_accent, 1 if not _is_boss else 2))
	skill_panel.add_theme_stylebox_override("panel", VisualTheme.elevated_panel_style(Color(0.055, 0.045, 0.06, 0.96), VisualTheme.ENERGY_DARK.lightened(0.22), 2, 14))
	action_panel.add_theme_stylebox_override("panel", VisualTheme.panel_style(Color(0.025, 0.018, 0.022, 0.18), Color.TRANSPARENT, 0, 8))
	player_health_bar.add_theme_stylebox_override("background", VisualTheme.panel_style(Color("0d0b11"), VisualTheme.BORDER_DARK, 2, 8))
	player_health_bar.add_theme_stylebox_override("fill", VisualTheme.panel_style(VisualTheme.HEAL, VisualTheme.HEAL, 0, 8))
	companion_health_bar.add_theme_stylebox_override("background", VisualTheme.panel_style(Color("0d0b11"), VisualTheme.BORDER_DARK, 1, 6))
	companion_health_bar.add_theme_stylebox_override("fill", VisualTheme.panel_style(Color("cf4820"), Color("ed7b32"), 0, 6))
	enemy_health_bar.add_theme_stylebox_override("background", VisualTheme.panel_style(Color("0d0b11"), VisualTheme.BORDER_DARK, 2, 8))
	enemy_health_bar.add_theme_stylebox_override("fill", VisualTheme.panel_style(VisualTheme.BOSS if _is_boss else VisualTheme.DANGER, VisualTheme.DANGER, 0, 8))
	energy_bar.add_theme_stylebox_override("background", VisualTheme.panel_style(Color("14101a"), VisualTheme.ENERGY_DARK, 2, 8))
	energy_bar.add_theme_stylebox_override("fill", VisualTheme.panel_style(VisualTheme.ENERGY, VisualTheme.ENERGY, 0, 8))
	var encounter_kind: String = "JEFE" if _is_boss else ("ÉLITE" if _is_elite else "ENEMIGO")
	if _is_boss and _boss_controller != null and _boss_controller.data != null:
		encounter_kind = "%s · %s" % [_boss_controller.data.get_role_label(), _boss_controller.data.get_threat_label()]
	encounter_label.text = encounter_kind
	if enemy_actors.size() == 1:
		var role_name: String = _get_enemy_ai_profile(enemy_actor).get_role_name()
		if role_name != encounter_kind:
			encounter_label.text = "%s · %s" % [encounter_kind, role_name]
	combat_stage.configure(_is_elite, _is_boss, _biome.accent_color)
	_setup_boss_hud()
	if _is_boss:
		enemy_panel.theme_type_variation = &"BossPanel"
		enemy_panel.anchor_bottom = 0.085
		enemy_view.anchor_top = 0.065
		enemy_view.anchor_bottom = 0.55
		encounter_label.hide()
		enemy_attack_badge.hide()
		enemy_defense_badge.hide()
		enemy_view.fallback_label.text = "JEFE"
		(%Background as ColorRect).color = Color("14090d")
		encounter_label.modulate = VisualTheme.BOSS
		enemy_name_label.add_theme_font_size_override("font_size", 18)
		AudioManager.play_sfx(AudioManager.Sfx.BOSS_ENCOUNTER)
	elif _is_elite:
		enemy_panel.theme_type_variation = &"ElitePanel"
		enemy_view.fallback_label.text = "ÉLITE"
		encounter_label.modulate = VisualTheme.ELITE
		AudioManager.play_sfx(AudioManager.Sfx.ELITE)
	else:
		enemy_view.fallback_label.text = "ENEMIGO"
		AudioManager.play_sfx(AudioManager.Sfx.COMBAT_ENTER)
	_apply_character_visuals()
	_update_target_highlights()
	vfx.setup(player_view, enemy_view, enemy_actor.display_name, _is_elite, _is_boss)
	_update_combatants()
	_update_skill_ui()
	_run_combat()


func _build_skill_buttons() -> void:
	for controller: ActiveSkillController in _skill_loadout.skills:
		var button: CombatSkillButton = CombatSkillButton.new()
		button.theme_type_variation = &"SecondaryButton"
		button.configure(controller)
		button.skill_requested.connect(_on_skill_requested)
		button.skill_focused.connect(_show_skill_detail)
		action_bar.add_child(button)
		_skill_buttons.append(button)
	var focus_controls: Array[Control] = []
	focus_controls.append(attack_button)
	for skill_action_button: CombatSkillButton in _skill_buttons:
		focus_controls.append(skill_action_button)
	for index: int in focus_controls.size():
		var previous_index: int = (index - 1 + focus_controls.size()) % focus_controls.size()
		var next_index: int = (index + 1) % focus_controls.size()
		focus_controls[index].focus_previous = focus_controls[index].get_path_to(focus_controls[previous_index])
		focus_controls[index].focus_next = focus_controls[index].get_path_to(focus_controls[next_index])
	_show_skill_detail(_focused_skill)


func _show_skill_detail(controller: ActiveSkillController) -> void:
	_focused_skill = controller
	var has_skill: bool = controller != null
	skill_icon.visible = has_skill
	skill_name_label.visible = has_skill
	skill_description_label.visible = false
	skill_status_label.visible = false
	skill_augments_label.visible = false
	if not has_skill:
		return
	skill_name_label.text = controller.skill.display_name.to_upper()
	var skill_color: Color = VisualTheme.ATTACK
	if controller.skill.skill_type == ActiveSkillData.SkillType.DEFENSE:
		skill_color = VisualTheme.DEFENSE
	elif controller.skill.skill_type == ActiveSkillData.SkillType.HEAL:
		skill_color = VisualTheme.HEAL
	skill_icon.configure(controller.skill.icon_id, skill_color, AshenIcon.DisplaySize.MEDIUM)
	_update_skill_ui()


func _emit_configuration_failure() -> void:
	combat_lost.emit(_is_boss, _is_elite)


func _initialize_actors() -> void:
	var enemy_type: CombatActor.ActorType = CombatActor.ActorType.NORMAL_ENEMY
	if _is_boss:
		enemy_type = CombatActor.ActorType.BOSS
	elif _is_elite:
		enemy_type = CombatActor.ActorType.ELITE
	player_actor = CombatActor.from_player(&"player_0", RunManager.current_run, PlayerVisualCatalog.ASHEN_WANDERER)
	player_actor.set_visual_view(player_view)
	companion_actor = null
	_companion_runtime = null
	player_actors.clear()
	enemy_actors.clear()
	_enemy_ai_states.clear()
	_enemy_intents.clear()
	_intent_plan_sequence = 0
	player_actors.append(player_actor)
	var companion_data: CompanionData = CompanionCatalog.get_by_id(RunManager.current_run.equipped_companion_id)
	if companion_data != null:
		companion_actor = CombatActor.from_companion(&"companion_0", companion_data)
		companion_actor.formation_slot = 1
		companion_actor.set_visual_view(companion_view)
		player_actors.append(companion_actor)
		_companion_runtime = CompanionRuntimeState.new()
	for enemy_index: int in range(_encounter_enemies.size()):
		var created_actor: CombatActor = CombatActor.from_enemy(
			StringName("enemy_%d" % enemy_index), _encounter_enemies[enemy_index], enemy_type,
		)
		created_actor.formation_slot = enemy_index
		enemy_actors.append(created_actor)
		_enemy_ai_states[created_actor.actor_id] = EnemyAIRuntimeState.new()
	selected_enemy_actor = enemy_actors[0]
	enemy_actor = selected_enemy_actor


func _initialize_boss_encounter() -> void:
	_boss_actor = null
	_boss_controller = null
	_next_minion_runtime_index = 0
	if not _is_boss or enemy_actors.is_empty():
		return
	var boss_data: EnemyData = enemy_actors[0].source_data as EnemyData
	if boss_data == null or boss_data.boss_encounter == null:
		return
	_boss_actor = enemy_actors[0]
	_boss_actor.formation_slot = 1
	_boss_controller = BossEncounterController.new(boss_data.boss_encounter, _boss_actor)


func _setup_boss_hud() -> void:
	if _boss_controller == null:
		return
	_boss_threshold_markers = BossThresholdMarkers.new()
	_boss_threshold_markers.name = "BossThresholdMarkers"
	_boss_threshold_markers.thresholds.clear()
	for phase_index: int in range(1, _boss_controller.data.phases.size()):
		var threshold_phase: BossPhaseData = _boss_controller.data.phases[phase_index]
		if threshold_phase != null:
			_boss_threshold_markers.thresholds.append(threshold_phase.hp_threshold_percent)
	_boss_threshold_markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	enemy_health_bar.add_child(_boss_threshold_markers)
	var phase: BossPhaseData = _boss_controller.get_current_phase()
	if phase != null:
		combat_stage.set_boss_phase_accent(phase.visual_accent)


func _build_encounter(active_pool: Array[EnemyData]) -> Array[EnemyData]:
	var encounter: Array[EnemyData] = []
	var slice_mode: StringName = DebugConfig.get_visual_slice_mode()
	if slice_mode == &"intent_support":
		encounter.assign([VISUAL_SLICE_SUPPORT])
		_encounter_template_id = &"visual_slice_61_support"
		return encounter
	if slice_mode in [&"normal", &"attack", &"attack_start", &"attack_contact", &"attack_recovery", &"ember", &"intent_multi", &"intent_detail"]:
		encounter.assign([VISUAL_SLICE_CRAWLER, VISUAL_SLICE_WRETCH, VISUAL_SLICE_BRUTE])
		_encounter_template_id = &"visual_slice_61" if String(slice_mode).begins_with("intent") else &"visual_slice_59b"
		return encounter
	if _is_boss:
		encounter.append(_biome.boss)
		return encounter
	if _is_elite:
		encounter.append(_pick_from_pool(active_pool, _encounter_rng()))
		return encounter
	var generated: EncounterInstance = EncounterResolver.build_normal(_biome, RunManager.current_run)
	if generated != null and not generated.enemies.is_empty():
		if generated.template != null:
			_encounter_template_id = generated.template.id
		return generated.enemies
	# Fallback aislado: un solo enemigo válido. No restaura el reparto provisional 70/23/7.
	encounter.append(_pick_from_pool(active_pool, _encounter_rng()))
	return encounter


func _encounter_rng() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var biome_hash: int = String(_biome.id).hash()
	var position_mix: int = RunManager.current_run.board_position * 104729
	rng.seed = absi(RunManager.current_run.board_seed ^ biome_hash ^ position_mix ^ 0x37B)
	return rng


func _pick_from_pool(pool: Array[EnemyData], rng: RandomNumberGenerator) -> EnemyData:
	return pool[rng.randi_range(0, pool.size() - 1)]


func get_alive_player_actors() -> Array[CombatActor]:
	var alive_actors: Array[CombatActor] = []
	for actor: CombatActor in player_actors:
		if actor.is_targetable():
			alive_actors.append(actor)
	return alive_actors


func get_alive_enemy_actors() -> Array[CombatActor]:
	var alive_actors: Array[CombatActor] = []
	for actor: CombatActor in enemy_actors:
		if actor.is_alive():
			alive_actors.append(actor)
	return alive_actors


func _get_enemy_ai_profile(actor: CombatActor) -> EnemyAIData:
	if actor == null:
		return DEFAULT_ENEMY_AI
	var enemy_data: EnemyData = actor.source_data as EnemyData
	if enemy_data == null or enemy_data.ai_profile == null:
		return DEFAULT_ENEMY_AI
	if _boss_controller != null and _boss_controller.owns_actor(actor):
		return _boss_controller.get_active_ai_profile(enemy_data.ai_profile)
	return enemy_data.ai_profile


func _get_enemy_ai_state(actor: CombatActor) -> EnemyAIRuntimeState:
	if actor == null:
		return null
	var state: EnemyAIRuntimeState = _enemy_ai_states.get(actor.actor_id) as EnemyAIRuntimeState
	if state == null:
		state = EnemyAIRuntimeState.new()
		_enemy_ai_states[actor.actor_id] = state
	return state


func _get_enemy_defense_bonus(actor: CombatActor) -> int:
	var state: EnemyAIRuntimeState = _get_enemy_ai_state(actor)
	var defense_bonus: int = state.get_defense_bonus() if state != null else 0
	if _boss_controller != null and _boss_controller.owns_actor(actor):
		defense_bonus += _boss_controller.get_defense_bonus()
	return defense_bonus


func _get_effective_actor_defense(actor: CombatActor) -> int:
	if actor == null:
		return 0
	var base_defense: int = actor.get_defense()
	if actor == player_actor and _boons != null and _skill_loadout != null:
		base_defense = _boons.get_effective_defense() + _skill_loadout.get_temporary_defense_bonus()
	elif actor.team == CombatActor.Team.ENEMY:
		base_defense += _get_enemy_defense_bonus(actor)
	return _statuses.get_effective_defense(actor, base_defense) if _statuses != null else base_defense


## Afinidades elementales Fase 1 — WEAK/RESIST/inmune sobre un daño ya
## calculado por CombatMath (sin tocarlo). Puramente aditivo: sin datos de
## elemento en ninguno de los dos lados, AffinityResolver devuelve el mismo
## daño sin cambios. Ver scripts/combat/affinity_resolver.gd.
func _resolve_elemental_damage(base_damage: int, attacker: CombatActor, target: CombatActor) -> int:
	if attacker == null or target == null:
		return base_damage
	var damage_type: StringName = _attacker_damage_type(attacker)
	var target_enemy_data: EnemyData = target.source_data as EnemyData
	var no_tags: Array[StringName] = []
	var resistance_tags: Array[StringName] = target_enemy_data.resistance_tags if target_enemy_data != null else no_tags
	var weakness_tags: Array[StringName] = target_enemy_data.weakness_tags if target_enemy_data != null else no_tags
	var immunity_tags: Array[StringName] = target_enemy_data.immunity_tags if target_enemy_data != null else no_tags
	if target_enemy_data == null and target.actor_type == CombatActor.ActorType.PLAYER:
		resistance_tags = _player_equipment_resistance_tags()
	return int(AffinityResolver.resolve_damage_preview(base_damage, damage_type, resistance_tags, weakness_tags, immunity_tags)["damage"])


## Equipment 2.0 Fase 1 — resistencia elemental del jugador vía CHEST/HEAD/
## CAPE/RELIC (ver EquipmentData.resistance_affinity_id). Reutiliza el mismo
## mecanismo de tags que ya usan los enemigos (AffinityResolver), no un
## cálculo de magnitud paralelo: la presencia del tag ya aplica el mismo
## multiplicador de resistencia existente; resistance_bonus queda como dato
## para tuning futuro, no pondera el resultado todavía. INITIAL TUNING.
func _player_equipment_resistance_tags() -> Array[StringName]:
	var tags: Array[StringName] = []
	if RunManager.current_run == null:
		return tags
	for affinity_id: StringName in RunManager.current_run.equipment_resistance_bonuses:
		if float(RunManager.current_run.equipment_resistance_bonuses[affinity_id]) > 0.0:
			tags.append(affinity_id)
	return tags


func _attacker_damage_type(attacker: CombatActor) -> StringName:
	if attacker.actor_type == CombatActor.ActorType.PLAYER:
		var weapon: EquipmentData = EquipmentCatalog.get_by_id(String(RunManager.current_run.equipped_weapon_id))
		return weapon.element_type if weapon != null else AffinityResolver.PHYSICAL
	var enemy_data: EnemyData = attacker.source_data as EnemyData
	return enemy_data.primary_damage_type if enemy_data != null else AffinityResolver.PHYSICAL


func _enemy_ai_rng(actor: CombatActor, state: EnemyAIRuntimeState) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var actor_mix: int = String(actor.actor_id).hash()
	var position_mix: int = (RunManager.current_run.board_position + 1) * 104729
	var combat_mix: int = (RunManager.current_run.combats_won + 1) * 4099
	var turn_mix: int = (state.turn_count + 1) * 65537
	rng.seed = absi(RunManager.current_run.board_seed ^ actor_mix ^ position_mix ^ combat_mix ^ turn_mix ^ 0x46A1)
	return rng


func _plan_all_enemy_intents() -> void:
	if _result_resolved:
		return
	for actor_id: StringName in _enemy_intents.keys():
		var previous: EnemyIntent = _enemy_intents.get(actor_id) as EnemyIntent
		if previous != null:
			previous.invalidate(&"new_round")
	_enemy_intents.clear()
	for actor: CombatActor in _get_enemy_formation_actors():
		if actor.is_alive():
			_plan_enemy_intent(actor)
	_refresh_intent_ui()


func _plan_enemy_intent(actor: CombatActor) -> EnemyIntent:
	if actor == null or not actor.is_alive() or _result_resolved:
		return null
	var state: EnemyAIRuntimeState = _get_enemy_ai_state(actor)
	var profile: EnemyAIData = _get_enemy_ai_profile(actor)
	var forced_action: EnemyActionData = _boss_controller.get_forced_action(actor) if _boss_controller != null else null
	var excluded_actions: Array[StringName] = []
	if _boss_controller != null:
		excluded_actions = _boss_controller.get_excluded_action_ids(actor)
	_intent_plan_sequence += 1
	var intent: EnemyIntent = EnemyIntentPlanner.plan(
		actor,
		profile,
		state,
		get_alive_player_actors(),
		_enemy_ai_rng(actor, state),
		_intent_plan_sequence,
		forced_action,
		excluded_actions,
	)
	if intent == null:
		return null
	_populate_intent_estimate(intent)
	_enemy_intents[actor.actor_id] = intent
	TelemetryManager.track_enemy_intent_shown(
		intent.category_name_for_telemetry(),
		intent.get_intensity_name().to_lower().replace(" ", "_"),
		intent.target_actor != null,
		actor.actor_type == CombatActor.ActorType.BOSS,
	)
	return intent


func _populate_intent_estimate(intent: EnemyIntent) -> void:
	if intent == null or intent.action == null:
		return
	if intent.category == EnemyIntent.Category.SUMMON and _boss_controller != null:
		var summon_phase: BossPhaseData = _boss_controller.get_pending_summon_phase()
		if summon_phase != null and summon_phase.summon_data != null:
			intent.summon_type = summon_phase.summon_data.id
			intent.summon_count = mini(
				_boss_controller.get_pending_summon_count(),
				_boss_controller.data.max_active_enemies - enemy_actors.size(),
			)
		return
	if intent.action.action_type not in [EnemyAIEnums.ActionType.ATTACK, EnemyAIEnums.ActionType.ATTACK_STATUS]:
		return
	var target: CombatActor = intent.target_actor
	if target == null:
		return
	var base_attack: int = intent.source_actor.get_attack()
	if _boss_controller != null and _boss_controller.owns_actor(intent.source_actor):
		base_attack = maxi(1, roundi(float(base_attack) * _boss_controller.get_attack_multiplier()))
	var effective_attack: int = _statuses.get_effective_attack(intent.source_actor, base_attack)
	var raw_damage: int = _resolve_elemental_damage(CombatMath.calculate_damage(effective_attack, _get_effective_actor_defense(target)), intent.source_actor, target)
	raw_damage = _statuses.get_effective_incoming_damage(target, raw_damage)
	var estimated_damage: int = maxi(1, roundi(float(raw_damage) * intent.action.power_multiplier))
	# Boons, equipment y Guard pueden cambiar antes de ejecutar: la UI lo marca aproximado.
	intent.update_damage_estimate(estimated_damage, target, false)


func _refresh_intent_estimates() -> void:
	for intent: EnemyIntent in _enemy_intents.values():
		if intent != null and intent.is_valid:
			_populate_intent_estimate(intent)
	_refresh_intent_ui()


func _get_enemy_intent(actor: CombatActor) -> EnemyIntent:
	return _enemy_intents.get(actor.actor_id) as EnemyIntent if actor != null else null


func _consume_enemy_intent(actor: CombatActor) -> void:
	if actor == null:
		return
	_enemy_intents.erase(actor.actor_id)
	_refresh_intent_ui()


func _invalidate_enemy_intent(actor: CombatActor, reason: StringName, track_kill: bool = false) -> void:
	var intent: EnemyIntent = _get_enemy_intent(actor)
	if intent == null:
		return
	intent.invalidate(reason)
	if track_kill:
		TelemetryManager.track_enemy_killed_before_intent_execution(intent.category_name_for_telemetry())
	_enemy_intents.erase(actor.actor_id)
	_refresh_intent_ui()


func _refresh_intent_ui() -> void:
	if enemy_intent_badge != null:
		var selected_intent: EnemyIntent = _get_enemy_intent(selected_enemy_actor)
		enemy_intent_badge.visible = selected_intent != null and selected_intent.is_valid
		if enemy_intent_badge.visible:
			var global_intent_text: String = selected_intent.get_category_name()
			if selected_intent.category == EnemyIntent.Category.STATUS and not selected_intent.status_effect.is_empty():
				global_intent_text += " · %s" % selected_intent.get_status_display_name()
			enemy_intent_badge.configure(
				selected_intent.get_icon_id(),
				global_intent_text,
				_intent_badge_variant(selected_intent),
				AshenIcon.DisplaySize.SMALL,
				selected_intent.get_compact_counter(),
			)
	for slot: EnemyCombatSlot in _enemy_slots:
		slot.set_intent(_get_enemy_intent(slot.actor))
	_update_selected_intent_detail()


func _update_selected_intent_detail() -> void:
	if action_panel == null or action_label == null or _phase != CombatPhase.PLAYER_INPUT:
		return
	var intent: EnemyIntent = _get_enemy_intent(selected_enemy_actor)
	if intent == null:
		action_panel.visible = false
		return
	action_panel.visible = true
	action_label.add_theme_font_size_override("font_size", 13)
	action_label.tooltip_text = intent.get_detail_text(_get_enemy_ai_profile(selected_enemy_actor).get_role_name())
	action_label.text = "%s  ·  %s  ·  %s" % [
		intent.action.display_name.to_upper() if intent.action != null else intent.get_category_name(),
		intent.get_compact_target_name(),
		intent.get_compact_counter(),
	]


func _intent_badge_variant(intent: EnemyIntent) -> AshenBadge.Variant:
	match intent.category:
		EnemyIntent.Category.DEFEND:
			return AshenBadge.Variant.NEUTRAL
		EnemyIntent.Category.SUPPORT:
			return AshenBadge.Variant.HEAL
		EnemyIntent.Category.SUMMON, EnemyIntent.Category.SPECIAL:
			return AshenBadge.Variant.SYNERGY
		_:
			return AshenBadge.Variant.DANGER


func debug_get_enemy_intent_report() -> Array[String]:
	var report: Array[String] = []
	if not DebugConfig.DEBUG_TOOLS_ENABLED and not DebugConfig.is_visual_slice_enabled():
		return report
	for actor: CombatActor in _get_enemy_formation_actors():
		var intent: EnemyIntent = _get_enemy_intent(actor)
		if intent != null:
			report.append(intent.get_debug_text())
	return report


func get_primary_player_actor() -> CombatActor:
	return player_actor


func get_primary_enemy_actor() -> CombatActor:
	return selected_enemy_actor


func refresh_primary_enemy_actor() -> CombatActor:
	if _is_valid_enemy_target(selected_enemy_actor):
		_sync_selected_enemy_adapter()
		return selected_enemy_actor
	for candidate: CombatActor in enemy_actors:
		if candidate.is_targetable():
			_set_selected_enemy_actor(candidate, false)
			return selected_enemy_actor
	_clear_selected_enemy_actor()
	return null


func _is_valid_enemy_target(candidate: CombatActor) -> bool:
	return (
		candidate != null
		and candidate.team == CombatActor.Team.ENEMY
		and candidate.is_targetable()
		and candidate in enemy_actors
	)


func _set_selected_enemy_actor(candidate: CombatActor, play_feedback: bool = true) -> bool:
	if _result_resolved or not _is_valid_enemy_target(candidate):
		return false
	if get_tree().paused:
		return false
	var changed: bool = selected_enemy_actor != candidate
	selected_enemy_actor = candidate
	_sync_selected_enemy_adapter()
	_update_target_highlights()
	_update_selected_intent_detail()
	if changed and play_feedback:
		AudioManager.play_sfx(AudioManager.Sfx.UI_CLICK, 1.0, -7.0)
		if _phase == CombatPhase.PLAYER_INPUT and _get_enemy_intent(candidate) != null:
			TelemetryManager.track_player_target_changed_after_intent(
				_get_enemy_intent(candidate).category_name_for_telemetry(),
			)
	return true


func _sync_selected_enemy_adapter() -> void:
	enemy_actor = selected_enemy_actor
	if enemy_actor != null and is_instance_valid(enemy_actor.visual_view):
		enemy_view = enemy_actor.visual_view


func _clear_selected_enemy_actor() -> void:
	selected_enemy_actor = null
	enemy_actor = null
	_update_target_highlights()
	_refresh_intent_ui()


func _update_target_highlights() -> void:
	if is_instance_valid(enemy_view):
		enemy_view.set_targeted(enemy_actors.size() == 1 and enemy_actor == selected_enemy_actor)
	for slot: EnemyCombatSlot in _enemy_slots:
		slot.set_selected(slot.actor == selected_enemy_actor)


func _on_enemy_target_requested(requested_actor: CombatActor) -> void:
	if not _can_change_target():
		return
	_set_selected_enemy_actor(requested_actor)


func _can_change_target() -> bool:
	return (
		not _result_resolved
		and (_phase == CombatPhase.PLAYER_INPUT or _phase == CombatPhase.ENEMY_ACTION)
	)


func _input(event: InputEvent) -> void:
	if not _can_change_target() or get_tree().paused or event.is_echo():
		return
	var direction: int = 0
	if event.is_action_pressed(&"ui_right"):
		direction = 1
	elif event.is_action_pressed(&"ui_left"):
		direction = -1
	if direction == 0 or get_alive_enemy_actors().size() <= 1:
		return
	_cycle_selected_enemy(direction)
	get_viewport().set_input_as_handled()


func _cycle_selected_enemy(direction: int) -> void:
	var available_targets: Array[CombatActor] = []
	for candidate: CombatActor in _get_enemy_formation_actors():
		if _is_valid_enemy_target(candidate):
			available_targets.append(candidate)
	if available_targets.is_empty():
		return
	var current_index: int = available_targets.find(selected_enemy_actor)
	if current_index < 0:
		current_index = 0
	var next_index: int = posmod(current_index + direction, available_targets.size())
	_set_selected_enemy_actor(available_targets[next_index])


func get_enemy_actor_by_id(runtime_id: StringName) -> CombatActor:
	for candidate: CombatActor in enemy_actors:
		if candidate.actor_id == runtime_id:
			return candidate
	return null


func has_alive_enemies() -> bool:
	return not get_alive_enemy_actors().is_empty()


func _apply_character_visuals() -> void:
	player_view.setup_visual(player_actor.visual_data, "ASH")
	if companion_actor != null:
		player_view.anchor_right = 0.68
		companion_view.setup_visual(companion_actor.visual_data, "COMPAÑERO")
		companion_view.show()
		companion_panel.show()
	else:
		player_view.anchor_right = 0.8
		companion_view.hide()
		companion_panel.hide()
	var run_weapon: EquipmentData = EquipmentCatalog.get_by_id(String(RunManager.current_run.equipped_weapon_id))
	var run_armor: EquipmentData = EquipmentCatalog.get_by_id(String(RunManager.current_run.equipped_armor_id))
	player_view.setup_equipment_visuals(run_weapon, run_armor)
	if enemy_actors.size() == 1:
		enemy_formation.hide()
		enemy_view.show()
		enemy_panel.show()
		enemy_view.setup_visual(enemy_actor.visual_data, enemy_view.fallback_label.text)
		enemy_actor.set_visual_view(enemy_view)
		if enemy_actor.visual_data != null:
			enemy_name_label.modulate = enemy_actor.visual_data.accent
		return
	enemy_view.hide()
	enemy_panel.hide()
	enemy_formation.show()
	_build_enemy_slots()
	refresh_primary_enemy_actor()


func _get_enemy_formation_actors() -> Array[CombatActor]:
	var ordered: Array[CombatActor] = []
	for formation_index: int in range(MAX_ENEMY_ACTORS):
		for candidate: CombatActor in enemy_actors:
			if candidate.formation_slot == formation_index:
				ordered.append(candidate)
	return ordered


func _build_enemy_slots() -> void:
	for child: Node in enemy_formation.get_children():
		enemy_formation.remove_child(child)
		child.queue_free()
	_enemy_slots.clear()
	var formation_actors: Array[CombatActor] = _get_enemy_formation_actors()
	var count: int = formation_actors.size()
	var fixed_boss_formation: bool = _boss_controller != null and count > 1
	var slot_width: float = 1.0 / float(MAX_ENEMY_ACTORS if fixed_boss_formation else count)
	for slot_index: int in range(count):
		var slot_actor: CombatActor = formation_actors[slot_index]
		var visual_slot: int = slot_actor.formation_slot if fixed_boss_formation else slot_index
		var slot: EnemyCombatSlot = EnemyCombatSlot.new()
		slot.name = "EnemySlot%d" % slot_index
		slot.anchor_left = slot_width * float(visual_slot)
		slot.anchor_right = slot_width * float(visual_slot + 1)
		slot.anchor_bottom = 1.0
		slot.grow_horizontal = Control.GROW_DIRECTION_BOTH
		slot.grow_vertical = Control.GROW_DIRECTION_BOTH
		enemy_formation.add_child(slot)
		var hud_mode: EnemyCombatSlot.HUDMode = EnemyCombatSlot.HUDMode.FULL
		if slot_actor.actor_type == CombatActor.ActorType.BOSS:
			hud_mode = EnemyCombatSlot.HUDMode.HIDDEN
		elif slot_actor.actor_type == CombatActor.ActorType.MINION:
			hud_mode = EnemyCombatSlot.HUDMode.MINION
		slot.setup(slot_actor, _biome.accent_color, hud_mode)
		slot.target_requested.connect(_on_enemy_target_requested)
		_enemy_slots.append(slot)
	_update_target_highlights()


func _activate_boss_formation() -> void:
	if _boss_controller == null:
		return
	enemy_view.hide()
	enemy_formation.anchor_top = 0.135
	enemy_formation.show()
	enemy_panel.show()
	_build_enemy_slots()
	refresh_primary_enemy_actor()


func _update_enemy_slots() -> void:
	for slot: EnemyCombatSlot in _enemy_slots:
		slot.update_actor(
			_statuses.get_effective_attack(slot.actor, slot.actor.get_attack()),
			_get_effective_actor_defense(slot.actor),
		)
		slot.set_intent(_get_enemy_intent(slot.actor))


func _run_combat() -> void:
	await vfx.play_entrance(_boons.has_pyre_heart_active())
	if enemy_actors.size() > 1:
		action_label.text = "%d enemigos emergen de la ceniza.%s" % [
			enemy_actors.size(),
			" PHOENIX BLOOD · Pyre Heart potenciado." if _boons.is_phoenix_empowered() else "",
		]
	else:
		action_label.text = "%s emerge de la ceniza.%s" % [
			enemy_actor.display_name,
			" PHOENIX BLOOD · Pyre Heart potenciado." if _boons.is_phoenix_empowered() else "",
		]
	if _boons.is_phoenix_empowered():
		_set_action_badge(&"phoenix_blood", "PHOENIX BLOOD", AshenBadge.Variant.SYNERGY)
	else:
		_set_action_badge(&"combat", "ENCUENTRO", AshenBadge.Variant.DANGER)
	if _boons.is_phoenix_empowered():
		AudioManager.play_event(AudioManager.AudioEvent.SYNERGY_ACTIVATE)
	await _wait(TURN_DELAY)
	_plan_all_enemy_intents()

	while player_actor.is_alive() and has_alive_enemies():
		await _wait_for_player_action()
		if _result_resolved:
			return
		match _pending_player_action:
			PlayerAction.BASIC_ATTACK:
				if await _run_player_basic_action(_committed_target_actor):
					return
				var energy_gained: int = _skill_loadout.on_basic_attack_completed()
				_update_skill_ui()
				var companion_tutorial_pending: bool = (
					companion_actor != null
					and not TutorialManager.is_completed(TutorialCatalog.COMPANION_COMBAT)
					and _player_actions_completed == 0
				)
				if energy_gained > 0 and not companion_tutorial_pending:
					if not await TutorialManager.request_and_wait(TutorialCatalog.ENERGY_GAIN, TutorialManager.CONTEXT_COMBAT, self):
						return
			PlayerAction.ACTIVE_SKILL:
				if await _execute_active_skill(_committed_skill, _committed_target_actor):
					return
			_:
				continue
		_player_actions_completed += 1
		_statuses.process_turn_end(player_actor)
		if await _run_companion_action():
			return
		_pending_player_action = PlayerAction.NONE
		_committed_target_actor = null
		_committed_skill = null
		_phase = CombatPhase.ENEMY_ACTION
		_refresh_action_bar()
		if await _run_enemy_round():
			return


func _run_companion_action() -> bool:
	if companion_actor == null or not companion_actor.is_alive() or _companion_runtime == null:
		return false
	if not await TutorialManager.request_and_wait(TutorialCatalog.COMPANION_COMBAT, TutorialManager.CONTEXT_COMBAT, self):
		return true
	if _result_resolved:
		return true
	if await _process_actor_turn_start(companion_actor):
		_statuses.process_turn_end(companion_actor)
		await _present_companion_death()
		_update_combatants()
		return false
	var companion_data: CompanionData = companion_actor.source_data as CompanionData
	if companion_data == null:
		return false
	var plan: CompanionActionResolver.ActionPlan = CompanionActionResolver.build_plan(
		companion_actor,
		companion_data,
		_companion_runtime,
		selected_enemy_actor,
		enemy_actors,
		_statuses,
		_get_enemy_defense_bonus(CompanionActionResolver.choose_target(selected_enemy_actor, enemy_actors)),
	)
	if plan.target == null:
		await _finish_victory(null)
		return true
	var target_actor: CombatActor = plan.target
	var target_view: CombatCharacterView = target_actor.visual_view
	var action_name: String = companion_data.ability_name if plan.uses_ability else "ATAQUE"
	_set_turn(companion_actor.display_name.to_upper(), Color("ed7b32"))
	target_actor.apply_damage(_statuses.get_effective_incoming_damage(target_actor, plan.damage))
	var burn_applied: bool = false
	if plan.uses_ability and target_actor.is_alive() and not companion_data.ability_status_id.is_empty():
		burn_applied = _statuses.apply_status(
			target_actor,
			companion_data.ability_status_id,
			companion_actor,
			companion_data.ability_status_stacks,
		) != null
	companion_view.play_attack(
		CombatChoreographyController.AGGRESSIVE_DURATION if plan.uses_ability else CombatChoreographyController.MELEE_DURATION
	)
	await choreography.approach(
		companion_view,
		target_view,
		companion_actor.actor_type,
		CombatChoreographyController.MotionStyle.AGGRESSIVE if plan.uses_ability else CombatChoreographyController.MotionStyle.MELEE,
	)
	AudioManager.play_event(
		AudioManager.AudioEvent.COMPANION_SPECIAL if plan.uses_ability else AudioManager.AudioEvent.COMPANION_ATTACK,
	)
	var feedback: Array[String] = []
	if plan.passive_triggered:
		feedback.append("EMBER HUNTER +15%")
	if burn_applied:
		feedback.append("QUEMADURA ×%d" % companion_data.ability_status_stacks)
	action_label.text = "%s · %s\n%s -%d VIDA%s" % [
		companion_actor.display_name.to_upper(),
		action_name.to_upper(),
		target_actor.display_name.to_upper(),
		plan.damage,
		"\n" + " · ".join(feedback) if not feedback.is_empty() else "",
	]
	_set_action_badge(
		&"burn" if plan.uses_ability else &"attack",
		action_name.to_upper(),
		AshenBadge.Variant.EMBER,
	)
	_animate_action_feedback(Color("ed7b32"))
	_update_combatants()
	target_view.play_hit(
		CombatChoreographyController.AGGRESSIVE_DURATION if plan.uses_ability else CombatChoreographyController.MELEE_DURATION
	)
	vfx.player_attack_target(target_view, plan.uses_ability)
	vfx.show_damage_number(target_view, plan.damage, false, false, Color("ffb14d") if plan.uses_ability else Color("fff0df"))
	await choreography.impact_and_return(
		CombatChoreographyController.EMPHASIZED_HIT_STOP_DURATION if plan.uses_ability else CombatChoreographyController.HIT_STOP_DURATION,
	)
	await _check_boss_phase_transition()
	_companion_runtime.record_action()
	_statuses.process_turn_end(companion_actor)
	if companion_actor.is_alive():
		companion_view.play_idle()
	if target_actor.is_alive():
		target_view.play_idle()
	if not target_actor.is_alive():
		if _is_defeated_boss(target_actor) or not has_alive_enemies():
			await _finish_victory(target_actor)
			return true
		await _present_enemy_death(target_actor)
		refresh_primary_enemy_actor()
	_update_combatants()
	return false


func _wait_for_player_action() -> void:
	_synergy_runtime.begin_player_turn()
	if await _process_actor_turn_start(player_actor):
		if not player_actor.is_alive():
			await _finish_defeat()
		return
	if refresh_primary_enemy_actor() == null:
		return
	_refresh_intent_estimates()
	_phase = CombatPhase.TRANSITION
	_refresh_action_bar()
	var contextual_tutorial_shown: bool = false
	if _player_actions_completed == 0:
		if enemy_actors.size() > 1 and not TutorialManager.is_completed(TutorialCatalog.TARGET_SELECTION):
			if not await TutorialManager.request_and_wait(TutorialCatalog.TARGET_SELECTION, TutorialManager.CONTEXT_COMBAT, self):
				return
			contextual_tutorial_shown = true
			TutorialManager.complete_without_presenting(TutorialCatalog.COMBAT_AUTO)
		elif not TutorialManager.is_completed(TutorialCatalog.COMBAT_AUTO):
			if not await TutorialManager.request_and_wait(TutorialCatalog.COMBAT_AUTO, TutorialManager.CONTEXT_COMBAT, self):
				return
			contextual_tutorial_shown = true
	elif _has_mixed_enemy_roles() and not TutorialManager.is_completed(TutorialCatalog.ENEMY_AI):
		if not await TutorialManager.request_and_wait(TutorialCatalog.ENEMY_AI, TutorialManager.CONTEXT_COMBAT, self):
			return
		contextual_tutorial_shown = true
	if _result_resolved:
		return
	var ready_skill: ActiveSkillController = null
	if not contextual_tutorial_shown:
		ready_skill = _skill_loadout.consume_ready_skill()
	if ready_skill != null:
		if not await TutorialManager.request_and_wait(TutorialCatalog.COMBAT_ACTIVE_SKILL, TutorialManager.CONTEXT_COMBAT, self):
			return
		TutorialManager.complete_without_presenting(TutorialCatalog.SKILL_READY)
		if _result_resolved:
			return
		AudioManager.play_event(AudioManager.AudioEvent.SKILL_READY, 1.0, -5.0)
	_phase = CombatPhase.PLAYER_INPUT
	_pending_player_action = PlayerAction.NONE
	_committed_target_actor = null
	_committed_skill = null
	_set_turn("TU TURNO", VisualTheme.EMBER_BRIGHT)
	action_label.text = "Elegí una acción."
	if ready_skill != null:
		_set_action_badge(&"skill", "%s LISTA" % ready_skill.skill.display_name.to_upper(), AshenBadge.Variant.EMBER)
	else:
		_set_action_badge(&"attack", "ELEGÍ UNA ACCIÓN", AshenBadge.Variant.EMBER)
	_update_selected_intent_detail()
	_refresh_action_bar()
	attack_button.grab_focus.call_deferred()
	await player_action_committed


func _has_mixed_enemy_roles() -> bool:
	var roles: Dictionary[int, bool] = {}
	for actor: CombatActor in get_alive_enemy_actors():
		roles[_get_enemy_ai_profile(actor).role] = true
	return roles.size() > 1


func _commit_player_action(action: PlayerAction, captured_target: CombatActor) -> void:
	if _phase != CombatPhase.PLAYER_INPUT or _result_resolved:
		return
	_pending_player_action = action
	_committed_target_actor = captured_target
	_telemetry_turn_count += 1
	if action == PlayerAction.ACTIVE_SKILL and _committed_skill != null:
		TelemetryManager.record_skill_use(RunManager.current_run, _committed_skill.skill.id)
		var relevant_intent: EnemyIntent = _get_enemy_intent(captured_target)
		if relevant_intent == null:
			for incoming: EnemyIntent in _enemy_intents.values():
				if incoming != null and incoming.target_actor == player_actor and (
					relevant_intent == null or incoming.intensity > relevant_intent.intensity
				):
					relevant_intent = incoming
		if _committed_skill.skill.id == ActiveSkillCatalog.ASHEN_GUARD.id:
			var dangerous_count: int = 0
			for planned: EnemyIntent in _enemy_intents.values():
				if planned != null and planned.target_actor == player_actor and planned.estimated_damage > 0:
					dangerous_count += 1
			TelemetryManager.track_guard_used_against_attack_intent(dangerous_count)
		elif relevant_intent != null and relevant_intent.intensity >= EnemyIntent.Intensity.HIGH:
			TelemetryManager.track_skill_used_against_high_threat(
				_committed_skill.skill.id,
				relevant_intent.category_name_for_telemetry(),
			)
	action_panel.visible = false
	_phase = CombatPhase.PLAYER_ACTION
	_refresh_action_bar()
	player_action_committed.emit()


func _run_player_basic_action(captured_target: CombatActor) -> bool:
	var target_actor: CombatActor = captured_target
	if not _is_valid_enemy_target(target_actor):
		target_actor = refresh_primary_enemy_actor()
	if target_actor == null:
		await _finish_victory(null)
		return true
	var target_view: CombatCharacterView = target_actor.visual_view
	_set_turn("TURNO DEL JUGADOR", VisualTheme.EMBER_BRIGHT)
	var target_was_burning: bool = target_actor.has_status(&"burn")
	var effective_attack: int = _statuses.get_effective_attack(player_actor, _boons.before_player_attack())
	var target_defense: int = _get_effective_actor_defense(target_actor)
	var player_damage: int = _resolve_elemental_damage(CombatMath.calculate_damage(effective_attack, target_defense), player_actor, target_actor)
	player_damage = EquipmentEffectResolver.apply_basic_attack_damage(player_damage, RunManager.current_run)
	var critical_hit: bool = EquipmentEffectResolver.roll_critical(RunManager.current_run, _equipment_rng)
	if critical_hit:
		player_damage = EquipmentEffectResolver.apply_critical_damage(player_damage, RunManager.current_run)
	target_actor.apply_damage(_statuses.get_effective_incoming_damage(target_actor, player_damage))
	var equipment_statuses: Array[StringName] = EquipmentEffectResolver.apply_basic_hit_statuses(
		RunManager.current_run, player_actor, target_actor, _statuses, _equipment_runtime,
	)
	var burning_damage: int = _boons.after_player_attack()
	if burning_damage > 0:
		target_actor.apply_damage(_statuses.get_effective_incoming_damage(target_actor, burning_damage))
		if target_actor.is_alive():
			var burn_stacks: int = 1
			if SynergyResolver.is_active(&"inferno_rhythm", RunManager.current_run):
				burn_stacks += 1
			_statuses.apply_status(target_actor, &"burn", player_actor, burn_stacks)
	var player_feedback: Array[String] = []
	var synergy_energy: int = 0
	if critical_hit:
		synergy_energy += SynergyEffectResolver.on_critical_hit(RunManager.current_run, _synergy_runtime, _skill_loadout)
	synergy_energy += SynergyEffectResolver.on_burning_basic_attack(
		RunManager.current_run, _synergy_runtime, _skill_loadout, target_was_burning,
	)
	if burning_damage > 0:
		player_feedback.append("Burning Strike +%d · QUEMADURA" % burning_damage)
	if critical_hit:
		player_feedback.append("CRÍTICO")
	if &"burn" in equipment_statuses:
		player_feedback.append("QUEMADURA ×1")
	if &"armor_break" in equipment_statuses:
		player_feedback.append("RUPTURA DE ARMADURA ×1")
	if synergy_energy > 0:
		player_feedback.append("SINERGIA · +%d BRASA" % synergy_energy)
	if _boons.was_inferno_triggered():
		player_feedback.append("INFERNO RHYTHM · +2 Relentless")
	player_view.play_attack(CombatChoreographyController.MELEE_DURATION)
	await choreography.approach(
		player_view,
		target_view,
		player_actor.actor_type,
		CombatChoreographyController.MotionStyle.MELEE,
	)
	AudioManager.play_event(AudioManager.AudioEvent.BASIC_ATTACK)
	if critical_hit:
		AudioManager.play_event(AudioManager.AudioEvent.CRITICAL)
	if _boons.was_inferno_triggered():
		AudioManager.play_event(AudioManager.AudioEvent.SYNERGY_ACTIVATE)
	action_label.text = "%s\n-%d VIDA%s" % [
		target_actor.display_name.to_upper(), player_damage,
		"\n" + " · ".join(player_feedback) if not player_feedback.is_empty() else "",
	]
	if critical_hit:
		_set_action_badge(&"attack", "CRÍTICO", AshenBadge.Variant.DANGER)
	elif _boons.was_inferno_triggered():
		_set_action_badge(&"inferno_rhythm", "INFERNO RHYTHM", AshenBadge.Variant.SYNERGY)
	elif burning_damage > 0:
		_set_action_badge(&"burning_strike", "BURNING STRIKE", AshenBadge.Variant.EMBER)
	else:
		_set_action_badge(&"attack", "IMPACTO", AshenBadge.Variant.DANGER)
	_animate_action_feedback(VisualTheme.DANGER)
	_update_combatants()
	target_view.play_hit(CombatChoreographyController.MELEE_DURATION)
	vfx.player_attack_target(target_view, burning_damage > 0, critical_hit)
	vfx.show_damage_number(target_view, player_damage, critical_hit)
	if burning_damage > 0:
		vfx.show_damage_number(target_view, burning_damage, false, false, Color("ff8d36"), 0.08)
	await choreography.impact_and_return(
		CombatChoreographyController.EMPHASIZED_HIT_STOP_DURATION if critical_hit else CombatChoreographyController.HIT_STOP_DURATION,
	)
	await _check_boss_phase_transition()
	player_view.play_idle()
	if target_actor.is_alive():
		target_view.play_idle()
		if _boss_controller != null and _boss_controller.can_counter_basic(target_actor):
			if await _resolve_warden_counter(target_actor):
				return true
	if not target_actor.is_alive():
		if _is_defeated_boss(target_actor) or not has_alive_enemies():
			await _finish_victory(target_actor)
			return true
		await _present_enemy_death(target_actor)
		refresh_primary_enemy_actor()
		_update_combatants()
	return false


func _run_enemy_round() -> bool:
	_phase = CombatPhase.ENEMY_ACTION
	_refresh_action_bar()
	var round_actors: Array[CombatActor] = []
	for round_actor: CombatActor in enemy_actors:
		round_actors.append(round_actor)
	for attacking_actor: CombatActor in round_actors:
		if not attacking_actor.is_alive():
			continue
		if await _run_enemy_action(attacking_actor):
			return true
	if not _result_resolved and player_actor.is_alive() and has_alive_enemies():
		_plan_all_enemy_intents()
	return false


func _run_enemy_action(attacking_actor: CombatActor) -> bool:
	if await _process_actor_turn_start(attacking_actor):
		if not attacking_actor.is_alive():
			_statuses.process_turn_end(attacking_actor)
			if _is_defeated_boss(attacking_actor):
				await _finish_victory(attacking_actor)
				return true
			await _present_enemy_death(attacking_actor)
			refresh_primary_enemy_actor()
			_update_combatants()
			if not has_alive_enemies():
				await _finish_victory(attacking_actor)
				return true
		return false
	var ai_state: EnemyAIRuntimeState = _get_enemy_ai_state(attacking_actor)
	ai_state.begin_turn()
	_update_combatants()
	var intent: EnemyIntent = _get_enemy_intent(attacking_actor)
	if intent == null or not intent.can_execute():
		intent = _plan_enemy_intent(attacking_actor)
	var decision: EnemyActionResolver.Decision = EnemyActionResolver.Decision.new()
	if intent == null or not intent.can_execute():
		_statuses.process_turn_end(attacking_actor)
		return false
	decision.action = intent.action
	decision.target = intent.resolve_execution_target(get_alive_player_actors())
	if decision.action.is_special():
		if not await TutorialManager.request_and_wait(TutorialCatalog.ENEMY_AI, TutorialManager.CONTEXT_COMBAT, self):
			return true
		if _result_resolved or not attacking_actor.is_alive():
			return _result_resolved
	if decision.action.action_type == EnemyAIEnums.ActionType.SUMMON:
		_consume_enemy_intent(attacking_actor)
		await _run_boss_summon_action(attacking_actor, decision.action, ai_state)
		_statuses.process_turn_end(attacking_actor)
		return false
	if decision.action.action_type == EnemyAIEnums.ActionType.SELF_BUFF:
		_consume_enemy_intent(attacking_actor)
		await _run_enemy_self_buff_action(attacking_actor, decision.action, ai_state)
		ai_state.record_action(decision.action)
		_statuses.process_turn_end(attacking_actor)
		return false
	if decision.target == null:
		intent.invalidate(&"no_valid_target")
		_consume_enemy_intent(attacking_actor)
		if not player_actor.is_alive():
			await _finish_defeat()
			return true
		_statuses.process_turn_end(attacking_actor)
		return false
	_consume_enemy_intent(attacking_actor)
	var target_actor: CombatActor = decision.target
	var target_view: CombatCharacterView = target_actor.visual_view
	var target_is_player: bool = target_actor == player_actor
	_set_turn("%s · %s" % [attacking_actor.display_name.to_upper(), decision.action.display_name.to_upper()], VisualTheme.DANGER)
	var attacking_view: CombatCharacterView = attacking_actor.visual_view
	var last_ember_before_hit: bool = _last_ember_active
	var effective_defense: int = _get_effective_actor_defense(target_actor)
	var base_enemy_attack: int = attacking_actor.get_attack()
	if _boss_controller != null and _boss_controller.owns_actor(attacking_actor):
		base_enemy_attack = maxi(1, roundi(float(base_enemy_attack) * _boss_controller.get_attack_multiplier()))
	var effective_enemy_attack: int = _statuses.get_effective_attack(attacking_actor, base_enemy_attack)
	var raw_enemy_damage: int = _resolve_elemental_damage(CombatMath.calculate_damage(effective_enemy_attack, effective_defense), attacking_actor, target_actor)
	var enemy_damage: int = maxi(1, roundi(float(raw_enemy_damage) * decision.action.power_multiplier))
	var equipment_reduction: int = 0
	var guard_controller: ActiveSkillController
	var stored_energy: int = 0
	var reprisal_damage: int = 0
	var counter_damage: int = 0
	var synergy_healing: int = 0
	var equipment_regen_applied: bool = false
	if target_is_player:
		enemy_damage = _boons.before_player_takes_damage(enemy_damage)
		var damage_before_equipment: int = enemy_damage
		enemy_damage = EquipmentEffectResolver.before_player_takes_damage(enemy_damage, RunManager.current_run, _equipment_runtime)
		equipment_reduction = damage_before_equipment - enemy_damage
		if player_actor.has_status(&"guard"):
			guard_controller = _skill_loadout.get_by_id(ActiveSkillCatalog.ASHEN_GUARD.id)
		if guard_controller != null:
			enemy_damage = guard_controller.apply_guard_to_damage(enemy_damage)
			_statuses.consume_hit_status(player_actor, &"guard")
	target_actor.apply_damage(_statuses.get_effective_incoming_damage(target_actor, enemy_damage))
	if target_is_player:
		_skill_loadout.on_damage_received(enemy_damage)
		synergy_healing = SynergyEffectResolver.on_guard_consumed(
			RunManager.current_run,
			_synergy_runtime,
			guard_controller != null and guard_controller.last_guard_consumed,
		)
		equipment_regen_applied = EquipmentEffectResolver.apply_guard_consumed_status(
			RunManager.current_run,
			player_actor,
			_statuses,
			_equipment_runtime,
			guard_controller != null and guard_controller.last_guard_consumed,
		)
		if guard_controller != null:
			stored_energy = _skill_loadout.add_energy(guard_controller.consume_stored_embers_energy())
		reprisal_damage = _boons.after_player_takes_damage()
		counter_damage = guard_controller.consume_counter_guard_damage() if guard_controller != null else 0
	var retaliation_damage: int = reprisal_damage + counter_damage
	if retaliation_damage > 0:
		attacking_actor.apply_damage(_statuses.get_effective_incoming_damage(attacking_actor, retaliation_damage))
	var feedback: Array[String] = []
	var status_applied: bool = false
	if decision.action.action_type == EnemyAIEnums.ActionType.ATTACK_STATUS and target_actor.is_alive():
		status_applied = _statuses.apply_status(
			target_actor,
			decision.action.status_id,
			attacking_actor,
			decision.action.status_stacks,
			decision.action.status_duration,
		) != null
	if status_applied:
		feedback.append(_enemy_status_feedback(decision.action.status_id))
	if target_is_player and _boons.get_last_cinder_reduction() > 0:
		feedback.append("CINDER SKIN · DAÑO REDUCIDO %d" % _boons.get_last_cinder_reduction())
	if equipment_reduction > 0:
		feedback.append("PLACA DEL GUARDIÁN · REDUCCIÓN %d" % equipment_reduction)
	if target_is_player and _boons.was_last_stand_triggered():
		feedback.append("LAST STAND · Segunda guardia")
	if reprisal_damage > 0:
		feedback.append("Reprisal %d" % reprisal_damage)
	if target_is_player and _boons.was_vengeance_triggered():
		feedback.append("ASHEN VENGEANCE · Reprisal +3")
	if guard_controller != null and guard_controller.last_guard_reduction > 0:
		feedback.append("GUARDIA · DAÑO REDUCIDO %d" % guard_controller.last_guard_reduction)
	if stored_energy > 0:
		feedback.append("Stored Embers +%d de Brasa" % stored_energy)
	if counter_damage > 0:
		feedback.append("Counter Guard %d" % counter_damage)
	if synergy_healing > 0:
		feedback.append("IRON VIGIL +%d VIDA" % synergy_healing)
	if equipment_regen_applied:
		feedback.append("REBROTE PROTEGIDO · REGENERACIÓN")
	attacking_view.play_attack(CombatChoreographyController.MELEE_DURATION)
	await choreography.approach(
		attacking_view,
		target_view,
		attacking_actor.actor_type,
		_enemy_motion_style(decision.action),
	)
	if guard_controller != null and guard_controller.last_guard_reduction > 0:
		AudioManager.play_event(AudioManager.AudioEvent.GUARD_CONSUMED)
	elif decision.action.is_special():
		AudioManager.play_event(AudioManager.AudioEvent.ENEMY_SPECIAL)
	else:
		AudioManager.play_event(AudioManager.AudioEvent.IMPACT_PLAYER)
	if target_is_player and (_boons.was_last_stand_triggered() or _boons.was_vengeance_triggered()):
		AudioManager.play_event(AudioManager.AudioEvent.SYNERGY_ACTIVATE)
	action_label.text = "%s · %s\n%s -%d VIDA%s" % [
		attacking_actor.display_name.to_upper(), decision.action.display_name.to_upper(),
		target_actor.display_name.to_upper(), enemy_damage,
		"\n" + " · ".join(feedback) if not feedback.is_empty() else "",
	]
	if target_is_player and _boons.was_vengeance_triggered():
		_set_action_badge(&"ashen_vengeance", "ASHEN VENGEANCE", AshenBadge.Variant.SYNERGY)
	elif target_is_player and _boons.was_last_stand_triggered():
		_set_action_badge(&"last_stand", "LAST STAND", AshenBadge.Variant.SYNERGY)
	elif guard_controller != null and guard_controller.last_guard_reduction > 0:
		_set_action_badge(&"block", "BLOQUEO", AshenBadge.Variant.NEUTRAL)
	elif target_is_player and _boons.get_last_cinder_reduction() > 0:
		_set_action_badge(&"cinder_skin", "CINDER SKIN", AshenBadge.Variant.NEUTRAL)
	elif status_applied:
		_set_action_badge(decision.action.status_id, _enemy_status_feedback(decision.action.status_id), AshenBadge.Variant.DANGER)
	elif decision.action.presentation_type == EnemyAIEnums.PresentationType.HEAVY:
		_set_action_badge(&"attack", "GOLPE PESADO", AshenBadge.Variant.DANGER)
	else:
		_set_action_badge(&"health", "DAÑO RECIBIDO", AshenBadge.Variant.DANGER)
	_animate_action_feedback(VisualTheme.DANGER)
	_update_combatants()
	var mitigation_badge: String = ""
	if guard_controller != null and guard_controller.last_guard_reduction > 0:
		mitigation_badge = "GUARDIA · DAÑO REDUCIDO"
	elif target_is_player and _boons.was_last_stand_triggered():
		mitigation_badge = "LAST STAND"
	elif target_is_player and _boons.get_last_cinder_reduction() > 0:
		mitigation_badge = "CINDER SKIN · DAÑO REDUCIDO"
	target_view.play_hit(CombatChoreographyController.MELEE_DURATION)
	vfx.enemy_attack_target_from(attacking_view, target_view, mitigation_badge, retaliation_damage > 0)
	vfx.show_damage_number(target_view, enemy_damage, false, false, Color("ff8a78"))
	await choreography.impact_and_return(
		CombatChoreographyController.HEAVY_HIT_STOP_DURATION
		if decision.action.presentation_type == EnemyAIEnums.PresentationType.HEAVY
		else CombatChoreographyController.HIT_STOP_DURATION,
	)
	await _check_boss_phase_transition()
	if target_is_player and status_applied:
		if not await TutorialManager.request_and_wait(TutorialCatalog.STATUS_EFFECTS, TutorialManager.CONTEXT_COMBAT, self):
			return true
	if attacking_actor.is_alive():
		attacking_view.play_idle()
	if target_actor.is_alive():
		target_view.play_idle()
	ai_state.record_action(decision.action)
	_statuses.process_turn_end(attacking_actor)
	if target_is_player:
		_last_ember_active = _boons.is_last_ember_active()
		if _last_ember_active != last_ember_before_hit:
			vfx.show_last_ember(_last_ember_active)
	if not player_actor.is_alive():
		await _finish_defeat()
		return true
	if target_actor == companion_actor and not target_actor.is_alive():
		await _present_companion_death()
		_update_combatants()
	if not attacking_actor.is_alive():
		if _is_defeated_boss(attacking_actor) or not has_alive_enemies():
			await _finish_victory(attacking_actor)
			return true
		await _present_enemy_death(attacking_actor)
		refresh_primary_enemy_actor()
		_update_combatants()
	return false


func _run_enemy_self_buff_action(
	attacking_actor: CombatActor,
	action: EnemyActionData,
	ai_state: EnemyAIRuntimeState,
) -> void:
	var attacking_view: CombatCharacterView = attacking_actor.visual_view
	_set_turn("%s - %s" % [attacking_actor.display_name.to_upper(), action.display_name.to_upper()], VisualTheme.DANGER)
	await choreography.begin_static(attacking_view)
	if _boss_controller != null and _boss_controller.is_counter_action(action):
		AudioManager.play_event(AudioManager.AudioEvent.BOSS_REBUKE)
		_boss_controller.arm_counter()
		action_label.text = "%s\nCONTRAATACA EL PRÓXIMO ATAQUE BÁSICO" % action.display_name.to_upper()
		_set_action_badge(&"counter_guard", "CONTRAATAQUE PREPARADO", AshenBadge.Variant.DANGER)
		await vfx.boss_telegraph(attacking_view, "WARDEN'S REBUKE", Color("c98842"))
	else:
		AudioManager.play_event(AudioManager.AudioEvent.STATUS_APPLY, 0.9, -5.0)
		ai_state.activate_guard_stance(action.defense_bonus)
		action_label.text = "%s\nDEF +%d HASTA SU PRÓXIMO TURNO" % [action.display_name.to_upper(), action.defense_bonus]
		_set_action_badge(&"defense", "POSTURA DEFENSIVA", AshenBadge.Variant.NEUTRAL)
		vfx.show_secondary("%s - DEF +%d" % [attacking_actor.display_name.to_upper(), action.defense_bonus], VisualTheme.EVENT)
	_animate_action_feedback(VisualTheme.EVENT)
	_update_combatants()
	await choreography.finish_static()
	if attacking_actor.is_alive():
		attacking_view.play_idle()


func _run_boss_summon_action(
	attacking_actor: CombatActor,
	action: EnemyActionData,
	ai_state: EnemyAIRuntimeState,
) -> void:
	if _boss_controller == null or not _boss_controller.owns_actor(attacking_actor):
		return
	var summon_phase: BossPhaseData = _boss_controller.get_pending_summon_phase()
	if summon_phase == null or summon_phase.summon_data == null:
		_boss_controller.mark_summon_completed()
		return
	var available_slots: Array[int] = [0, 2]
	var summon_total: int = mini(
		_boss_controller.get_pending_summon_count(),
		_boss_controller.data.max_active_enemies - enemy_actors.size(),
	)
	var summoned_actors: Array[CombatActor] = []
	for summon_index: int in range(summon_total):
		var minion_actor: CombatActor = CombatActor.from_enemy(
			StringName("minion_%d" % _next_minion_runtime_index),
			summon_phase.summon_data,
			CombatActor.ActorType.MINION,
		)
		_next_minion_runtime_index += 1
		minion_actor.formation_slot = available_slots[summon_index]
		enemy_actors.append(minion_actor)
		_enemy_ai_states[minion_actor.actor_id] = EnemyAIRuntimeState.new()
		summoned_actors.append(minion_actor)
	_boss_controller.mark_summon_completed()
	_activate_boss_formation()
	var boss_view: CombatCharacterView = attacking_actor.visual_view
	var add_views: Array[Control] = []
	for summoned_actor: CombatActor in summoned_actors:
		if is_instance_valid(summoned_actor.visual_view):
			add_views.append(summoned_actor.visual_view)
	_set_turn("%s · %s" % [attacking_actor.display_name.to_upper(), action.display_name.to_upper()], VisualTheme.BOSS)
	action_label.text = "%s\nEMBER SPAWN ×%d · ACTÚAN EN LA PRÓXIMA RONDA" % [action.display_name.to_upper(), summoned_actors.size()]
	_set_action_badge(&"ember", "INVOCACIÓN", AshenBadge.Variant.DANGER)
	_animate_action_feedback(summon_phase.visual_accent)
	_update_combatants()
	await choreography.begin_static(boss_view)
	AudioManager.play_event(AudioManager.AudioEvent.BOSS_SUMMON)
	await vfx.boss_summon(boss_view, add_views, summon_phase.visual_accent)
	await choreography.finish_static()
	if attacking_actor.is_alive():
		boss_view.play_idle()
	ai_state.record_action(action)
	if not await TutorialManager.request_and_wait(TutorialCatalog.BOSS_SUMMON, TutorialManager.CONTEXT_COMBAT, self):
		return


func _check_boss_phase_transition() -> void:
	if _boss_controller == null or _result_resolved:
		return
	var transition: BossEncounterController.TransitionResult = _boss_controller.check_phase_transition()
	if transition == null or transition.current_phase == null:
		return
	var current_phase: BossPhaseData = transition.current_phase
	var transitioned_boss: CombatActor = _boss_controller.get_boss_actor()
	_invalidate_enemy_intent(transitioned_boss, &"phase_changed")
	_plan_enemy_intent(transitioned_boss)
	_refresh_intent_ui()
	var phase_number: int = _boss_controller.runtime.current_phase_index + 1
	TelemetryManager.track_boss_phase(RunManager.current_run, _biome.boss.id, phase_number)
	var phase_title: String = "FASE %s · %s" % [_roman_phase(phase_number), current_phase.display_name.to_upper()]
	var transition_prefix: String = ""
	if transition.crossed_phases > 1:
		transition_prefix = "TRANSICIÓN ACELERADA · %d UMBRALES\n" % transition.crossed_phases
	_set_turn(phase_title, current_phase.visual_accent)
	action_label.text = "%s\n%s%s" % [phase_title, transition_prefix, current_phase.transition_message]
	_set_action_badge(&"boss", "FASE %s" % _roman_phase(phase_number), AshenBadge.Variant.DANGER)
	combat_stage.set_boss_phase_accent(current_phase.visual_accent)
	_update_combatants()
	var boss_view: CombatCharacterView = _boss_controller.get_boss_actor().visual_view
	AudioManager.play_event(AudioManager.AudioEvent.BOSS_PHASE)
	await vfx.boss_phase_transition(boss_view, phase_title, current_phase.visual_accent)
	if not await TutorialManager.request_and_wait(TutorialCatalog.BOSS_PHASE, TutorialManager.CONTEXT_COMBAT, self):
		return


func _resolve_warden_counter(target_boss: CombatActor) -> bool:
	var counter_multiplier: float = _boss_controller.consume_counter_multiplier(target_boss)
	if counter_multiplier <= 0.0 or not player_actor.is_alive():
		return false
	var boss_view: CombatCharacterView = target_boss.visual_view
	var last_ember_before_counter: bool = _last_ember_active
	var base_attack: int = maxi(1, roundi(float(target_boss.get_attack()) * _boss_controller.get_attack_multiplier()))
	var effective_attack: int = _statuses.get_effective_attack(target_boss, base_attack)
	var raw_damage: int = _resolve_elemental_damage(CombatMath.calculate_damage(effective_attack, _get_effective_actor_defense(player_actor)), target_boss, player_actor)
	var counter_damage: int = maxi(1, roundi(float(raw_damage) * counter_multiplier))
	counter_damage = _boons.before_player_takes_damage(counter_damage)
	var damage_before_equipment: int = counter_damage
	counter_damage = EquipmentEffectResolver.before_player_takes_damage(
		counter_damage, RunManager.current_run, _equipment_runtime,
	)
	var equipment_reduction: int = damage_before_equipment - counter_damage
	var guard_controller: ActiveSkillController
	if player_actor.has_status(&"guard"):
		guard_controller = _skill_loadout.get_by_id(ActiveSkillCatalog.ASHEN_GUARD.id)
	if guard_controller != null:
		counter_damage = guard_controller.apply_guard_to_damage(counter_damage)
		_statuses.consume_hit_status(player_actor, &"guard")
	player_actor.apply_damage(_statuses.get_effective_incoming_damage(player_actor, counter_damage))
	_skill_loadout.on_damage_received(counter_damage)
	var stored_energy: int = 0
	var discarded_counter_guard: int = 0
	if guard_controller != null:
		stored_energy = _skill_loadout.add_energy(guard_controller.consume_stored_embers_energy())
		discarded_counter_guard = guard_controller.consume_counter_guard_damage()
	var discarded_retaliation: int = _boons.after_player_takes_damage()
	var counter_feedback: Array[String] = []
	if equipment_reduction > 0:
		counter_feedback.append("WARDEN PLATE -%d" % equipment_reduction)
	if guard_controller != null and guard_controller.last_guard_reduction > 0:
		counter_feedback.append("GUARDIA -%d" % guard_controller.last_guard_reduction)
	if _boons.get_last_cinder_reduction() > 0:
		counter_feedback.append("CINDER SKIN -%d" % _boons.get_last_cinder_reduction())
	if stored_energy > 0:
		counter_feedback.append("STORED EMBERS +%d" % stored_energy)
	if discarded_retaliation > 0 or discarded_counter_guard > 0:
		counter_feedback.append("SIN CADENA DE CONTRAATAQUE")
	_set_turn("WARDEN'S REBUKE", VisualTheme.BOSS)
	action_label.text = "CONTRAATAQUE ANUNCIADO\nASHEN WANDERER -%d VIDA%s" % [
		counter_damage,
		"\n" + " · ".join(counter_feedback) if not counter_feedback.is_empty() else "",
	]
	_set_action_badge(&"counter_guard", "WARDEN'S REBUKE", AshenBadge.Variant.DANGER)
	_animate_action_feedback(VisualTheme.BOSS)
	boss_view.play_attack(0.24)
	await choreography.begin_static(boss_view)
	AudioManager.play_event(AudioManager.AudioEvent.BOSS_REBUKE)
	player_view.play_hit(0.24)
	vfx.enemy_attack_target_from(boss_view, player_view, "CONTRAATAQUE", false)
	_update_combatants()
	await choreography.finish_static()
	if target_boss.is_alive():
		boss_view.play_idle()
	if player_actor.is_alive():
		player_view.play_idle()
	_last_ember_active = _boons.is_last_ember_active()
	if _last_ember_active != last_ember_before_counter:
		vfx.show_last_ember(_last_ember_active)
	if not player_actor.is_alive():
		await _finish_defeat()
		return true
	return false


func _roman_phase(phase_number: int) -> String:
	match phase_number:
		2:
			return "II"
		3:
			return "III"
		_:
			return "I"


func _is_defeated_boss(actor: CombatActor) -> bool:
	return _boss_controller != null and _boss_controller.owns_actor(actor) and not actor.is_alive()


func _enemy_status_feedback(status_id: StringName) -> String:
	match status_id:
		&"burn":
			return "QUEMADURA"
		&"weaken":
			return "DEBILITADO"
		&"armor_break":
			return "ARMADURA ROTA"
		_:
			return "ESTADO APLICADO"


func _enemy_motion_style(action: EnemyActionData) -> CombatChoreographyController.MotionStyle:
	if action == null:
		return CombatChoreographyController.MotionStyle.MELEE
	match action.presentation_type:
		EnemyAIEnums.PresentationType.STATIC:
			return CombatChoreographyController.MotionStyle.STATIC
		EnemyAIEnums.PresentationType.RANGED:
			return CombatChoreographyController.MotionStyle.RANGED
		_:
			return CombatChoreographyController.MotionStyle.MELEE


func _finish_victory(defeated_actor: CombatActor) -> void:
	if _result_resolved:
		return
	_result_resolved = true
	_invalidate_enemy_intent(defeated_actor, &"source_dead", true)
	for intent: EnemyIntent in _enemy_intents.values():
		if intent != null:
			intent.invalidate(&"combat_finished")
	_enemy_intents.clear()
	_track_combat_result(&"victory")
	if _boss_controller != null:
		_boss_controller.finish_encounter()
	_phase = CombatPhase.RESOLVING_VICTORY
	_lock_action_input()
	for allied_actor: CombatActor in player_actors:
		_statuses.clear_all(allied_actor)
	for remaining_actor: CombatActor in enemy_actors:
		_statuses.clear_all(remaining_actor)
	var recovered: int = _boons.on_enemy_defeated()
	if recovered > 0:
		AudioManager.play_event(AudioManager.AudioEvent.HEAL)
	_boons.on_combat_ended()
	_skill_loadout.store_combat_carryover(not _is_boss)
	_set_turn("COMBATE GANADO", VisualTheme.EMBER_BRIGHT)
	var defeated_name: String = defeated_actor.display_name if defeated_actor != null else "la formación enemiga"
	action_label.text = "¡Victoria! Derrotaste a %s.%s" % [
		defeated_name,
		" Ember Blood recuperó %d de Vida." % recovered if recovered > 0 else "",
	]
	_set_action_badge(&"boon", "VICTORIA", AshenBadge.Variant.EMBER)
	_update_combatants()
	if recovered > 0:
		vfx.show_secondary("EMBER BLOOD · +%d VIDA" % recovered, VisualTheme.HEAL)
	var death_duration: float = 0.0
	if defeated_actor != null:
		death_duration = _enemy_death_duration(defeated_actor)
		await _present_enemy_death(defeated_actor, recovered > 0)
	if _is_defeated_boss(defeated_actor):
		await _cleanup_boss_adds()
	AudioManager.play_event(AudioManager.AudioEvent.VICTORY)
	_clear_selected_enemy_actor()
	await _wait(maxf(0.0, RESULT_DELAY - death_duration))
	combat_won.emit(_is_boss, _is_elite)


func _cleanup_boss_adds() -> void:
	var add_views: Array[Control] = []
	for remaining_actor: CombatActor in enemy_actors:
		if remaining_actor.actor_type != CombatActor.ActorType.MINION:
			continue
		remaining_actor.set_current_hp(0)
		_invalidate_enemy_intent(remaining_actor, &"boss_defeated")
		remaining_actor.death_presented = true
		_statuses.clear_all(remaining_actor)
		if is_instance_valid(remaining_actor.visual_view):
			add_views.append(remaining_actor.visual_view)
	await vfx.boss_add_cleanup(add_views)
	_update_enemy_slots()


func _present_enemy_death(defeated_actor: CombatActor, absorb_to_player: bool = false) -> void:
	if defeated_actor == null or defeated_actor.death_presented:
		return
	_invalidate_enemy_intent(defeated_actor, &"source_dead", true)
	defeated_actor.death_presented = true
	_statuses.clear_all(defeated_actor)
	var defeated_view: CombatCharacterView = defeated_actor.visual_view
	if not is_instance_valid(defeated_view):
		return
	var duration: float = _enemy_death_duration(defeated_actor)
	AudioManager.play_event(
		AudioManager.AudioEvent.BOSS_DEATH
		if defeated_actor.actor_type == CombatActor.ActorType.BOSS
		else AudioManager.AudioEvent.ENEMY_DEATH,
	)
	defeated_view.play_death(duration)
	await vfx.enemy_death_target(
		defeated_view,
		duration,
		defeated_actor.actor_type == CombatActor.ActorType.BOSS,
		absorb_to_player,
	)
	_update_enemy_slots()


func _present_companion_death() -> void:
	if companion_actor == null or companion_actor.death_presented:
		return
	companion_actor.death_presented = true
	_statuses.clear_all(companion_actor)
	if not is_instance_valid(companion_view):
		return
	var duration: float = 0.0 if SettingsManager.reduce_motion else 0.38
	AudioManager.play_event(AudioManager.AudioEvent.COMPANION_DEATH)
	companion_view.play_death(duration)
	if SettingsManager.reduce_motion:
		companion_view.modulate = Color(0.45, 0.38, 0.38, 0.55)
		return
	var death_tween: Tween = create_tween().set_parallel(true)
	death_tween.tween_property(companion_view, "modulate", Color(0.42, 0.3, 0.3, 0.42), duration)
	death_tween.tween_property(companion_view, "scale", companion_view.scale * 0.94, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await death_tween.finished


func _enemy_death_duration(defeated_actor: CombatActor) -> float:
	if SettingsManager.reduce_motion:
		return 0.0
	if defeated_actor.actor_type == CombatActor.ActorType.BOSS:
		return CombatVFXController.BOSS_DEATH_DURATION
	if defeated_actor.actor_type == CombatActor.ActorType.ELITE:
		return CombatVFXController.ELITE_DEATH_DURATION
	return CombatVFXController.NORMAL_DEATH_DURATION


func _finish_defeat() -> void:
	if _result_resolved:
		return
	_result_resolved = true
	_track_combat_result(&"defeat")
	if _boss_controller != null:
		_boss_controller.finish_encounter()
	for allied_actor: CombatActor in player_actors:
		_statuses.clear_all(allied_actor)
	_phase = CombatPhase.RESOLVING_DEFEAT
	_lock_action_input()
	_clear_selected_enemy_actor()
	_boons.on_combat_ended()
	_skill_loadout.store_combat_carryover(false)
	_set_turn("COMBATE PERDIDO", VisualTheme.DANGER)
	action_label.text = "Derrota. El Reino reclama a otro viajero."
	_set_action_badge(&"death", "DERROTA", AshenBadge.Variant.DANGER)
	var death_duration: float = vfx.get_player_death_duration()
	player_view.play_death(death_duration)
	await vfx.player_death()
	AudioManager.play_event(AudioManager.AudioEvent.DEFEAT)
	await _wait(maxf(0.0, RESULT_DELAY - death_duration))
	combat_lost.emit(_is_boss, _is_elite)


func _get_encounter_type() -> StringName:
	if _is_boss:
		return &"boss"
	if _is_elite:
		return &"elite"
	return &"normal"


func _track_combat_result(result: StringName) -> void:
	var companion_alive: bool = companion_actor != null and companion_actor.is_alive()
	TelemetryManager.track_combat_finished(
		result, _telemetry_turn_count,
		player_actor.get_current_hp() if player_actor != null else 0,
		player_actor.get_max_hp() if player_actor != null else 1,
		companion_alive, _encounter_enemies.size(), _get_encounter_type(),
	)
	if _is_boss and _biome != null and _biome.boss != null:
		TelemetryManager.track_boss_finished(RunManager.current_run, _biome.boss.id, result)


func _update_combatants() -> void:
	player_name_label.text = player_actor.display_name
	player_caption.text = "ASHEN WANDERER  ·  NV. %d" % RunManager.current_run.run_level
	player_health_label.configure(&"health", "VIDA", AshenBadge.Variant.HEAL, AshenIcon.DisplaySize.SMALL, "%d / %d" % [player_actor.get_current_hp(), player_actor.get_max_hp()])
	player_health_bar.max_value = player_actor.get_max_hp()
	_animate_bar(player_health_bar, player_actor.get_current_hp())
	var temporary_attack: int = _boons.get_temporary_attack_bonus()
	var temporary_defense: int = _boons.get_temporary_defense_bonus() + _skill_loadout.get_temporary_defense_bonus()
	player_attack_badge.configure(&"attack", "ATQ", AshenBadge.Variant.ATTACK, AshenIcon.DisplaySize.SMALL, "%d%s" % [
		_statuses.get_effective_attack(player_actor, player_actor.get_attack() + temporary_attack),
		" (+%d)" % temporary_attack if temporary_attack > 0 else "",
	])
	player_defense_badge.configure(&"defense", "DEF", AshenBadge.Variant.DEFENSE, AshenIcon.DisplaySize.SMALL, "%d%s" % [
		_statuses.get_effective_defense(player_actor, player_actor.get_defense() + temporary_defense),
		" (+%d)" % temporary_defense if temporary_defense > 0 else "",
	])
	_update_companion_hud()
	_update_active_effect_badges()
	if _boss_controller != null:
		_update_boss_hud()
		if enemy_actors.size() > 1:
			_update_enemy_slots()
		_update_skill_ui()
		_refresh_intent_ui()
		return
	if enemy_actors.size() > 1:
		_update_enemy_slots()
		_update_skill_ui()
		_refresh_intent_ui()
		return
	enemy_name_label.text = enemy_actor.display_name.to_upper() if _is_boss else enemy_actor.display_name
	enemy_health_label.configure(&"health", "VIDA", AshenBadge.Variant.DANGER, AshenIcon.DisplaySize.SMALL, "%d / %d" % [enemy_actor.get_current_hp(), enemy_actor.get_max_hp()])
	enemy_health_bar.max_value = enemy_actor.get_max_hp()
	_animate_bar(enemy_health_bar, enemy_actor.get_current_hp())
	enemy_attack_badge.configure(&"attack", "ATQ", AshenBadge.Variant.ATTACK, AshenIcon.DisplaySize.SMALL, str(_statuses.get_effective_attack(enemy_actor, enemy_actor.get_attack())))
	enemy_defense_badge.configure(&"defense", "DEF", AshenBadge.Variant.DEFENSE, AshenIcon.DisplaySize.SMALL, str(_get_effective_actor_defense(enemy_actor)))
	_refresh_status_badges(enemy_status_row, enemy_actor)
	_update_skill_ui()
	_refresh_intent_ui()


func debug_prepare_stage72_statuses() -> void:
	if not DebugConfig.is_visual_slice_enabled() or _statuses == null or player_actor == null or enemy_actor == null:
		return
	_statuses.apply_status(player_actor, &"guard", player_actor, 1, 1)
	_statuses.apply_status(player_actor, &"regen", player_actor, 1, 2)
	_statuses.apply_status(enemy_actor, &"burn", player_actor, 2, 2)
	_statuses.apply_status(enemy_actor, &"weaken", player_actor, 1, 2)
	_update_combatants()


func _update_boss_hud() -> void:
	if _boss_actor == null:
		return
	var phase: BossPhaseData = _boss_controller.get_current_phase()
	var phase_number: int = _boss_controller.runtime.current_phase_index + 1
	var phase_text: String = "FASE %s" % _roman_phase(phase_number)
	if phase != null:
		phase_text += " · %s" % phase.display_name.to_upper().trim_prefix("THE ")
	if _boss_controller.runtime.counter_armed:
		phase_text += " · REBUKE PREPARADO"
	enemy_name_label.text = "%s\n%s" % [_boss_actor.display_name.to_upper(), phase_text]
	enemy_health_label.configure(&"health", "VIDA", AshenBadge.Variant.DANGER, AshenIcon.DisplaySize.SMALL, "%d / %d" % [_boss_actor.get_current_hp(), _boss_actor.get_max_hp()])
	enemy_health_bar.max_value = _boss_actor.get_max_hp()
	_animate_bar(enemy_health_bar, _boss_actor.get_current_hp())
	var boss_attack: int = maxi(1, roundi(float(_boss_actor.get_attack()) * _boss_controller.get_attack_multiplier()))
	enemy_attack_badge.configure(&"attack", "ATQ", AshenBadge.Variant.ATTACK, AshenIcon.DisplaySize.SMALL, str(_statuses.get_effective_attack(_boss_actor, boss_attack)))
	enemy_defense_badge.configure(&"defense", "DEF", AshenBadge.Variant.DEFENSE, AshenIcon.DisplaySize.SMALL, str(_get_effective_actor_defense(_boss_actor)))
	_refresh_status_badges(enemy_status_row, _boss_actor)


func _update_companion_hud() -> void:
	var has_companion: bool = companion_actor != null
	companion_panel.visible = has_companion
	companion_view.visible = has_companion
	if not has_companion:
		return
	companion_name_label.text = companion_actor.display_name.to_upper()
	companion_panel.modulate.a = 1.0 if companion_actor.is_alive() else 0.45
	companion_health_bar.max_value = companion_actor.get_max_hp()
	_animate_bar(companion_health_bar, companion_actor.get_current_hp())
	companion_stats_label.text = "VIDA %d/%d · ATQ %d · DEF %d" % [
		companion_actor.get_current_hp(),
		companion_actor.get_max_hp(),
		_statuses.get_effective_attack(companion_actor, companion_actor.get_attack()),
		_statuses.get_effective_defense(companion_actor, companion_actor.get_defense()),
	]
	if companion_actor.is_alive() and _companion_runtime != null:
		var companion_data: CompanionData = companion_actor.source_data as CompanionData
		if companion_data != null:
			companion_stats_label.text += " · %s EN %d" % [
				companion_data.ability_name.to_upper(),
				_companion_runtime.actions_until_ability(companion_data),
			]
	_refresh_status_badges(companion_status_row, companion_actor)


func _on_attack_pressed() -> void:
	if _phase != CombatPhase.PLAYER_INPUT or _result_resolved:
		return
	var captured_target: CombatActor = refresh_primary_enemy_actor()
	if captured_target == null:
		return
	_commit_player_action(PlayerAction.BASIC_ATTACK, captured_target)


func _on_skill_requested(skill_controller: ActiveSkillController) -> void:
	if _phase != CombatPhase.PLAYER_INPUT or _result_resolved:
		return
	if not player_actor.is_alive() or not has_alive_enemies():
		return
	_show_skill_detail(skill_controller)
	var captured_target: CombatActor
	if skill_controller == null or skill_controller not in _skill_loadout.skills:
		return
	match skill_controller.skill.target_type:
		ActiveSkillData.TargetType.SELF:
			captured_target = player_actor
		ActiveSkillData.TargetType.SINGLE_ENEMY:
			captured_target = refresh_primary_enemy_actor()
			if captured_target == null:
				return
		_:
			return
	if not _skill_loadout.try_use(skill_controller):
		_refresh_action_bar()
		return
	_focused_skill = skill_controller
	_committed_skill = skill_controller
	_commit_player_action(PlayerAction.ACTIVE_SKILL, captured_target)


func debug_trigger_visual_skill(skill_id: StringName) -> void:
	if not DebugConfig.is_visual_slice_enabled():
		return
	var frames_waited: int = 0
	while _phase != CombatPhase.PLAYER_INPUT and frames_waited < 240:
		await get_tree().process_frame
		frames_waited += 1
	if _phase != CombatPhase.PLAYER_INPUT or _skill_loadout == null:
		return
	var controller: ActiveSkillController = _skill_loadout.get_by_id(skill_id)
	if controller != null and _skill_loadout.can_use(controller):
		_on_skill_requested(controller)


func debug_trigger_visual_attack() -> void:
	if not DebugConfig.is_visual_slice_enabled():
		return
	var frames_waited: int = 0
	while _phase != CombatPhase.PLAYER_INPUT and frames_waited < 240:
		await get_tree().process_frame
		frames_waited += 1
	if _phase != CombatPhase.PLAYER_INPUT:
		return
	var target: CombatActor = refresh_primary_enemy_actor()
	if target != null:
		_commit_player_action(PlayerAction.BASIC_ATTACK, target)


func _execute_active_skill(skill_controller: ActiveSkillController, captured_target: CombatActor) -> bool:
	if skill_controller == null:
		return false
	var active_skill: ActiveSkillData = skill_controller.skill
	var skill_target: CombatActor = captured_target
	var synergy_energy: int = 0
	_set_turn(player_actor.display_name.to_upper(), VisualTheme.EMBER_BRIGHT)
	match active_skill.skill_type:
		ActiveSkillData.SkillType.DAMAGE:
			if skill_target == null:
				await _finish_victory(null)
				return true
			var skill_target_view: CombatCharacterView = skill_target.visual_view
			var execution_applied: bool = SkillAugmentResolver.execution_multiplier(
				RunManager.current_run, skill_target.get_current_hp(), skill_target.get_max_hp(),
			) > 1.0
			var skill_damage: int = skill_controller.calculate_skill_damage(
				_statuses.get_effective_attack(player_actor, _boons.get_effective_attack()),
				_get_effective_actor_defense(skill_target),
				skill_target.get_current_hp(),
				skill_target.get_max_hp(),
			)
			var skill_critical: bool = EquipmentEffectResolver.roll_critical(RunManager.current_run, _equipment_rng)
			if skill_critical:
				skill_damage = EquipmentEffectResolver.apply_critical_damage(skill_damage, RunManager.current_run)
				synergy_energy += SynergyEffectResolver.on_critical_hit(
					RunManager.current_run, _synergy_runtime, _skill_loadout,
				)
			skill_target.apply_damage(_statuses.get_effective_incoming_damage(skill_target, skill_damage))
			player_view.play_named_animation(&"ember_slash", CombatChoreographyController.AGGRESSIVE_DURATION)
			await choreography.approach(
				player_view,
				skill_target_view,
				player_actor.actor_type,
				CombatChoreographyController.MotionStyle.AGGRESSIVE,
			)
			_set_action_badge(&"ember_slash", active_skill.display_name.to_upper(), AshenBadge.Variant.EMBER)
			AudioManager.play_event(AudioManager.AudioEvent.SKILL_ATTACK)
			if skill_critical:
				AudioManager.play_event(AudioManager.AudioEvent.CRITICAL)
			action_label.text = "%s\n-%d VIDA%s" % [active_skill.display_name.to_upper(), skill_damage, "\nCRÍTICO" if skill_critical else ""]
			_animate_action_feedback(VisualTheme.EMBER_BRIGHT)
			_update_combatants()
			skill_target_view.play_hit(CombatChoreographyController.AGGRESSIVE_DURATION)
			vfx.ember_slash_target(skill_target_view, execution_applied, skill_critical)
			vfx.show_damage_number(skill_target_view, skill_damage, skill_critical, false, VisualTheme.EMBER_BRIGHT)
			await choreography.impact_and_return(
				CombatChoreographyController.EMPHASIZED_HIT_STOP_DURATION if skill_critical else CombatChoreographyController.HIT_STOP_DURATION,
			)
			player_view.play_idle()
			if skill_target.is_alive():
				skill_target_view.play_idle()
		ActiveSkillData.SkillType.DEFENSE:
			_statuses.apply_status(player_actor, &"guard", player_actor, 1, 1)
			await choreography.begin_static(player_view)
			_set_action_badge(&"ashen_guard", active_skill.display_name.to_upper(), AshenBadge.Variant.NEUTRAL)
			AudioManager.play_event(AudioManager.AudioEvent.GUARD_ACTIVATE)
			var guard_percent: int = roundi(SkillAugmentResolver.effective_guard_reduction(active_skill, RunManager.current_run) * 100.0)
			action_label.text = "GUARDIA ACTIVA\nPRÓXIMO GOLPE REDUCIDO · %d%%" % guard_percent
			_animate_action_feedback(VisualTheme.EVENT)
			_update_combatants()
			await vfx.guard_activation()
			await choreography.finish_static()
			player_view.play_idle()
		ActiveSkillData.SkillType.HEAL:
			await choreography.begin_static(player_view)
			_set_action_badge(&"second_wind", active_skill.display_name.to_upper(), AshenBadge.Variant.HEAL)
			AudioManager.play_event(AudioManager.AudioEvent.HEAL)
			action_label.text = "SECOND WIND\n+%d VIDA" % skill_controller.last_heal_amount
			_animate_action_feedback(VisualTheme.HEAL)
			_update_combatants()
			await vfx.heal(skill_controller.last_heal_amount, skill_controller.get_temporary_defense_bonus())
			await choreography.finish_static()
			player_view.play_idle()
			var last_ember_after_heal: bool = _boons.is_last_ember_active()
			if last_ember_after_heal != _last_ember_active:
				_last_ember_active = last_ember_after_heal
				vfx.show_last_ember(_last_ember_active)
	synergy_energy += SynergyEffectResolver.on_skill_used(
		RunManager.current_run, _synergy_runtime, _skill_loadout,
	)
	if synergy_energy > 0:
		action_label.text += "\nSINERGIA · +%d BRASA" % synergy_energy
		vfx.show_secondary("SINERGIA · +%d BRASA" % synergy_energy, VisualTheme.EMBER_BRIGHT)
	await _check_boss_phase_transition()
	if skill_target != null and not skill_target.is_alive():
		if _is_defeated_boss(skill_target) or not has_alive_enemies():
			await _finish_victory(skill_target)
			return true
		await _present_enemy_death(skill_target)
		refresh_primary_enemy_actor()
		_update_combatants()
	return false


func _update_skill_ui() -> void:
	if _skill_loadout == null:
		return
	energy_bar.value = _skill_loadout.current_energy
	energy_label.text = "%d / %d" % [_skill_loadout.current_energy, CombatSkillController.MAX_ENERGY]
	var input_enabled: bool = (
		_phase == CombatPhase.PLAYER_INPUT
		and not _result_resolved
		and player_actor != null
		and player_actor.is_alive()
		and has_alive_enemies()
	)
	for skill_action_button: CombatSkillButton in _skill_buttons:
		skill_action_button.refresh(_skill_loadout.current_energy, input_enabled)
	if _focused_skill == null:
		skill_description_label.text = "SIN HABILIDADES EQUIPADAS"
		skill_status_label.visible = false
		return
	skill_description_label.text = "%s\n%s" % [
		_focused_skill.skill.effect_summary,
		SkillAugmentResolver.effective_summary(_focused_skill.skill, RunManager.current_run),
	]
	var augment_lines: Array[String] = SkillAugmentResolver.list_for_skill(RunManager.current_run, _focused_skill.skill.id)
	skill_augments_label.visible = not augment_lines.is_empty()
	skill_augments_label.text = "AUMENTOS\n%s" % "\n".join(augment_lines)
	var status_icon: StringName = &"skill"
	var status_variant: AshenBadge.Variant = AshenBadge.Variant.ENERGY
	if _focused_skill.cooldown_remaining > 0:
		status_icon = &"cooldown"
		status_variant = AshenBadge.Variant.UTILITY
	elif _focused_skill.skill.skill_type == ActiveSkillData.SkillType.HEAL and _focused_skill.used_this_combat:
		status_icon = &"health"
		status_variant = AshenBadge.Variant.UTILITY
	skill_status_label.visible = true
	skill_status_label.configure(
		status_icon,
		_focused_skill.get_status_text(_skill_loadout.current_energy),
		status_variant,
		AshenIcon.DisplaySize.SMALL,
	)


func _refresh_action_bar() -> void:
	var player_can_act: bool = (
		_phase == CombatPhase.PLAYER_INPUT
		and not _result_resolved
		and player_actor != null
		and player_actor.is_alive()
		and has_alive_enemies()
	)
	attack_button.disabled = not player_can_act or not _is_valid_enemy_target(selected_enemy_actor)
	for slot: EnemyCombatSlot in _enemy_slots:
		slot.set_target_input_enabled(_can_change_target())
	_update_skill_ui()


func _lock_action_input() -> void:
	_pending_player_action = PlayerAction.NONE
	_committed_target_actor = null
	_committed_skill = null
	_refresh_action_bar()


func _on_debug_fill_energy_pressed() -> void:
	if not DebugConfig.DEBUG_TOOLS_ENABLED or _skill_loadout == null:
		return
	_skill_loadout.debug_fill_energy()
	_update_skill_ui()


func _on_debug_reset_cooldown_pressed() -> void:
	if not DebugConfig.DEBUG_TOOLS_ENABLED or _skill_loadout == null:
		return
	_skill_loadout.debug_reset_cooldowns()
	_update_skill_ui()


func _set_action_badge(icon_id: StringName, text: String, variant: AshenBadge.Variant) -> void:
	action_badge.configure(icon_id, text, variant, AshenIcon.DisplaySize.SMALL)


func _update_active_effect_badges() -> void:
	var guard_active: bool = player_actor.has_status(&"guard")
	var skill_defense_bonus: int = _skill_loadout.get_temporary_defense_bonus()
	var synergy_signature: String = ""
	for synergy_id: StringName in RunManager.current_run.active_synergy_ids:
		synergy_signature += "%s," % synergy_id
	var signature: String = "%s|%s|%d|%d|%d|%d|%s|%s" % [
		str(guard_active),
		str(_boons.is_last_ember_active()),
		_boons.get_pyre_attack_bonus(),
		_boons.get_relentless_attack_bonus(),
		_boons.get_temporary_defense_bonus(),
		skill_defense_bonus,
		_status_signature(player_actor),
		synergy_signature,
	]
	if signature == _active_effect_signature:
		return
	_active_effect_signature = signature
	for child: Node in active_effects_row.get_children():
		active_effects_row.remove_child(child)
		child.queue_free()
	var badge_count: int = _append_status_badges(active_effects_row, player_actor, 4)
	var synergy_badge_count: int = 0
	for synergy_id: StringName in RunManager.current_run.active_synergy_ids:
		if badge_count >= 4 or synergy_badge_count >= 2:
			break
		var synergy: SynergyData = SynergyCatalog.get_by_id(synergy_id)
		if synergy != null:
			_add_active_effect_badge(synergy.icon_id, synergy.display_name, AshenBadge.Variant.BUFF)
			badge_count += 1
			synergy_badge_count += 1
	if _boons.is_last_ember_active() and badge_count < 4:
		_add_active_effect_badge(&"last_ember", "LAST EMBER", AshenBadge.Variant.DANGER)
		badge_count += 1
	if _boons.get_pyre_attack_bonus() > 0 and badge_count < 4:
		var pyre_text: String = "PHOENIX BLOOD" if _boons.is_phoenix_empowered() else "PYRE HEART"
		var pyre_icon: StringName = &"phoenix_blood" if _boons.is_phoenix_empowered() else &"pyre_heart"
		var pyre_variant: AshenBadge.Variant = AshenBadge.Variant.BUFF if _boons.is_phoenix_empowered() else AshenBadge.Variant.ATTACK
		_add_active_effect_badge(pyre_icon, pyre_text, pyre_variant)
		badge_count += 1
	if _boons.get_relentless_attack_bonus() > 0 and badge_count < 4:
		_add_active_effect_badge(&"relentless_flame", "RELENTLESS", AshenBadge.Variant.ATTACK, "+%d" % _boons.get_relentless_attack_bonus())
		badge_count += 1
	if _boons.get_temporary_defense_bonus() > 0 and badge_count < 4:
		_add_active_effect_badge(&"ashen_bulwark", "BULWARK", AshenBadge.Variant.DEFENSE, "+%d" % _boons.get_temporary_defense_bonus())
		badge_count += 1
	if skill_defense_bonus > 0 and badge_count < 4:
		_add_active_effect_badge(&"ashen_renewal", "RENOVACIÓN", AshenBadge.Variant.DEFENSE, "+%d" % skill_defense_bonus)
	active_effects_row.visible = active_effects_row.get_child_count() > 0


func _add_active_effect_badge(icon_id: StringName, text: String, variant: AshenBadge.Variant, counter: String = "") -> void:
	var badge: AshenBadge = AshenBadge.new()
	badge.configure(icon_id, text, variant, AshenIcon.DisplaySize.SMALL, counter)
	active_effects_row.add_child(badge)


func _process_actor_turn_start(actor: CombatActor) -> bool:
	var results: Array[CombatStatusController.TickResult] = _statuses.process_turn_start(actor)
	for result: CombatStatusController.TickResult in results:
		if result.damage <= 0 and result.healing <= 0:
			continue
		var is_damage: bool = result.damage > 0
		var amount: int = result.damage if is_damage else result.healing
		_set_turn(actor.display_name.to_upper(), VisualTheme.DANGER if is_damage else VisualTheme.HEAL)
		_set_action_badge(
			result.status.data.icon_id,
			result.status.data.display_name.to_upper(),
			AshenBadge.Variant.DANGER if is_damage else AshenBadge.Variant.HEAL,
		)
		action_label.text = "%s\n%s%d VIDA" % [
			result.status.data.display_name.to_upper(),
			"-" if is_damage else "+",
			amount,
		]
		_animate_action_feedback(VisualTheme.DANGER if is_damage else VisualTheme.HEAL)
		var actor_view: CombatCharacterView = actor.visual_view
		AudioManager.play_event(
			AudioManager.AudioEvent.BURN_TICK if is_damage else AudioManager.AudioEvent.HEAL,
			1.0,
			-7.0 if not is_damage else 0.0,
		)
		vfx.status_tick(actor_view, is_damage)
		vfx.show_damage_number(actor_view, amount, false, not is_damage, VisualTheme.DANGER if is_damage else VisualTheme.HEAL)
		if is_instance_valid(actor_view) and is_damage:
			actor_view.play_hit(0.18)
		_update_combatants()
		await _wait(0.08 if SettingsManager.reduce_motion else 0.16)
		if is_instance_valid(actor_view) and actor.is_alive():
			actor_view.play_idle()
		if not actor.is_alive():
			return true
		if _boss_controller != null and _boss_controller.owns_actor(actor):
			await _check_boss_phase_transition()
	return not actor.is_alive()


func _refresh_status_badges(container: HBoxContainer, actor: CombatActor) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
	_append_status_badges(container, actor, 2)
	container.visible = container.get_child_count() > 0


func _append_status_badges(container: HBoxContainer, actor: CombatActor, maximum: int) -> int:
	if actor == null:
		return 0
	var statuses: Array[StatusEffectInstance] = actor.get_statuses()
	var visible_count: int = mini(maximum, statuses.size())
	for index: int in visible_count:
		var instance: StatusEffectInstance = statuses[index]
		var badge: AshenBadge = AshenBadge.new()
		var variant: AshenBadge.Variant = _status_badge_variant(instance.data)
		badge.configure(instance.data.icon_id, instance.data.display_name.to_upper(), variant, AshenIcon.DisplaySize.SMALL, _status_counter(instance))
		badge.tooltip_text = instance.data.description
		container.add_child(badge)
	if statuses.size() > visible_count:
		var overflow: Label = Label.new()
		overflow.text = "+%d" % (statuses.size() - visible_count)
		container.add_child(overflow)
	return visible_count


func _status_badge_variant(status_data: StatusEffectData) -> AshenBadge.Variant:
	if status_data == null:
		return AshenBadge.Variant.UTILITY
	match status_data.category:
		StatusEffectData.Category.BUFF:
			return AshenBadge.Variant.BUFF
		StatusEffectData.Category.DEBUFF:
			return AshenBadge.Variant.DEBUFF
		StatusEffectData.Category.DOT:
			return AshenBadge.Variant.DEBUFF
		StatusEffectData.Category.DEFENSE:
			return AshenBadge.Variant.DEFENSE
		_:
			return AshenBadge.Variant.UTILITY


func _status_counter(instance: StatusEffectInstance) -> String:
	var parts: Array[String] = []
	if instance.stacks > 1:
		parts.append("×%d" % instance.stacks)
	if instance.data.duration_type == StatusEffectData.DurationType.HITS:
		parts.append("%d GOLPE" % instance.remaining_duration)
	elif instance.data.duration_type == StatusEffectData.DurationType.TURNS:
		parts.append("%d" % instance.remaining_duration)
	return " · ".join(parts)


func _status_signature(actor: CombatActor) -> String:
	if actor == null:
		return ""
	var parts: Array[String] = []
	for instance: StatusEffectInstance in actor.get_statuses():
		parts.append("%s:%d:%d" % [instance.data.status_id, instance.stacks, instance.remaining_duration])
	return "|".join(parts)


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds, false).timeout


func _animate_bar(bar: ProgressBar, target_value: float) -> void:
	if SettingsManager.reduce_motion:
		bar.value = target_value
		return
	var tween: Tween = create_tween()
	tween.tween_property(bar, "value", target_value, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_turn(text: String, color: Color) -> void:
	turn_label.text = text
	turn_label.modulate = color
	if SettingsManager.reduce_motion:
		turn_label.scale = Vector2.ONE
		return
	turn_label.pivot_offset = turn_label.size * 0.5
	turn_label.scale = Vector2(0.94, 0.94)
	var tween: Tween = create_tween()
	tween.tween_property(turn_label, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_action_feedback(color: Color) -> void:
	action_label.modulate = color
	if SettingsManager.reduce_motion:
		action_label.scale = Vector2.ONE
		return
	action_label.pivot_offset = action_label.size * 0.5
	action_label.scale = Vector2(0.97, 0.97)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(action_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(action_label, "modulate", Color.WHITE, 0.28)

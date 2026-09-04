extends Control

const MilestoneDataType = preload("res://scripts/data/milestone_data.gd")
const MilestoneCatalogSource = preload("res://scripts/meta/milestone_catalog.gd")
const MilestoneResolverSource = preload("res://scripts/meta/milestone_resolver.gd")

signal return_to_lobby_requested

@onready var result_title: Label = %ResultTitle
@onready var outcome_label: Label = %OutcomeLabel
@onready var result_message: Label = %ResultMessage
@onready var player_art: TextureRect = %PlayerArt
@onready var player_art_fallback: Label = %PlayerArtFallback
@onready var ash_earned_label: Label = %AshEarnedLabel
@onready var player_xp_label: Label = %PlayerXpLabel
@onready var player_xp_bar: ProgressBar = %PlayerXpBar
@onready var loot_rarity_label: Label = %LootRarityLabel
@onready var loot_name_label: Label = %LootNameLabel
@onready var loot_stats_label: Label = %LootStatsLabel
@onready var loot_panel: PanelContainer = %LootPanel
@onready var loot_card_host: VBoxContainer = %LootCardHost
@onready var background: ColorRect = %Background
@onready var summary_label: Label = %SummaryLabel
@onready var return_button: Button = %ReturnButton
@onready var region_label: Label = %RegionLabel
@onready var boss_reward_label: Label = %BossRewardLabel
@onready var milestone_progress_label: Label = %MilestoneProgressLabel

var _is_victory: bool = false
var _loot_icon: AshenIcon
var _boss_reward_icon: AshenIcon


func configure(is_victory: bool) -> void:
	_is_victory = is_victory


func _ready() -> void:
	if not RunManager.has_active_run():
		push_error("Run Result requires an active run.")
		return

	return_button.pressed.connect(_on_return_button_pressed)
	_configure_player_xp_bar()
	if _is_victory:
		if not RunManager.current_run.boss_reward_applied or not RunManager.current_run.loot_rolled:
			push_error("Victory Result requires an applied Boss Reward and resolved loot.")
			return
	else:
		RunManager.current_run.prepare_loot(false)
	if not RunManager.current_run.rewards_deposited and not SaveManager.deposit_run(RunManager.current_run):
		push_error("Run Result could not persist run rewards and metaprogression.")
		return
	TelemetryManager.track_run_finished(
		RunManager.current_run,
		&"victory" if _is_victory else &"defeat",
		&"boss_defeated" if _is_victory else &"player_defeated",
	)
	_update_result()
	_attach_ash_icon()
	_update_player_visual()
	_play_result_feedback()
	TutorialManager.request(TutorialCatalog.RUN_RESULTS, TutorialManager.CONTEXT_RESULTS, self)
	if not RunManager.current_run.completed_milestone_ids_this_run.is_empty():
		SaveManager.acknowledge_milestone_announcements(RunManager.current_run.completed_milestone_ids_this_run)
	return_button.grab_focus()


func _configure_player_xp_bar() -> void:
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color("171522")
	background_style.border_color = Color("54486e")
	background_style.set_border_width_all(1)
	background_style.set_corner_radius_all(7)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color("8268c7")
	fill_style.set_corner_radius_all(7)
	player_xp_bar.add_theme_stylebox_override("background", background_style)
	player_xp_bar.add_theme_stylebox_override("fill", fill_style)


func _update_player_visual() -> void:
	var visual: CharacterVisualData = PlayerVisualCatalog.ASHEN_WANDERER
	var texture: Texture2D = null
	if visual != null:
		texture = visual.get_portrait()
	player_art.texture = texture
	player_art.visible = texture != null
	player_art_fallback.visible = texture == null
	var treatment: Color = Color.WHITE if _is_victory else Color(0.42, 0.35, 0.38, 0.8)
	player_art.modulate = treatment
	player_art_fallback.modulate = treatment


func _update_result() -> void:
	var run: RunState = RunManager.current_run
	region_label.text = "REGIÓN  ·  %s" % run.biome_data.display_name.to_upper()
	region_label.modulate = run.biome_data.accent_color
	result_title.text = "VICTORIA" if _is_victory else "DERROTA"
	result_title.modulate = VisualTheme.EMBER_BRIGHT if _is_victory else VisualTheme.DANGER
	background.color = Color("16100e") if _is_victory else Color("130b10")
	result_title.add_theme_stylebox_override(
		"normal",
		VisualTheme.elevated_panel_style(
			Color("2b2115") if _is_victory else Color("241417"),
			VisualTheme.EMBER if _is_victory else VisualTheme.DANGER,
			3,
			12,
		),
	)
	var board_length: int = run.board_tile_sequence.size()
	outcome_label.text = "PARTIDA COMPLETADA" if _is_victory else "PARTIDA TERMINADA · CASILLA %d DE %d" % [run.board_position + 1, board_length]
	result_message.text = "%s ha caído. El camino está completo." % run.biome_data.boss.display_name if _is_victory else "El Reino reclama a otro viajero."
	ash_earned_label.text = "CENIZA DE RUN  +%d\nHITOS  +%d  ·  TOTAL %d" % [
		run.run_ash, run.milestone_ash_awarded, SaveManager.profile.total_ash,
	]
	ash_earned_label.text = "CENIZA  +%d  ·  HITOS +%d  ·  TOTAL %d" % [run.run_ash, run.milestone_ash_awarded, SaveManager.profile.total_ash]
	if run.biome_material_earned > 0:
		var material_name: String = run.biome_data.material_name if not run.biome_data.material_name.is_empty() else "Material de Bioma"
		var material_total: int = int(SaveManager.profile.biome_materials.get(String(run.biome_id), 0))
		ash_earned_label.text += "\n%s  +%d  ·  TOTAL %d" % [material_name.to_upper(), run.biome_material_earned, material_total]
	_update_player_xp(run)
	_update_loot(run.pending_loot_id)
	_update_boss_reward()
	_update_milestone_progress(run)
	var equipped_skill_names: Array[String] = []
	var augment_lines: Array[String] = []
	for skill_id: StringName in run.equipped_skill_ids:
		var active_skill: ActiveSkillData = ActiveSkillCatalog.get_by_id(skill_id)
		if active_skill == null:
			continue
		equipped_skill_names.append(active_skill.display_name)
		augment_lines.append_array(SkillAugmentResolver.list_for_skill(run, skill_id))
	var skill_summary: String = "Ninguna" if equipped_skill_names.is_empty() else ", ".join(equipped_skill_names)
	var augment_summary: String = "Ninguno" if augment_lines.is_empty() else ", ".join(augment_lines)
	var level_upgrade_names: Array[String] = []
	for upgrade_id: StringName in run.run_level_upgrade_stacks:
		var level_upgrade: UpgradeData = UpgradeCatalog.get_by_id(upgrade_id)
		if level_upgrade != null:
			level_upgrade_names.append("%s ×%d" % [level_upgrade.display_name, run.get_run_level_upgrade_count(upgrade_id)])
	var level_upgrade_summary: String = "Ninguna" if level_upgrade_names.is_empty() else ", ".join(level_upgrade_names)
	var boon_count: int = 0
	for boon_id: StringName in run.active_boons:
		boon_count += run.get_boon_count(boon_id)
	var companion: CompanionData = CompanionCatalog.get_by_id(run.equipped_companion_id)
	var companion_summary: String = "Ninguno" if companion == null else companion.display_name
	var synergy_names: Array[String] = []
	for synergy_id: StringName in run.activated_synergy_ids:
		synergy_names.append(BoonSynergyResolver.get_display_name(synergy_id))
	var synergy_summary: String = "Ninguna" if synergy_names.is_empty() else ", ".join(synergy_names)
	summary_label.text = "RESUMEN\n\nENFOQUE INICIAL  %s\nNIVEL ALCANZADO  %d\nXP GANADA  %d\nMEJORAS DE NIVEL  %s\nVIDA  %d / %d\nCOMPAÑERO  %s\nCASILLA  %d\nENCUENTROS GANADOS  %d\nÉLITES  %d\nEVENTOS  %d\nTESOROS  %d\nBENDICIONES  %d\nHABILIDADES  %s\nAUMENTOS  %s\nSINERGIAS ACTIVADAS  %s" % [
		MetaUnlockCatalog.get_display_name(run.starting_option_id),
		run.run_level,
		run.total_xp_gained,
		level_upgrade_summary,
		run.current_health,
		run.max_health,
		companion_summary,
		run.board_position + 1,
		run.combats_won,
		run.elites_won,
		run.events_resolved,
		run.treasures_found,
		boon_count,
		skill_summary,
		augment_summary,
		synergy_summary,
	]
	summary_label.tooltip_text = summary_label.text
	summary_label.text = "RUN NIV %d  ·  VIDA %d/%d  ·  CASILLA %d\nCOMBATES %d  ·  ELITES %d  ·  EVENTOS %d  ·  TESOROS %d\nBOONS %d  ·  SKILLS %d  ·  SINERGIAS %d" % [
		run.run_level,
		run.current_health,
		run.max_health,
		run.board_position + 1,
		run.combats_won,
		run.elites_won,
		run.events_resolved,
		run.treasures_found,
		boon_count,
		equipped_skill_names.size(),
		synergy_names.size(),
	]


func _update_player_xp(run: RunState) -> void:
	var requirement: int = PlayerProgressionConfig.xp_required_for_level(run.player_level_after)
	player_xp_bar.max_value = maxi(1, requirement)
	player_xp_bar.value = run.player_xp_after if requirement > 0 else player_xp_bar.max_value
	var level_feedback: String = ""
	if run.player_levels_gained > 0:
		level_feedback = "\nNIVEL ALCANZADO %d" % run.player_level_after
	player_xp_label.text = "EXP PERMANENTE +%d  ·  NIVEL %d\n%s%s" % [
		run.player_xp_earned,
		run.player_level_after,
		"EXP MÁXIMA" if requirement <= 0 else "PROGRESO %d / %d" % [run.player_xp_after, requirement],
		level_feedback,
	]
	player_xp_label.tooltip_text = player_xp_label.text
	player_xp_label.text = "EXP +%d  ·  NIV %d\n%s%s" % [
		run.player_xp_earned,
		run.player_level_after,
		"MAX" if requirement <= 0 else "%d / %d" % [run.player_xp_after, requirement],
		level_feedback,
	]


func _update_milestone_progress(run: RunState) -> void:
	var completed_names: Array[String] = []
	for milestone_id: StringName in run.completed_milestone_ids_this_run:
		var milestone: MilestoneDataType = MilestoneCatalogSource.get_by_id(milestone_id)
		if milestone != null:
			completed_names.append(milestone.display_name.to_upper())
	var next_goal: MilestoneDataType = MilestoneResolverSource.get_next_goal(SaveManager.profile)
	var completed_text: String = "SIN HITOS NUEVOS"
	if not completed_names.is_empty():
		completed_text = "NUEVO HITO  ·  %s  ·  +%d CENIZA" % [
			" / ".join(completed_names), run.milestone_ash_awarded,
		]
	var goal_text: String = "META COMPLETADA"
	if next_goal != null:
		goal_text = "PRÓXIMO  ·  %s  ·  %s" % [
			next_goal.display_name.to_upper(),
			MilestoneResolverSource.get_progress_text(SaveManager.profile, next_goal),
		]
	var available_unlocks: Array[StringName] = MetaUnlockCatalog.get_newly_available_for_milestones(
		SaveManager.profile,
		run.completed_milestone_ids_this_run,
	)
	var unlock_text: String = ""
	if not available_unlocks.is_empty():
		var unlock_names: Array[String] = []
		for unlock_id: StringName in available_unlocks:
			unlock_names.append(MetaUnlockCatalog.get_display_name(unlock_id).to_upper())
		unlock_text = "\nNUEVA OPCIÓN DISPONIBLE · %s" % " / ".join(unlock_names)
	milestone_progress_label.text = "%s\nASHEN RANK %d  ·  %s\n%s%s" % [
		completed_text,
		MilestoneResolverSource.get_ashen_rank(SaveManager.profile),
		MilestoneResolverSource.get_rank_progress_text(SaveManager.profile),
		goal_text,
		unlock_text,
	]


func _update_boss_reward() -> void:
	var run: RunState = RunManager.current_run
	var reward: BossRewardData = BossRewardCatalog.get_by_id(run.boss_reward_id)
	boss_reward_label.visible = _is_victory and reward != null
	if reward == null:
		boss_reward_label.text = ""
		if _boss_reward_icon != null:
			_boss_reward_icon.hide()
		return
	var loot: EquipmentData = EquipmentCatalog.get_by_id(run.pending_loot_id)
	boss_reward_label.text = "RECOMPENSA DE JEFE\n%s\n%s" % [
		reward.display_name,
		BossRewardCatalog.get_result_effect(reward.id, loot),
	]
	if run.boss_chest_awarded:
		var chest: ChestData = ChestCatalog.get_by_id(run.boss_chest_id)
		boss_reward_label.text += "\nCOFRE · %s\nSIGILOS +%d" % [
			chest.display_name.to_upper() if chest != null else "RELIQUIA DE BOSS",
			run.guardian_sigils_awarded,
		]
	if _boss_reward_icon == null:
		_boss_reward_icon = AshenIcon.new()
		_boss_reward_icon.position = Vector2(14.0, 14.0)
		boss_reward_label.add_child(_boss_reward_icon)
	_boss_reward_icon.configure(reward.id, VisualTheme.EMBER_BRIGHT, AshenIcon.DisplaySize.MEDIUM)
	_boss_reward_icon.show()


func _update_loot(equipment_id: String) -> void:
	for child: Node in loot_card_host.get_children():
		child.queue_free()
	var item: EquipmentData = EquipmentCatalog.get_by_id(equipment_id)
	if item == null:
		loot_rarity_label.text = ""
		loot_name_label.text = "No encontraste equipamiento"
		loot_name_label.modulate = VisualTheme.TEXT_SECONDARY
		loot_panel.theme_type_variation = &"CardPanel"
		loot_stats_label.text = ""
		if _loot_icon != null:
			_loot_icon.hide()
		return
	loot_rarity_label.hide()
	loot_name_label.hide()
	loot_stats_label.hide()
	loot_rarity_label.text = "%s · TIER %d · REQUIERE NIVEL %d" % [EquipmentCatalog.get_rarity_name(item.rarity), item.tier, item.required_level]
	loot_rarity_label.text = loot_rarity_label.text.to_upper()
	loot_rarity_label.modulate = VisualTheme.rarity_color(item.rarity)
	loot_panel.add_theme_stylebox_override("panel", VisualTheme.rarity_card_style(item.rarity, true))
	# Results persists the run before rendering, so compare against the immutable
	# inventory snapshot captured when the expedition started.
	var is_new_item: bool = String(item.id) not in RunManager.current_run.owned_equipment_ids_at_start
	var reward_state: String = "new" if is_new_item else "owned"
	loot_name_label.text = "%s%s" % [item.display_name, "  ·  NUEVO" if is_new_item else ""]
	loot_name_label.modulate = Color.WHITE
	var passive_text: String = EquipmentCatalog.get_passive_text(item)
	loot_stats_label.text = "%s%s" % [
		"%s\nVISUAL · %s" % [EquipmentCatalog.get_stats_text(item), EquipmentVisualCatalog.get_visual_label(item)],
		"\n" + passive_text if not passive_text.is_empty() else "",
	]
	if RunManager.current_run.duplicate_converted_id == item.id:
		reward_state = "duplicate"
		loot_name_label.text = "%s · DUPLICADO RECICLADO" % item.display_name
		loot_stats_label.text = "+%d CENIZA · Conservás tu copia original" % RunManager.current_run.duplicate_ash_awarded
	if _loot_icon == null:
		_loot_icon = AshenIcon.new()
		_loot_icon.position = Vector2(8.0, 0.0)
		loot_rarity_label.add_child(_loot_icon)
	_loot_icon.configure(item.icon_id, VisualTheme.rarity_color(item.rarity), AshenIcon.DisplaySize.SMALL)
	_loot_icon.show()
	var card := ItemCardView.new()
	card.configure(
		item,
		SaveManager.profile.player_level,
		1,
		false,
		null,
		ItemCardView.Mode.REWARD,
		reward_state,
		RunManager.current_run.duplicate_ash_awarded,
	)
	loot_card_host.add_child(card)


func _attach_ash_icon() -> void:
	var icon: AshenIcon = AshenIcon.new()
	icon.configure(&"ash", VisualTheme.EMBER, AshenIcon.DisplaySize.MEDIUM)
	icon.position = Vector2(14.0, 14.0)
	ash_earned_label.add_child(icon)


func _on_return_button_pressed() -> void:
	return_button.disabled = true
	return_to_lobby_requested.emit()


func _play_result_feedback() -> void:
	if not SettingsManager.reduce_motion:
		result_title.pivot_offset = result_title.size * 0.5
		result_title.scale = Vector2(0.86, 0.86)
		result_title.modulate.a = 0.0
		var title_tween: Tween = create_tween().set_parallel(true)
		title_tween.tween_property(result_title, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		title_tween.tween_property(result_title, "modulate:a", 1.0, 0.22)

	var item: EquipmentData = EquipmentCatalog.get_by_id(RunManager.current_run.pending_loot_id)
	if item == null:
		return
	if not SettingsManager.reduce_motion:
		await get_tree().create_timer(0.24).timeout
	var rarity_pitches: Array[float] = [0.92, 1.08, 1.24]
	var rarity_pitch: float = rarity_pitches[item.rarity]
	AudioManager.play_event(AudioManager.AudioEvent.LOOT_REVEAL, rarity_pitch)
	if SettingsManager.reduce_motion:
		return
	loot_panel.pivot_offset = loot_panel.size * 0.5
	loot_panel.scale = Vector2(0.94, 0.94)
	var loot_tween: Tween = create_tween()
	loot_tween.tween_property(loot_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

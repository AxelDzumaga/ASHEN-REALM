extends Control

const MilestoneDataType = preload("res://scripts/data/milestone_data.gd")
const MilestoneCatalogSource = preload("res://scripts/meta/milestone_catalog.gd")
const MilestoneResolverSource = preload("res://scripts/meta/milestone_resolver.gd")

signal start_run_requested
signal permanent_upgrades_requested
signal equipment_requested
signal region_selection_requested
signal skill_selection_requested
signal companion_selection_requested
signal codex_requested
signal how_to_play_requested
signal settings_requested
signal main_menu_requested
signal shop_requested
signal refinement_requested

@onready var ash_badge: AshenBadge = %AshLabel
@onready var profile_stats_label: Label = %ProfileStatsLabel
@onready var player_level_label: Label = %PlayerLevelLabel
@onready var player_xp_bar: ProgressBar = %PlayerXpBar
@onready var health_badge: AshenBadge = %HealthBadge
@onready var attack_badge: AshenBadge = %AttackBadge
@onready var defense_badge: AshenBadge = %DefenseBadge
@onready var player_view: CombatCharacterView = %RefugeCharacterView
@onready var companion_view: CombatCharacterView = %RefugeCompanionView
@onready var start_run_button: Button = %StartRunButton
@onready var permanent_upgrades_button: Button = %PermanentUpgradesButton
@onready var equipment_button: Button = %EquipmentButton
@onready var selected_region_preview: PanelContainer = %SelectedRegionPreview
@onready var selected_region_thumbnail: TextureRect = %SelectedRegionThumbnail
@onready var region_label: Label = %RegionLabel
@onready var region_button: Button = %RegionButton
@onready var skill_label: Label = %SkillLabel
@onready var skill_button: Button = %SkillButton
@onready var companion_button: Button = %CompanionButton
@onready var codex_button: Button = %CodexButton
@onready var how_to_play_button: Button = %HowToPlayButton
@onready var settings_button: Button = %SettingsButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var shop_button: Button = %ShopButton
@onready var refinement_button: Button = %RefinementButton
@onready var region_icon: AshenIcon = %RegionIcon
@onready var skill_icon: AshenIcon = %SkillIcon
@onready var equipment_icon: AshenIcon = %EquipmentIcon
@onready var upgrades_icon: AshenIcon = %UpgradesIcon
@onready var codex_icon: AshenIcon = %CodexIcon
@onready var help_icon: AshenIcon = %HelpIcon
@onready var settings_icon: AshenIcon = %SettingsIcon
@onready var companion_icon: AshenIcon = %CompanionIcon
@onready var shop_icon: AshenIcon = %ShopIcon
@onready var refinement_icon: AshenIcon = %RefinementIcon
@onready var refuge_message: Label = %RefugeMessage
@onready var objective_icon: AshenIcon = %ObjectiveIcon
@onready var start_icon: AshenIcon = %StartIcon
@onready var skill_badges: Array[AshenBadge] = [%SkillBadgeOne, %SkillBadgeTwo, %SkillBadgeThree]

var _cta_tween: Tween


func _ready() -> void:
	start_run_button.pressed.connect(_on_start_run_pressed)
	permanent_upgrades_button.pressed.connect(_on_permanent_upgrades_pressed)
	equipment_button.pressed.connect(_on_equipment_pressed)
	region_button.pressed.connect(_on_region_pressed)
	skill_button.pressed.connect(_on_skill_pressed)
	companion_button.pressed.connect(_on_companion_pressed)
	codex_button.pressed.connect(_on_codex_pressed)
	how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	refinement_button.pressed.connect(_on_refinement_pressed)
	SaveManager.profile_changed.connect(_refresh_profile)
	_configure_static_icons()
	_configure_player_xp_bar()
	_configure_refuge_navigation_style()
	_configure_focus_navigation()
	player_view.setup_visual(PlayerVisualCatalog.ASHEN_WANDERER, "ASH")
	companion_view.configure_fallback_presence(&"companion", Color("ed5a1f"), VisualTheme.EMBER_DARK)
	SaveManager.evaluate_milestones()
	_refresh_profile()
	_present_pending_milestone()
	_play_refuge_entrance()
	call_deferred("_finalize_refuge_visuals")
	start_run_button.grab_focus()
	TutorialManager.request(TutorialCatalog.LOBBY_INTRO, TutorialManager.CONTEXT_LOBBY, self)


func _configure_player_xp_bar() -> void:
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color("171522")
	background_style.border_color = Color("54486e")
	background_style.set_border_width_all(1)
	background_style.set_corner_radius_all(6)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color("8268c7")
	fill_style.set_corner_radius_all(6)
	player_xp_bar.add_theme_stylebox_override("background", background_style)
	player_xp_bar.add_theme_stylebox_override("fill", fill_style)


func _configure_static_icons() -> void:
	region_icon.configure(&"biome", VisualTheme.EMBER, AshenIcon.DisplaySize.LARGE)
	equipment_icon.configure(&"weapon", VisualTheme.ATTACK, AshenIcon.DisplaySize.LARGE)
	upgrades_icon.configure(&"augment", VisualTheme.ENERGY, AshenIcon.DisplaySize.LARGE)
	codex_icon.configure(&"boon", VisualTheme.TREASURE, AshenIcon.DisplaySize.LARGE)
	help_icon.configure(&"skill", VisualTheme.UTILITY, AshenIcon.DisplaySize.LARGE)
	settings_icon.configure(&"cooldown", VisualTheme.UTILITY, AshenIcon.DisplaySize.LARGE)
	companion_icon.configure(&"ember", Color("ed6b26"), AshenIcon.DisplaySize.LARGE)
	shop_icon.configure(&"treasure", VisualTheme.TREASURE, AshenIcon.DisplaySize.LARGE)
	refinement_icon.configure(&"augment", VisualTheme.EMBER_BRIGHT, AshenIcon.DisplaySize.LARGE)
	objective_icon.configure(&"level", VisualTheme.ASH, AshenIcon.DisplaySize.MEDIUM)
	start_icon.configure(&"route", VisualTheme.EMBER_BRIGHT, AshenIcon.DisplaySize.LARGE)


func _configure_refuge_navigation_style() -> void:
	for button: Button in _side_menu_buttons():
		button.add_theme_color_override("font_color", VisualTheme.TEXT_PRIMARY)
		button.add_theme_color_override("font_hover_color", Color("fff0d2"))
		button.add_theme_color_override("font_focus_color", Color("fff0d2"))
		button.mouse_entered.connect(_animate_nav_button.bind(button, true))
		button.mouse_exited.connect(_animate_nav_button.bind(button, false))
		button.focus_entered.connect(_animate_nav_button.bind(button, true))
		button.focus_exited.connect(_animate_nav_button.bind(button, false))


func _side_menu_buttons() -> Array[Button]:
	return [
		equipment_button,
		codex_button,
		how_to_play_button,
		permanent_upgrades_button,
		companion_button,
		settings_button,
		shop_button,
		refinement_button,
	]


func _finalize_refuge_visuals() -> void:
	for button: Button in _side_menu_buttons():
		button.pivot_offset = button.size * 0.5
	start_run_button.pivot_offset = start_run_button.size * 0.5
	_start_cta_pulse()


func _animate_nav_button(button: Button, active: bool) -> void:
	if SettingsManager.reduce_motion or not is_instance_valid(button):
		return
	var target_scale := Vector2(1.025, 1.025) if active else Vector2.ONE
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, 0.12)


func _start_cta_pulse() -> void:
	if SettingsManager.reduce_motion or not is_instance_valid(start_run_button) or start_run_button.disabled:
		return
	if _cta_tween != null and _cta_tween.is_valid():
		_cta_tween.kill()
	_cta_tween = create_tween().set_loops()
	_cta_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cta_tween.tween_property(start_run_button, "modulate", Color("ffe2b5"), 1.25)
	_cta_tween.tween_property(start_run_button, "modulate", Color.WHITE, 1.25)


func _configure_focus_navigation() -> void:
	_link_horizontal(equipment_button, permanent_upgrades_button)
	_link_horizontal(codex_button, companion_button)
	_link_horizontal(how_to_play_button, settings_button)
	_link_horizontal(shop_button, refinement_button)
	_link_vertical(main_menu_button, equipment_button)
	_link_vertical(equipment_button, codex_button)
	_link_vertical(codex_button, how_to_play_button)
	_link_vertical(how_to_play_button, shop_button)
	_link_vertical(permanent_upgrades_button, companion_button)
	_link_vertical(companion_button, settings_button)
	_link_vertical(settings_button, refinement_button)
	_link_vertical(shop_button, region_button)
	_link_vertical(refinement_button, region_button)
	_link_vertical(region_button, skill_button)
	_link_vertical(skill_button, start_run_button)


func _link_horizontal(left_control: Control, right_control: Control) -> void:
	left_control.focus_neighbor_right = left_control.get_path_to(right_control)
	right_control.focus_neighbor_left = right_control.get_path_to(left_control)


func _link_vertical(top_control: Control, bottom_control: Control) -> void:
	top_control.focus_neighbor_bottom = top_control.get_path_to(bottom_control)
	bottom_control.focus_neighbor_top = bottom_control.get_path_to(top_control)


func _refresh_profile() -> void:
	var profile: ProfileData = SaveManager.profile
	ash_badge.configure(&"ash", "CENIZA %d" % profile.total_ash, AshenBadge.Variant.EMBER, AshenIcon.DisplaySize.MEDIUM)
	var biome: BiomeData = BiomeCatalog.get_available_or_default(profile.selected_biome_id, profile.completed_milestone_ids)
	profile_stats_label.text = "RANGO DE CENIZA  %d" % MilestoneResolverSource.get_ashen_rank(profile)
	var xp_requirement: int = profile.get_player_xp_requirement()
	player_xp_bar.max_value = maxi(1, xp_requirement)
	player_xp_bar.value = profile.player_xp if xp_requirement > 0 else player_xp_bar.max_value
	player_level_label.text = "NIV %d  ·  %s" % [
		profile.player_level,
		"MÁXIMO" if xp_requirement <= 0 else "EXP %d / %d" % [profile.player_xp, xp_requirement],
	]
	var preview: RunState = RunState.new()
	preview.apply_permanent_upgrades(profile)
	health_badge.configure(&"health", "VIDA %d" % preview.max_health, AshenBadge.Variant.HEAL, AshenIcon.DisplaySize.SMALL)
	attack_badge.configure(&"attack", "ATQ %d" % preview.attack, AshenBadge.Variant.ATTACK, AshenIcon.DisplaySize.SMALL)
	defense_badge.configure(&"defense", "DEF %d" % preview.defense, AshenBadge.Variant.DEFENSE, AshenIcon.DisplaySize.SMALL)

	var thumbnail: Texture2D = biome.get_board_thumbnail()
	selected_region_thumbnail.texture = thumbnail
	selected_region_preview.add_theme_stylebox_override("panel", VisualTheme.elevated_panel_style(biome.panel_color, biome.accent_color, 2, 10))
	region_label.text = "DESTINO\n%s  ·  NIV REC %d" % [biome.display_name.to_upper(), biome.recommended_level]
	region_label.modulate = biome.accent_color
	region_icon.configure(biome.id, biome.accent_color, AshenIcon.DisplaySize.LARGE)
	region_button.tooltip_text = "%s — %s — %s" % [biome.display_name, biome.get_recommended_level_label(), BiomeModifierResolver.get_compact_summary(biome)]
	region_button.add_theme_stylebox_override("normal", VisualTheme.elevated_panel_style(Color(0.055, 0.045, 0.05, 0.58), biome.accent_color, 2, 10))

	var equipped_names: Array[String] = []
	var first_skill: ActiveSkillData
	for equipped_skill_id: StringName in profile.equipped_skill_ids:
		var equipped_skill: ActiveSkillData = ActiveSkillCatalog.get_by_id(equipped_skill_id)
		if equipped_skill == null:
			continue
		if first_skill == null:
			first_skill = equipped_skill
		equipped_names.append(equipped_skill.display_name)
	skill_label.text = "SKILLS\n%s" % ("SIN EQUIPAR" if equipped_names.is_empty() else " · ".join(equipped_names))
	var skill_accent: Color = VisualTheme.ATTACK
	match first_skill.skill_type if first_skill != null else ActiveSkillData.SkillType.DAMAGE:
		ActiveSkillData.SkillType.DEFENSE:
			skill_accent = VisualTheme.DEFENSE
		ActiveSkillData.SkillType.HEAL:
			skill_accent = VisualTheme.HEAL
	skill_icon.configure(first_skill.icon_id if first_skill != null else &"skill", skill_accent, AshenIcon.DisplaySize.MEDIUM)
	_configure_skill_badges(profile.equipped_skill_ids)

	var weapon: EquipmentData = EquipmentCatalog.get_by_id(profile.equipped_weapon_id)
	var armor: EquipmentData = EquipmentCatalog.get_by_id(profile.equipped_armor_id)
	player_view.setup_equipment_visuals(weapon, armor)
	var equipped_companion: CompanionData = CompanionCatalog.get_by_id(profile.equipped_companion_id)
	var refuge_companion: CompanionData = equipped_companion
	if refuge_companion == null:
		refuge_companion = CompanionCatalog.get_by_id(CompanionCatalog.DEFAULT_COMPANION_ID)
	companion_view.visible = refuge_companion != null
	if refuge_companion != null:
		companion_view.setup_visual(refuge_companion.visual_data, "COMPAÑERO")
	if equipped_companion != null:
		companion_button.tooltip_text = "%s equipado · IA automática" % equipped_companion.display_name
	else:
		companion_button.tooltip_text = "Ember Hound espera en el Refugio · sin compañero equipado"
	companion_button.text = "COMPAÑERO"
	equipment_button.text = "EQUIPO"
	equipment_button.tooltip_text = "Arma: %s\nArmadura: %s" % [_equipment_summary(weapon, "Sin arma"), _equipment_summary(armor, "Sin armadura")]
	permanent_upgrades_button.text = "MEJORAS"
	permanent_upgrades_button.tooltip_text = "VIT %d · POD %d · GUA %d\nOpciones %d/%d · %s" % [
		profile.permanent_health_level,
		profile.permanent_attack_level,
		profile.permanent_defense_level,
		profile.owned_meta_unlock_ids.size(),
		MetaUnlockCatalog.get_all().size(),
		MetaUnlockCatalog.get_display_name(profile.selected_starting_option_id),
	]
	codex_button.text = "ARCHIVO · NUEVO" if DiscoveryTracker.has_unseen_entries() else "ARCHIVO"
	var next_goal: MilestoneDataType = MilestoneResolverSource.get_next_goal(profile)
	refuge_message.text = "META COMPLETADA · TODOS LOS HITOS" if next_goal == null else (
		"PRÓXIMO OBJETIVO · %s · %s" % [
			next_goal.display_name.to_upper(), MilestoneResolverSource.get_progress_text(profile, next_goal),
		]
	)
	start_run_button.text = "INICIAR EXPEDICIÓN\n%s" % biome.display_name.to_upper()
	start_run_button.tooltip_text = "Comenzar una run en %s" % biome.display_name
	start_run_button.add_theme_stylebox_override("normal", VisualTheme.button_style(Color("4b2018"), Color("b78945"), 4))
	start_run_button.add_theme_stylebox_override("hover", VisualTheme.button_style(Color("71301d"), VisualTheme.EMBER_BRIGHT, 4))
	start_run_button.add_theme_stylebox_override("pressed", VisualTheme.button_style(Color("351610"), VisualTheme.EMBER, 4))
	start_run_button.add_theme_stylebox_override("focus", VisualTheme.button_style(Color("5e2819"), VisualTheme.EMBER_BRIGHT, 5))


func _configure_skill_badges(skill_ids: Array[StringName]) -> void:
	for index: int in skill_badges.size():
		var badge := skill_badges[index]
		if index >= skill_ids.size():
			badge.configure(&"skill", "VACÍO", AshenBadge.Variant.UTILITY, AshenIcon.DisplaySize.SMALL, "", false)
			continue
		var skill: ActiveSkillData = ActiveSkillCatalog.get_by_id(skill_ids[index])
		if skill == null:
			badge.configure(&"skill", "VACÍO", AshenBadge.Variant.UTILITY, AshenIcon.DisplaySize.SMALL, "", false)
			continue
		var variant := AshenBadge.Variant.ATTACK
		if skill.skill_type == ActiveSkillData.SkillType.DEFENSE:
			variant = AshenBadge.Variant.DEFENSE
		elif skill.skill_type == ActiveSkillData.SkillType.HEAL:
			variant = AshenBadge.Variant.HEAL
		var short_name := skill.display_name.to_upper()
		if short_name.length() > 8:
			short_name = short_name.substr(0, 8)
		badge.configure(skill.icon_id, short_name, variant, AshenIcon.DisplaySize.SMALL)
		badge.tooltip_text = skill.display_name


func _present_pending_milestone() -> void:
	var pending: Array[StringName] = SaveManager.get_pending_milestone_ids()
	if pending.is_empty():
		return
	var names: Array[String] = []
	var reward: int = 0
	for milestone_id: StringName in pending:
		var milestone: MilestoneDataType = MilestoneCatalogSource.get_by_id(milestone_id)
		if milestone != null:
			names.append(milestone.display_name.to_upper())
			reward += milestone.reward_ash
	refuge_message.text = "HITO COMPLETADO · %s · +%d CENIZA" % [" / ".join(names), reward]
	SaveManager.acknowledge_milestone_announcements(pending)


func _equipment_summary(item: EquipmentData, empty_text: String) -> String:
	if item == null:
		return empty_text
	var passive_name: String = EquipmentEffectResolver.get_passive_name(item.passive_effect_id)
	return "%s [%s]%s" % [
		item.display_name,
		EquipmentCatalog.get_rarity_name(item.rarity).to_upper(),
		" · " + passive_name if not passive_name.is_empty() else "",
	]


func _play_refuge_entrance() -> void:
	if SettingsManager.reduce_motion:
		return
	player_view.modulate.a = 0.0
	player_view.scale = Vector2(0.98, 0.98)
	player_view.pivot_offset = player_view.size * 0.5
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(player_view, "modulate:a", 1.0, 0.24)
	tween.tween_property(player_view, "scale", Vector2.ONE, 0.24)


func _disable_navigation() -> void:
	if _cta_tween != null and _cta_tween.is_valid():
		_cta_tween.kill()
	start_run_button.disabled = true
	permanent_upgrades_button.disabled = true
	equipment_button.disabled = true
	region_button.disabled = true
	skill_button.disabled = true
	companion_button.disabled = true
	codex_button.disabled = true
	how_to_play_button.disabled = true
	settings_button.disabled = true
	shop_button.disabled = true
	refinement_button.disabled = true
	main_menu_button.disabled = true


func _on_start_run_pressed() -> void:
	_disable_navigation()
	start_run_requested.emit()


func _on_permanent_upgrades_pressed() -> void:
	_disable_navigation()
	permanent_upgrades_requested.emit()


func _on_equipment_pressed() -> void:
	_disable_navigation()
	equipment_requested.emit()


func _on_region_pressed() -> void:
	_disable_navigation()
	region_selection_requested.emit()


func _on_skill_pressed() -> void:
	_disable_navigation()
	skill_selection_requested.emit()


func _on_companion_pressed() -> void:
	_disable_navigation()
	companion_selection_requested.emit()


func _on_codex_pressed() -> void:
	_disable_navigation()
	codex_requested.emit()


func _on_how_to_play_pressed() -> void:
	_disable_navigation()
	how_to_play_requested.emit()


func _on_settings_pressed() -> void:
	_disable_navigation()
	settings_requested.emit()


func _on_main_menu_pressed() -> void:
	_disable_navigation()
	main_menu_requested.emit()


func _on_shop_pressed() -> void:
	_disable_navigation()
	shop_requested.emit()


func _on_refinement_pressed() -> void:
	_disable_navigation()
	refinement_requested.emit()

extends Control

signal upgrade_selected(upgrade: UpgradeData)

const OPTION_COUNT := 3
const CONFIRMATION_DELAY := 1.0
const REROLL_GENERATION_ATTEMPTS := 16
const REROLL_LOCK_DURATION := 0.25

const NORMAL_COMMON_CHANCE := 0.65
const NORMAL_RARE_CHANCE := 0.30
const ELITE_COMMON_CHANCE := 0.30
const ELITE_RARE_CHANCE := 0.50

@onready var title_label: Label = %Title
@onready var subtitle_label: Label = %Subtitle
@onready var stats_label: Label = %StatsLabel
@onready var build_label: Label = %BuildLabel
@onready var synergies_label: Label = %SynergiesLabel
@onready var cards: VBoxContainer = %Cards
@onready var status_label: Label = %StatusLabel
@onready var reroll_button: Button = %RerollButton

var _upgrade_pool: Array[UpgradeData] = []
var _option_buttons: Array[Button] = []
var _current_signature: String = ""
var _selection_locked: bool = false
var _reroll_locked: bool = false
var _reward_context: UpgradeRewardContext.Type = UpgradeRewardContext.Type.NORMAL
var _epic_reveal_played: bool = false
var _is_level_up: bool = false
var _level_up_options: Array[UpgradeData] = []


func configure(context: UpgradeRewardContext.Type) -> void:
	_reward_context = context


func configure_level_up(options: Array[UpgradeData]) -> void:
	_is_level_up = true
	_level_up_options = options.duplicate()


func _ready() -> void:
	_upgrade_pool = _level_up_options.duplicate() if _is_level_up else UpgradeCatalog.get_boons()
	if DebugConfig.DEBUG_TOOLS_ENABLED and DebugConfig.DEBUG_UPGRADE_REWARD_CONTEXT >= 0:
		_reward_context = UpgradeRewardContext.Type.ELITE if DebugConfig.DEBUG_UPGRADE_REWARD_CONTEXT == UpgradeRewardContext.Type.ELITE else UpgradeRewardContext.Type.NORMAL
	if not RunManager.has_active_run() or not _has_valid_pool():
		push_error("Upgrade Selection requires an active run and at least three unique upgrades.")
		return

	reroll_button.pressed.connect(_on_reroll_pressed)
	reroll_button.visible = not _is_level_up
	_update_context_presentation()
	_update_run_information()
	TutorialManager.request(TutorialCatalog.RUN_XP, TutorialManager.CONTEXT_UPGRADE, self)
	if _is_level_up:
		_create_supplied_options()
		TutorialManager.request(TutorialCatalog.RUN_LEVEL_UP, TutorialManager.CONTEXT_UPGRADE, self)
	else:
		_create_options("")
		TutorialManager.request(TutorialCatalog.PASSIVE_BOON, TutorialManager.CONTEXT_UPGRADE, self)


func _create_supplied_options() -> void:
	_clear_options()
	for upgrade: UpgradeData in _level_up_options:
		_add_upgrade_card(upgrade)
	if not _option_buttons.is_empty():
		_option_buttons[0].grab_focus()


func _has_valid_pool() -> bool:
	var unique_ids: Dictionary[StringName, bool] = {}
	for upgrade: UpgradeData in _upgrade_pool:
		if upgrade != null:
			unique_ids[upgrade.id] = true
	return unique_ids.size() >= OPTION_COUNT


func _create_options(previous_signature: String) -> void:
	_clear_options()
	_epic_reveal_played = false
	var options: Array[UpgradeData] = _generate_options(previous_signature)
	_current_signature = _make_signature(options)
	var visible_boon_ids: Array[StringName] = []
	for upgrade: UpgradeData in options:
		if upgrade.category == UpgradeData.Category.PASSIVE:
			visible_boon_ids.append(StringName(upgrade.id))
	DiscoveryTracker.discover_many(CodexCatalog.BOONS, visible_boon_ids)
	for upgrade: UpgradeData in options:
		_add_upgrade_card(upgrade)
	if not _option_buttons.is_empty():
		_option_buttons[0].grab_focus()


func _generate_options(previous_signature: String) -> Array[UpgradeData]:
	var run: RunState = RunManager.current_run
	var context: StringName = &"boon_elite" if _reward_context == UpgradeRewardContext.Type.ELITE else &"boon_normal"
	return BuildRewardResolver.generate_boon_options(
		run,
		_reward_context == UpgradeRewardContext.Type.ELITE,
		run.next_reward_offer_seed(context),
		previous_signature,
	)


func _make_signature(options: Array[UpgradeData]) -> String:
	return BuildRewardResolver.signature(options)


func _clear_options() -> void:
	_option_buttons.clear()
	for child: Node in cards.get_children():
		cards.remove_child(child)
		child.queue_free()


func _add_upgrade_card(upgrade: UpgradeData) -> void:
	var button: Button = Button.new()
	var owned: int = RunManager.current_run.get_run_level_upgrade_count(upgrade.id) if _is_level_up else (RunManager.current_run.get_boon_count(upgrade.id) if upgrade.category == UpgradeData.Category.PASSIVE else 0)
	var category_text: String = UpgradeCatalog.get_affinity_name(upgrade.affinity) if upgrade.category == UpgradeData.Category.PASSIVE else "MEJORA"
	var owned_text: String = "\nNIVEL %d → %d / %d" % [owned, owned + 1, upgrade.max_stacks] if _is_level_up else ("\nPoseídas: %d" % owned if upgrade.category == UpgradeData.Category.PASSIVE else "")
	var completes_text: String = _get_completes_text(upgrade)
	var rarity_name: String = UpgradeCatalog.get_rarity_name(upgrade.rarity)
	var rarity_color: Color = UpgradeCatalog.get_rarity_color(upgrade.rarity)
	button.theme_type_variation = &"SecondaryButton"
	button.custom_minimum_size = Vector2(0, 150)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20)
	button.text = "%s  ·  %s\n%s%s\n%s%s" % [rarity_name.to_upper(), category_text, upgrade.display_name.to_upper(), owned_text, UpgradeApplier.describe_effect(upgrade, owned), completes_text]
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.set_meta(&"audio_skip_generic", true)
	button.add_theme_stylebox_override("normal", _card_style(VisualTheme.CARD, rarity_color, 2))
	button.add_theme_stylebox_override("hover", _card_style(Color("30231d"), rarity_color.lightened(0.12), 3))
	button.add_theme_stylebox_override("focus", _card_style(Color("30231d"), rarity_color.lightened(0.2), 3))
	button.add_theme_stylebox_override("pressed", _card_style(VisualTheme.EMBER_DARK, VisualTheme.EMBER_BRIGHT, 3))
	button.pressed.connect(_on_upgrade_pressed.bind(upgrade, button))
	_attach_upgrade_icons(button, upgrade)
	cards.add_child(button)
	_option_buttons.append(button)
	if not SettingsManager.reduce_motion:
		button.modulate.a = 0.0
		button.position.x = 18.0
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(button, "modulate:a", 1.0, 0.22).set_delay((_option_buttons.size() - 1) * 0.06)
		tween.tween_property(button, "position:x", 0.0, 0.22).set_delay((_option_buttons.size() - 1) * 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if upgrade.rarity == UpgradeData.UpgradeRarity.EPIC and not _epic_reveal_played:
		_epic_reveal_played = true
		AudioManager.play_sfx(AudioManager.Sfx.EPIC_REVEAL)


func _on_upgrade_pressed(upgrade: UpgradeData, selected_button: Button) -> void:
	if _selection_locked or _reroll_locked:
		return
	_selection_locked = true
	reroll_button.disabled = true
	for button in _option_buttons:
		button.disabled = true
	selected_button.add_theme_stylebox_override("disabled", _card_style(Color("4a3214"), VisualTheme.EMBER_BRIGHT, 4))
	var owned_before: int = RunManager.current_run.get_boon_count(upgrade.id) if upgrade.category == UpgradeData.Category.PASSIVE else 0
	selected_button.text = "SELECCIONADA\n%s\n\n%s" % [upgrade.display_name, UpgradeApplier.describe_effect(upgrade, owned_before)]
	AudioManager.play_event(AudioManager.AudioEvent.LEVEL_UP if _is_level_up else AudioManager.AudioEvent.UI_CONFIRM)
	selected_button.pivot_offset = selected_button.size * 0.5
	selected_button.scale = Vector2(1.035, 1.035)
	var selection_tween: Tween = create_tween()
	selection_tween.tween_property(selected_button, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	UpgradeApplier.apply(upgrade, RunManager.current_run)
	if _is_level_up:
		RunManager.current_run.record_run_level_upgrade(upgrade)
	var completed: Array[StringName] = RunManager.current_run.consume_pending_synergy_announcements()
	DiscoveryTracker.discover_active_synergies(RunManager.current_run)
	_update_run_information()
	status_label.text = "Obtenida: %s" % upgrade.display_name
	if not completed.is_empty():
		if not await TutorialManager.request_and_wait(TutorialCatalog.SYNERGY_ACTIVATED, TutorialManager.CONTEXT_UPGRADE, self):
			return
		var synergy_names: Array[String] = []
		for synergy_id: StringName in completed:
			synergy_names.append(BoonSynergyResolver.get_display_name(synergy_id))
		status_label.text += " · SINERGIA ACTIVADA: %s" % ", ".join(synergy_names)
		for synergy_id: StringName in completed:
			if synergy_id in [
				BoonSynergyResolver.INFERNO_RHYTHM,
				BoonSynergyResolver.ASHEN_VENGEANCE,
				BoonSynergyResolver.LAST_STAND,
				BoonSynergyResolver.PHOENIX_BLOOD,
			]:
				AudioManager.play_event(AudioManager.AudioEvent.SYNERGY_ACTIVATE)
				break
	await get_tree().create_timer(CONFIRMATION_DELAY).timeout
	upgrade_selected.emit(upgrade)


func _on_reroll_pressed() -> void:
	var run: RunState = RunManager.current_run
	if _selection_locked or _reroll_locked or run.upgrade_rerolls <= 0:
		return
	_reroll_locked = true
	reroll_button.disabled = true
	run.upgrade_rerolls = maxi(0, run.upgrade_rerolls - 1)
	var previous_signature: String = _current_signature
	_create_options(previous_signature)
	_update_run_information()
	status_label.text = "Las brasas revelan nuevas opciones."
	await get_tree().create_timer(REROLL_LOCK_DURATION).timeout
	_reroll_locked = false
	reroll_button.disabled = run.upgrade_rerolls <= 0


func _update_run_information() -> void:
	var run: RunState = RunManager.current_run
	stats_label.text = "VIDA %d/%d     ATQ %d     DEF %d" % [run.current_health, run.max_health, run.attack, run.defense]
	if _is_level_up:
		build_label.text = "XP %d / %d  ·  MEJORAS TEMPORALES %d" % [run.current_xp, run.get_xp_to_next_level(), run.upgrades_obtained]
		synergies_label.visible = false
		reroll_button.visible = false
		return
	build_label.text = "CONFIGURACIÓN  ·  Ofensiva %d  ·  Defensiva %d  ·  Sostén %d" % [
		run.get_affinity_count(UpgradeData.Affinity.OFFENSE),
		run.get_affinity_count(UpgradeData.Affinity.DEFENSE),
		run.get_affinity_count(UpgradeData.Affinity.SUSTAIN),
	]
	var active: Array[StringName] = BoonSynergyResolver.get_active_ids(run)
	if active.is_empty():
		synergies_label.text = "SINERGIAS ACTIVAS\nNo hay sinergias activas"
	else:
		var lines: Array[String] = ["SINERGIAS ACTIVAS"]
		for synergy_id: StringName in active:
			lines.append("%s · %s" % [BoonSynergyResolver.get_display_name(synergy_id), BoonSynergyResolver.get_requirements_text(synergy_id)])
		synergies_label.text = "\n".join(lines)
	reroll_button.text = "VOLVER A TIRAR\n%d RESTANTES" % run.upgrade_rerolls
	reroll_button.disabled = _selection_locked or _reroll_locked or run.upgrade_rerolls <= 0


func _get_completes_text(upgrade: UpgradeData) -> String:
	if upgrade.category != UpgradeData.Category.PASSIVE:
		return ""
	var completed: Array[StringName] = BoonSynergyResolver.get_completed_by(RunManager.current_run, upgrade.id)
	if completed.is_empty():
		return ""
	var names: Array[String] = []
	for synergy_id: StringName in completed:
		names.append(BoonSynergyResolver.get_display_name(synergy_id))
	return "\nCOMPLETA SINERGIA\n%s" % ", ".join(names)


func _update_context_presentation() -> void:
	if _is_level_up:
		var run: RunState = RunManager.current_run
		var resolving_level: int = run.run_level - run.pending_level_ups + 1
		title_label.text = "NIVEL %d" % resolving_level
		title_label.modulate = VisualTheme.EMBER_BRIGHT
		subtitle_label.text = "ELEGÍ UNA MEJORA · DURA HASTA EL FINAL DE ESTA RUN"
		build_label.text = "PROGRESIÓN TEMPORAL DE RUN"
		synergies_label.visible = false
	elif _reward_context == UpgradeRewardContext.Type.ELITE:
		title_label.text = "RECOMPENSA ÉLITE"
		title_label.modulate = VisualTheme.ELITE
		subtitle_label.text = "Mayor probabilidad de rareza · Elegí una bendición."
	else:
		title_label.text = "ELEGÍ UNA BENDICIÓN"
		title_label.modulate = VisualTheme.TEXT_PRIMARY
		subtitle_label.text = "Reclamá un don de las brasas."


func _card_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = VisualTheme.elevated_panel_style(background, border, width, 12)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_top = 12
	style.content_margin_right = 18
	style.content_margin_bottom = 12
	return style


func _attach_upgrade_icons(button: Button, upgrade: UpgradeData) -> void:
	var main_icon: AshenIcon = AshenIcon.new()
	var icon_id: StringName = upgrade.id if upgrade.category == UpgradeData.Category.PASSIVE else _stat_upgrade_icon(upgrade.effect_type)
	main_icon.configure(icon_id, UpgradeCatalog.get_rarity_color(upgrade.rarity), AshenIcon.DisplaySize.MEDIUM)
	main_icon.position = Vector2(14.0, 14.0)
	button.add_child(main_icon)
	if upgrade.affinity != UpgradeData.Affinity.NONE:
		var affinity_icon: AshenIcon = AshenIcon.new()
		affinity_icon.configure(_affinity_icon(upgrade.affinity), VisualTheme.TEXT_SECONDARY, AshenIcon.DisplaySize.SMALL)
		affinity_icon.position = Vector2(46.0, 16.0)
		button.add_child(affinity_icon)
	var rarity_icon: AshenIcon = AshenIcon.new()
	rarity_icon.configure(_rarity_icon(upgrade.rarity), UpgradeCatalog.get_rarity_color(upgrade.rarity), AshenIcon.DisplaySize.SMALL)
	rarity_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rarity_icon.position = Vector2(-40.0, 14.0)
	button.add_child(rarity_icon)
	if not _get_completes_text(upgrade).is_empty():
		var synergy_icon: AshenIcon = AshenIcon.new()
		synergy_icon.configure(&"synergy", VisualTheme.EPIC, AshenIcon.DisplaySize.SMALL)
		synergy_icon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		synergy_icon.position = Vector2(-40.0, -40.0)
		button.add_child(synergy_icon)


func _affinity_icon(affinity: UpgradeData.Affinity) -> StringName:
	match affinity:
		UpgradeData.Affinity.OFFENSE:
			return &"offense"
		UpgradeData.Affinity.DEFENSE:
			return &"defense_affinity"
		UpgradeData.Affinity.SUSTAIN:
			return &"sustain"
		_:
			return &"boon"


func _stat_upgrade_icon(effect_type: UpgradeData.EffectType) -> StringName:
	match effect_type:
		UpgradeData.EffectType.MAX_HEALTH_AND_HEAL, UpgradeData.EffectType.HEAL:
			return &"health"
		UpgradeData.EffectType.DEFENSE:
			return &"defense"
		_:
			return &"attack"


func _rarity_icon(rarity: UpgradeData.UpgradeRarity) -> StringName:
	match rarity:
		UpgradeData.UpgradeRarity.RARE:
			return &"rare"
		UpgradeData.UpgradeRarity.EPIC:
			return &"epic"
		_:
			return &"common"

extends Control

signal augment_selected(augment: SkillAugmentData)

const CONFIRMATION_DELAY: float = 1.0

@onready var skill_name_label: Label = %SkillNameLabel
@onready var cards: VBoxContainer = %Cards
@onready var status_label: Label = %StatusLabel

var _buttons: Array[Button] = []
var _selection_locked: bool = false


func _ready() -> void:
	if not RunManager.has_active_run():
		push_error("Skill Augment Selection requires an active run.")
		return
	var run: RunState = RunManager.current_run
	skill_name_label.text = "AUMENTO DE HABILIDAD EQUIPADA"
	var options: Array[SkillAugmentData] = BuildRewardResolver.generate_augment_options(
		run,
		run.next_reward_offer_seed(&"skill_augment"),
	)
	var visible_augment_ids: Array[StringName] = []
	for augment: SkillAugmentData in options:
		visible_augment_ids.append(StringName(augment.id))
	DiscoveryTracker.discover_many(CodexCatalog.SKILL_AUGMENTS, visible_augment_ids)
	for augment: SkillAugmentData in options:
		_add_card(augment)
	if not _buttons.is_empty():
		_buttons[0].grab_focus()
	TutorialManager.request(TutorialCatalog.SKILL_AUGMENT, TutorialManager.CONTEXT_SKILL_AUGMENT, self)


func _add_card(augment: SkillAugmentData) -> void:
	var owned: int = RunManager.current_run.get_skill_augment_count(augment.id)
	var skill: ActiveSkillData = ActiveSkillCatalog.get_or_default(augment.skill_id)
	var button: Button = Button.new()
	button.theme_type_variation = &"SecondaryButton"
	button.custom_minimum_size = Vector2(0, 158)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 19)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.set_meta(&"audio_skip_generic", true)
	button.text = "%s  ·  RANGO %d / %d\n%s · %s\nEFECTO\n%s\nPROGRESIÓN: %s" % [
		augment.display_name.to_upper(), owned, augment.max_stacks, skill.display_name.to_upper(), augment.category,
		augment.description, SkillAugmentResolver.describe_next(augment, owned),
	]
	button.add_theme_stylebox_override("normal", VisualTheme.button_style(Color("201b28"), Color("80629a"), 3))
	button.add_theme_stylebox_override("focus", VisualTheme.button_style(Color("2d2338"), Color("c392e6"), 4))
	button.add_theme_stylebox_override("hover", VisualTheme.button_style(Color("292133"), Color("a879c7"), 3))
	button.pressed.connect(_on_augment_pressed.bind(augment, button))
	var augment_icon: AshenIcon = AshenIcon.new()
	augment_icon.configure(augment.id, VisualTheme.EPIC, AshenIcon.DisplaySize.MEDIUM)
	augment_icon.position = Vector2(14.0, 14.0)
	button.add_child(augment_icon)
	var skill_icon: AshenIcon = AshenIcon.new()
	skill_icon.configure(augment.skill_id, VisualTheme.EMBER, AshenIcon.DisplaySize.SMALL)
	skill_icon.position = Vector2(46.0, 16.0)
	button.add_child(skill_icon)
	cards.add_child(button)
	_buttons.append(button)


func _on_augment_pressed(augment: SkillAugmentData, selected_button: Button) -> void:
	if _selection_locked:
		return
	if RunManager.current_run.get_skill_augment_count(augment.id) >= augment.max_stacks:
		return
	_selection_locked = true
	for button: Button in _buttons:
		button.disabled = true
	var new_count: int = RunManager.current_run.add_skill_augment(augment.id)
	selected_button.text = "SELECCIONADO\n%s %s" % [augment.display_name.to_upper(), SkillAugmentResolver.roman(new_count)]
	selected_button.add_theme_stylebox_override("disabled", VisualTheme.button_style(Color("4a3214"), VisualTheme.EMBER_BRIGHT, 4))
	status_label.text = "Obtenido: %s %s" % [augment.display_name, SkillAugmentResolver.roman(new_count)]
	var activated: Array[StringName] = RunManager.current_run.consume_pending_synergy_announcements()
	DiscoveryTracker.discover_active_synergies(RunManager.current_run)
	if not activated.is_empty():
		var synergy_names: Array[String] = []
		for synergy_id: StringName in activated:
			synergy_names.append(BoonSynergyResolver.get_display_name(synergy_id))
		status_label.text += " · SINERGIA ACTIVADA: %s" % ", ".join(synergy_names)
		if not await TutorialManager.request_and_wait(TutorialCatalog.SYNERGY_ACTIVATED, TutorialManager.CONTEXT_SKILL_AUGMENT, self):
			return
	AudioManager.play_sfx(AudioManager.Sfx.SKILL_AUGMENT_SELECTED)
	await get_tree().create_timer(CONFIRMATION_DELAY).timeout
	augment_selected.emit(augment)

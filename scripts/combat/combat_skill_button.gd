class_name CombatSkillButton
extends Button

signal skill_requested(controller: ActiveSkillController)
signal skill_focused(controller: ActiveSkillController)

var controller: ActiveSkillController
var _icon: AshenIcon


func _init() -> void:
	custom_minimum_size = Vector2(112.0, 72.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_font_size_override("font_size", 12)
	add_theme_constant_override("outline_size", 2)
	add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.025, 0.9))
	pressed.connect(_on_pressed)
	focus_entered.connect(_on_focused)
	mouse_entered.connect(_on_focused)


func configure(skill_controller: ActiveSkillController) -> void:
	controller = skill_controller
	if _icon == null:
		_icon = AshenIcon.new()
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon.position = Vector2(9.0, 8.0)
		add_child(_icon)
	_icon.configure(controller.skill.icon_id, _skill_accent(), AshenIcon.DisplaySize.MEDIUM)
	tooltip_text = "%s\n%s" % [controller.skill.display_name, controller.skill.description]


func refresh(available_energy: int, input_enabled: bool) -> void:
	if controller == null:
		visible = false
		return
	visible = true
	var can_activate: bool = controller.can_use(available_energy)
	disabled = not input_enabled or not can_activate
	var secondary: String = "BRASA %d · LISTA" % controller.get_effective_energy_cost()
	if not can_activate:
		secondary = controller.get_status_text(available_energy).replace("RECARGA", "REC")
	text = "%s\n%s" % [controller.skill.display_name.to_upper(), secondary]
	_apply_visual_state(can_activate, input_enabled)


func _skill_accent() -> Color:
	if controller == null:
		return VisualTheme.UTILITY
	match controller.skill.skill_type:
		ActiveSkillData.SkillType.DEFENSE:
			return VisualTheme.DEFENSE
		ActiveSkillData.SkillType.HEAL:
			return VisualTheme.HEAL
		_:
			return VisualTheme.ATTACK


func _apply_visual_state(can_activate: bool, input_enabled: bool) -> void:
	var accent: Color = _skill_accent()
	var background: Color = Color("211d22")
	var border: Color = VisualTheme.BORDER
	var active_icon: bool = input_enabled and can_activate
	if active_icon:
		background = accent.darkened(0.68)
		border = accent
	elif controller != null and controller.cooldown_remaining > 0:
		background = Color("201b26")
		border = VisualTheme.UTILITY
	else:
		background = Color("19171c")
		border = VisualTheme.ENERGY_DARK.lightened(0.18)
	add_theme_stylebox_override("normal", VisualTheme.button_style(background, border, 2))
	add_theme_stylebox_override("hover", VisualTheme.button_style(background.lightened(0.08), accent, 3))
	add_theme_stylebox_override("focus", VisualTheme.button_style(background.lightened(0.06), accent, 3))
	add_theme_stylebox_override("pressed", VisualTheme.button_style(background.darkened(0.08), accent, 3))
	add_theme_stylebox_override("disabled", VisualTheme.button_style(background, border, 2))
	add_theme_color_override("font_color", VisualTheme.TEXT_PRIMARY)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_focus_color", Color.WHITE)
	add_theme_color_override("font_disabled_color", VisualTheme.MUTED.lightened(0.18))
	if _icon != null:
		_icon.configure(controller.skill.icon_id, accent, AshenIcon.DisplaySize.MEDIUM, active_icon)


func _on_pressed() -> void:
	if controller != null:
		skill_requested.emit(controller)


func _on_focused() -> void:
	if controller != null:
		skill_focused.emit(controller)

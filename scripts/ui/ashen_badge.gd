class_name AshenBadge
extends PanelContainer

enum Variant {
	NEUTRAL, EMBER, DANGER, HEAL, SYNERGY, RARITY,
	ATTACK, DEFENSE, ENERGY, BUFF, DEBUFF, UTILITY,
}

var _row: HBoxContainer
var _icon: AshenIcon
var _text_label: Label
var _counter_label: Label
var _display_size: AshenIcon.DisplaySize = AshenIcon.DisplaySize.MEDIUM


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_nodes()


func configure(icon_id: StringName, text: String, variant: Variant = Variant.NEUTRAL, display_size: AshenIcon.DisplaySize = AshenIcon.DisplaySize.MEDIUM, counter: String = "", is_active: bool = true, accent_override: Color = Color.TRANSPARENT) -> void:
	_ensure_nodes()
	_display_size = display_size
	var color: Color = _variant_color(variant) if accent_override.a <= 0.0 else accent_override
	_icon.configure(icon_id, color, display_size, is_active)
	_text_label.text = text
	_text_label.modulate = VisualTheme.TEXT_PRIMARY if is_active else VisualTheme.MUTED
	_counter_label.text = counter
	_counter_label.visible = not counter.is_empty()
	_counter_label.modulate = color if is_active else VisualTheme.MUTED
	_apply_size()
	add_theme_stylebox_override("panel", _badge_style(color, variant, is_active))


func set_text(value: String) -> void:
	_ensure_nodes()
	_text_label.text = value


func set_counter(value: String) -> void:
	_ensure_nodes()
	_counter_label.text = value
	_counter_label.visible = not value.is_empty()


func set_icon(value: StringName, color: Color) -> void:
	_ensure_nodes()
	_icon.configure(value, color, _display_size)


func _ensure_nodes() -> void:
	if _row != null:
		return
	_row = HBoxContainer.new()
	_row.name = "BadgeRow"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 6)
	add_child(_row)
	_icon = AshenIcon.new()
	_icon.name = "Icon"
	_row.add_child(_icon)
	_text_label = Label.new()
	_text_label.name = "Text"
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_text_label)
	_counter_label = Label.new()
	_counter_label.name = "Counter"
	_counter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_counter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_counter_label)
	_apply_size()


func _apply_size() -> void:
	var height: float = 28.0
	var font_size: int = 13
	match _display_size:
		AshenIcon.DisplaySize.SMALL:
			height = 24.0
			font_size = 12
		AshenIcon.DisplaySize.LARGE:
			height = 46.0
			font_size = 18
		AshenIcon.DisplaySize.XLARGE:
			height = 72.0
			font_size = 22
	custom_minimum_size = Vector2(custom_minimum_size.x, height)
	if _text_label != null:
		_text_label.add_theme_font_size_override("font_size", font_size)
		_counter_label.add_theme_font_size_override("font_size", font_size)


func _variant_color(variant: Variant) -> Color:
	match variant:
		Variant.EMBER:
			return VisualTheme.EMBER
		Variant.DANGER:
			return VisualTheme.DANGER
		Variant.HEAL:
			return VisualTheme.HEAL
		Variant.SYNERGY:
			return VisualTheme.EPIC
		Variant.RARITY:
			return VisualTheme.RARE
		Variant.ATTACK:
			return VisualTheme.ATTACK
		Variant.DEFENSE:
			return VisualTheme.DEFENSE
		Variant.ENERGY:
			return VisualTheme.ENERGY
		Variant.BUFF:
			return VisualTheme.BUFF
		Variant.DEBUFF:
			return VisualTheme.DEBUFF
		Variant.UTILITY:
			return VisualTheme.UTILITY
		_:
			return VisualTheme.BORDER


func _badge_style(color: Color, variant: Variant, is_active: bool) -> StyleBoxFlat:
	var background: Color = Color(0.055, 0.045, 0.05, 0.86)
	if variant == Variant.SYNERGY:
		background = Color(0.105, 0.055, 0.13, 0.9)
	elif variant == Variant.EMBER:
		background = Color(0.12, 0.075, 0.035, 0.88)
	elif variant == Variant.DANGER:
		background = Color(0.12, 0.045, 0.045, 0.88)
	elif variant == Variant.HEAL:
		background = Color(0.04, 0.1, 0.07, 0.88)
	elif variant == Variant.ATTACK:
		background = VisualTheme.ATTACK_DARK
	elif variant == Variant.DEFENSE:
		background = VisualTheme.DEFENSE_DARK
	elif variant == Variant.ENERGY:
		background = VisualTheme.ENERGY_DARK
	elif variant == Variant.BUFF:
		background = VisualTheme.BUFF_DARK
	elif variant == Variant.DEBUFF:
		background = VisualTheme.DEBUFF_DARK
	elif variant == Variant.UTILITY:
		background = VisualTheme.UTILITY_DARK
	if not is_active:
		background = Color(0.045, 0.04, 0.045, 0.72)
	var style: StyleBoxFlat = VisualTheme.panel_style(background, color if is_active else VisualTheme.MUTED, 1, 8)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style

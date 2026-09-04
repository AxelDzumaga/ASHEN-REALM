class_name VisualTheme
extends RefCounted

const BACKGROUND := Color("100e12")
const BACKGROUND_DEEP := Color("08070a")
const PANEL := Color("211d22")
const PANEL_RAISED := Color("2b2528")
const CARD := Color("181519")
const TEXT_PRIMARY := Color("eee5d7")
const TEXT_SECONDARY := Color("aaa1b2")
const EMBER := Color("e6a23c")
const EMBER_BRIGHT := Color("ffc866")
const EMBER_DARK := Color("78451f")
const DANGER := Color("a8433f")
const DANGER_DARK := Color("491d22")
const HEAL := Color("5f9a72")
const HEAL_DARK := Color("18372d")
const ATTACK := Color("df8738")
const ATTACK_DARK := Color("4a2918")
const DEFENSE := Color("7698ad")
const DEFENSE_DARK := Color("1c2b35")
const ENERGY := Color("f2bd55")
const ENERGY_DARK := Color("382615")
const XP := Color("9a82df")
const XP_BRIGHT := Color("c4b2ff")
const XP_DARK := Color("241d3e")
const ASH := Color("c7b9aa")
const ASH_DARK := Color("302b2a")
const BUFF := Color("55a58f")
const BUFF_DARK := Color("15342f")
const DEBUFF := Color("b75a78")
const DEBUFF_DARK := Color("3d1828")
const UTILITY := Color("b9ad9b")
const UTILITY_DARK := Color("292522")
const COMBAT := Color("b86d3e")
const BOSS := Color("c34c45")
const COMMON := Color("c1bdba")
const RARE := Color("589de0")
const EPIC := Color("a66be0")
const EVENT := Color("6f82ad")
const TREASURE := Color("d5a441")
const ELITE := Color("d0654e")
const EASY := Color("64a77b")
const MEDIUM := Color("d0a14d")
const HARD := Color("c65353")
const LOCKED := Color("817984")
const AVAILABLE := Color("77b493")
const EQUIPPED := Color("e7c56d")
const OWNED := Color("a9a2b0")
const BORDER := Color("5a504c")
const BORDER_DARK := Color("332c2b")
const MUTED := Color("625b5b")

const SPACE_XS: int = 4
const SPACE_SM: int = 8
const SPACE_MD: int = 16
const SPACE_LG: int = 24
const SPACE_XL: int = 32
const RADIUS_SM: int = 8
const RADIUS_MD: int = 10
const RADIUS_LG: int = 12
const FONT_CAPTION: int = 12
const FONT_LABEL: int = 15
const FONT_SECONDARY: int = 17
const FONT_BODY: int = 19
const FONT_ITEM_NAME: int = 22
const FONT_PRIMARY_VALUE: int = 28
const FONT_SECTION: int = 24
const FONT_TITLE: int = 40
const FONT_DISPLAY: int = 56
const TOUCH_MINIMUM: int = 48
const SCREEN_MARGIN: int = SPACE_XL
const TOUCH_HEIGHT: int = 64
const SECTION_GAP: int = SPACE_MD


static func create_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 19
	result.set_color("font_color", "Label", TEXT_PRIMARY)
	result.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	result.set_constant("shadow_offset_x", "Label", 1)
	result.set_constant("shadow_offset_y", "Label", 1)
	result.set_constant("separation", "VBoxContainer", 12)
	result.set_constant("separation", "HBoxContainer", 12)

	result.set_stylebox("panel", "PanelContainer", panel_style(PANEL, BORDER_DARK, 1, 12))
	result.set_stylebox("normal", "Button", button_style(PANEL_RAISED, BORDER, 1))
	result.set_stylebox("hover", "Button", button_style(Color("3a2d32"), EMBER, 2))
	result.set_stylebox("focus", "Button", button_style(Color("34292f"), EMBER_BRIGHT, 2))
	result.set_stylebox("pressed", "Button", button_style(EMBER_DARK, EMBER_BRIGHT, 2))
	result.set_stylebox("disabled", "Button", button_style(Color("191720"), Color("332f3a"), 1))
	result.set_color("font_color", "Button", TEXT_PRIMARY)
	result.set_color("font_hover_color", "Button", EMBER_BRIGHT)
	result.set_color("font_focus_color", "Button", EMBER_BRIGHT)
	result.set_color("font_pressed_color", "Button", Color.WHITE)
	result.set_color("font_disabled_color", "Button", MUTED)
	result.set_font_size("font_size", "Button", 21)

	_add_button_variation(result, "PrimaryButton", EMBER_DARK, EMBER, EMBER_BRIGHT)
	_add_button_variation(result, "SecondaryButton", PANEL_RAISED, BORDER, EMBER)
	_add_button_variation(result, "DangerButton", DANGER_DARK, DANGER, Color("e2766c"))
	_add_button_variation(result, "SelectedButton", Color("49301c"), EMBER, EMBER_BRIGHT)
	_add_button_variation(result, "AttackButton", ATTACK_DARK, ATTACK, Color("ffb35e"))
	_add_button_variation(result, "DefenseButton", DEFENSE_DARK, DEFENSE, Color("a9c6d6"))
	_add_button_variation(result, "HealButton", HEAL_DARK, HEAL, Color("8ac69e"))
	_add_ornamental_button_variation(result, "TitlePrimaryButton", Color("4a281b"), Color("c5934f"), EMBER_BRIGHT, true)
	_add_ornamental_button_variation(result, "TitleSecondaryButton", Color("1c1a20"), Color("615748"), Color("c9ad79"), false)
	_add_ornamental_button_variation(result, "RefugeNavLeftButton", Color("1d191c"), Color("715d43"), Color("d3a65f"), false, true)
	_add_ornamental_button_variation(result, "RefugeNavRightButton", Color("1d191c"), Color("715d43"), Color("d3a65f"), false, false)
	result.set_stylebox("disabled", "SelectedButton", button_style(Color("49301c"), EMBER_BRIGHT, 3))
	result.set_color("font_disabled_color", "SelectedButton", TEXT_PRIMARY)
	_add_panel_variation(result, "CardPanel", CARD, BORDER)
	_add_panel_variation(result, "EmberPanel", Color("2b2119"), EMBER_DARK)
	_add_panel_variation(result, "BossPanel", Color("291619"), BOSS)
	_add_panel_variation(result, "HealPanel", HEAL_DARK, HEAL)
	_add_panel_variation(result, "ArchivePanel", Color("1b171d"), Color("675846"))
	_add_panel_variation(result, "ElitePanel", Color("27191a"), ELITE)
	_add_panel_variation(result, "EnergyPanel", ENERGY_DARK, ENERGY)
	_add_panel_variation(result, "XpPanel", XP_DARK, XP)
	_add_panel_variation(result, "AshPanel", ASH_DARK, ASH)
	_add_panel_variation(result, "LockedPanel", Color("17151a"), LOCKED)
	_add_panel_variation(result, "EquippedPanel", Color("292315"), EQUIPPED)

	result.set_stylebox("background", "ProgressBar", panel_style(Color("0d0b11"), Color("322d38"), 1, 8))
	result.set_stylebox("fill", "ProgressBar", panel_style(DANGER, Color("d1665e"), 0, 8))
	result.set_color("font_color", "ProgressBar", TEXT_PRIMARY)
	result.set_stylebox("slider", "HSlider", panel_style(Color("151216"), BORDER_DARK, 1, 5))
	result.set_stylebox("grabber_area", "HSlider", panel_style(EMBER_DARK, EMBER, 1, 5))
	result.set_stylebox("grabber_area_highlight", "HSlider", panel_style(EMBER_DARK, EMBER_BRIGHT, 2, 5))
	return result


static func panel_style(background: Color, border: Color = BORDER, width: int = 1, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


static func elevated_panel_style(background: Color, border: Color = BORDER, width: int = 2, radius: int = 12) -> StyleBoxFlat:
	var style := panel_style(background, border, width, radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 4.0)
	return style


static func rarity_card_style(rarity: int, selected: bool = false) -> StyleBoxFlat:
	var colors: Array[Color] = [COMMON, RARE, EPIC]
	var safe_rarity: int = clampi(rarity, 0, colors.size() - 1)
	var border: Color = colors[safe_rarity]
	var width: int = 4 if selected else (3 if safe_rarity > 0 else 2)
	return elevated_panel_style(CARD.lightened(0.025 * safe_rarity), border, width, 12)


static func button_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := panel_style(background, border, width, 10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0.0, 3.0)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


static func rarity_color(rarity: EquipmentData.Rarity) -> Color:
	return [COMMON, RARE, EPIC][rarity]


static func difficulty_color(tier: int) -> Color:
	return [EASY, MEDIUM, HARD][clampi(tier, 0, 2)]


static func ownership_color(is_equipped: bool, is_available: bool) -> Color:
	if is_equipped:
		return EQUIPPED
	return AVAILABLE if is_available else LOCKED


static func _add_button_variation(theme: Theme, name: String, normal: Color, border: Color, accent: Color) -> void:
	theme.set_type_variation(name, "Button")
	theme.set_stylebox("normal", name, button_style(normal, border, 2))
	theme.set_stylebox("hover", name, button_style(normal.lightened(0.12), accent, 3))
	theme.set_stylebox("focus", name, button_style(normal.lightened(0.08), accent, 3))
	theme.set_stylebox("pressed", name, button_style(normal.darkened(0.08), accent, 3))
	theme.set_stylebox("disabled", name, button_style(Color("191720"), Color("332f3a"), 1))
	theme.set_color("font_color", name, TEXT_PRIMARY)
	theme.set_color("font_hover_color", name, Color.WHITE)
	theme.set_color("font_focus_color", name, Color.WHITE)
	theme.set_color("font_disabled_color", name, MUTED)


static func _add_panel_variation(theme: Theme, name: String, background: Color, border: Color) -> void:
	theme.set_type_variation(name, "PanelContainer")
	theme.set_stylebox("panel", name, elevated_panel_style(background, border, 2, 12))


static func _add_ornamental_button_variation(theme: Theme, name: String, normal: Color, border: Color, accent: Color, primary: bool, left_facing: bool = true) -> void:
	theme.set_type_variation(name, "Button")
	for state: String in ["normal", "hover", "focus", "pressed", "disabled"]:
		var background := normal
		var state_border := border
		var width := 2
		if state == "hover" or state == "focus":
			background = normal.lightened(0.1)
			state_border = accent
			width = 3
		elif state == "pressed":
			background = normal.darkened(0.1)
			state_border = accent
			width = 3
		elif state == "disabled":
			background = Color("151419")
			state_border = Color("39343a")
		var style := elevated_panel_style(background, state_border, width, 7 if primary else 5)
		style.corner_radius_top_left = 8 if left_facing else 22
		style.corner_radius_bottom_left = 8 if left_facing else 22
		style.corner_radius_top_right = 22 if left_facing else 8
		style.corner_radius_bottom_right = 22 if left_facing else 8
		style.content_margin_left = 56 if name.begins_with("RefugeNav") else 28
		style.content_margin_right = 12 if name.begins_with("RefugeNav") else 28
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		theme.set_stylebox(state, name, style)
	theme.set_color("font_color", name, TEXT_PRIMARY)
	theme.set_color("font_hover_color", name, Color.WHITE)
	theme.set_color("font_focus_color", name, Color.WHITE)
	theme.set_color("font_pressed_color", name, Color.WHITE)
	theme.set_color("font_disabled_color", name, MUTED)

class_name CombatStage
extends Control

@export var foreground_only: bool = false

var _enemy_accent: Color = VisualTheme.DANGER
var _ambient_accent: Color = VisualTheme.EMBER_DARK
var _is_elite: bool = false
var _is_boss: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func configure(is_elite: bool, is_boss: bool, ambient_accent: Color = Color.TRANSPARENT) -> void:
	_is_elite = is_elite
	_is_boss = is_boss
	_enemy_accent = VisualTheme.BOSS if is_boss else (VisualTheme.ELITE if is_elite else VisualTheme.DANGER)
	_ambient_accent = VisualTheme.EMBER_DARK if ambient_accent.a <= 0.0 else ambient_accent
	var foreground: CombatStage = get_node_or_null("StageForeground") as CombatStage
	if foreground != null:
		foreground.configure(is_elite, is_boss, _ambient_accent)
	queue_redraw()


func set_boss_phase_accent(accent: Color) -> void:
	if not _is_boss or accent.a <= 0.0:
		return
	_enemy_accent = accent
	var foreground: CombatStage = get_node_or_null("StageForeground") as CombatStage
	if foreground != null:
		foreground._enemy_accent = accent
		foreground.queue_redraw()
	queue_redraw()


static func hud_style(background: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	var style: StyleBoxFlat = VisualTheme.elevated_panel_style(background, border, border_width, 12)
	style.content_margin_left = 14.0
	style.content_margin_top = 10.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 10.0
	return style


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if foreground_only:
		_draw_foreground()
		return
	var horizon_y: float = size.y * 0.54
	var distant_tint: Color = _ambient_accent
	distant_tint.a = 0.08 if not _is_boss else 0.13
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, size.y * 0.27), Vector2(size.x * 0.18, size.y * 0.22),
		Vector2(size.x * 0.34, size.y * 0.3), Vector2(size.x * 0.56, size.y * 0.2),
		Vector2(size.x * 0.78, size.y * 0.29), Vector2(size.x, size.y * 0.23),
		Vector2(size.x, horizon_y), Vector2(0.0, horizon_y),
	]), distant_tint)
	# The painted arena already carries perspective; this overlay only separates
	# combatants from it and must not become a second opaque panel.
	var ground_color: Color = Color(0.025, 0.02, 0.035, 0.24)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, horizon_y),
		Vector2(size.x, horizon_y * 0.96),
		Vector2(size.x, size.y),
		Vector2(0.0, size.y),
	]), ground_color)
	var horizon_color: Color = _enemy_accent
	horizon_color.a = 0.15 if not _is_boss else 0.23
	draw_line(Vector2(0.0, horizon_y), Vector2(size.x, horizon_y * 0.96), horizon_color, 2.0, true)
	for line_index: int in range(1, 3):
		var ground_y: float = lerpf(horizon_y, size.y, float(line_index) / 3.0)
		draw_line(Vector2(size.x * 0.08, ground_y), Vector2(size.x * 0.92, ground_y + 4.0), Color(0.22, 0.16, 0.15, 0.2), 1.5, true)


func _draw_foreground() -> void:
	var edge_alpha: float = 0.48 if _is_boss else (0.34 if _is_elite else 0.27)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, size.y * 0.72), Vector2(size.x * 0.12, size.y * 0.78),
		Vector2(size.x * 0.18, size.y), Vector2(0.0, size.y),
	]), Color(0.015, 0.012, 0.016, edge_alpha))
	var lower_tint: Color = _ambient_accent
	lower_tint.a = 0.055
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, size.y * 0.91), Vector2(size.x, size.y * 0.89),
		Vector2(size.x, size.y), Vector2(0.0, size.y),
	]), lower_tint)
	draw_colored_polygon(PackedVector2Array([
		Vector2(size.x, size.y * 0.68), Vector2(size.x * 0.88, size.y * 0.77),
		Vector2(size.x * 0.82, size.y), Vector2(size.x, size.y),
	]), Color(0.015, 0.012, 0.016, edge_alpha))

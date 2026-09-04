class_name RegionCardDecoration
extends Control

var biome: BiomeData
var selected: bool = false
var unlocked: bool = true


func configure(data: BiomeData, is_selected: bool, is_unlocked: bool) -> void:
	biome = data
	selected = is_selected
	unlocked = is_unlocked
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if biome == null or size.x <= 0.0:
		return
	var visual_width := minf(172.0, size.x * 0.28)
	var color := biome.accent_color if unlocked else VisualTheme.LOCKED
	var panel_color := biome.panel_color
	panel_color.a = 0.96
	draw_rect(Rect2(0.0, 0.0, visual_width, size.y), panel_color)
	draw_rect(Rect2(visual_width - 3.0, 14.0, 3.0, size.y - 28.0), Color(color, 0.7))
	draw_circle(Vector2(visual_width * 0.5, size.y * 0.43), visual_width * 0.36, Color(color, 0.075))
	if biome.id == &"ember_marsh": _draw_marsh(visual_width, color)
	else: _draw_wastes(visual_width, color)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(18.0, size.y - 26.0), "PELIGRO", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, VisualTheme.TEXT_SECONDARY)
	for index: int in 5:
		var pip_color := color if index < biome.danger_rating else Color(0.22, 0.2, 0.22, 0.8)
		draw_circle(Vector2(82.0 + float(index) * 15.0, size.y - 31.0), 4.5, pip_color)
	if selected:
		draw_polyline(PackedVector2Array([Vector2(12.0, 16.0), Vector2(22.0, 26.0), Vector2(39.0, 8.0)]), VisualTheme.EQUIPPED, 4.0, true)
	if not unlocked:
		draw_rect(Rect2(visual_width * 0.37, size.y * 0.29, visual_width * 0.26, size.y * 0.25), Color(0.04, 0.035, 0.05, 0.92), true)
		draw_arc(Vector2(visual_width * 0.5, size.y * 0.3), visual_width * 0.1, PI, TAU, 16, VisualTheme.LOCKED, 3.0, true)


func _draw_wastes(width: float, color: Color) -> void:
	draw_polyline(PackedVector2Array([Vector2(15.0, size.y * 0.63), Vector2(width * 0.36, size.y * 0.26), Vector2(width * 0.52, size.y * 0.5), Vector2(width * 0.7, size.y * 0.2), Vector2(width - 14.0, size.y * 0.63)]), color, 4.0, true)
	draw_line(Vector2(14.0, size.y * 0.68), Vector2(width - 14.0, size.y * 0.68), color.darkened(0.25), 3.0)
	draw_circle(Vector2(width * 0.75, size.y * 0.18), 6.0, color)


func _draw_marsh(width: float, color: Color) -> void:
	draw_polyline(PackedVector2Array([Vector2(14.0, size.y * 0.62), Vector2(width * 0.3, size.y * 0.55), Vector2(width * 0.5, size.y * 0.64), Vector2(width * 0.7, size.y * 0.54), Vector2(width - 14.0, size.y * 0.63)]), color, 4.0, true)
	for x: float in [0.28, 0.48, 0.68]:
		draw_line(Vector2(width * x, size.y * 0.56), Vector2(width * (x + 0.03), size.y * 0.2), color, 3.0)
		draw_line(Vector2(width * (x + 0.03), size.y * 0.35), Vector2(width * (x + 0.14), size.y * 0.29), color, 3.0)

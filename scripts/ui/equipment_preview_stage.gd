class_name EquipmentPreviewStage
extends Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var center := Vector2(size.x * 0.5, size.y * 0.56)
	var radius := minf(size.x * 0.28, size.y * 0.42)
	var ambient := VisualTheme.EMBER_DARK
	ambient.a = 0.2
	draw_circle(center, radius, ambient)
	draw_arc(center, radius * 0.82, -2.75, -0.39, 40, Color(0.68, 0.46, 0.22, 0.42), 2.0, true)
	draw_arc(center, radius * 0.62, 0.35, 2.78, 32, Color(0.45, 0.36, 0.28, 0.34), 1.5, true)
	for side: float in [-1.0, 1.0]:
		var pillar_x: float = center.x + side * radius * 1.16
		draw_rect(Rect2(pillar_x - 9.0, size.y * 0.18, 18.0, size.y * 0.59), Color(0.075, 0.065, 0.07, 0.88), true)
		draw_rect(Rect2(pillar_x - 13.0, size.y * 0.16, 26.0, 7.0), Color(0.24, 0.19, 0.15, 0.9), true)
		draw_line(Vector2(pillar_x, size.y * 0.2), Vector2(pillar_x, size.y * 0.7), Color(0.46, 0.32, 0.18, 0.38), 1.0, true)
	var floor_center := Vector2(center.x, size.y * 0.88)
	draw_set_transform(floor_center, 0.0, Vector2(1.0, 0.19))
	draw_circle(Vector2.ZERO, radius * 0.92, Color(0.015, 0.012, 0.017, 0.78))
	draw_arc(Vector2.ZERO, radius * 0.82, 0.0, TAU, 44, Color(0.72, 0.48, 0.2, 0.42), 7.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var diamond := PackedVector2Array([
		Vector2(center.x, size.y * 0.08),
		Vector2(center.x + 8.0, size.y * 0.13),
		Vector2(center.x, size.y * 0.18),
		Vector2(center.x - 8.0, size.y * 0.13),
	])
	draw_colored_polygon(diamond, Color(0.82, 0.55, 0.22, 0.72))

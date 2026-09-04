class_name PathLines
extends Control

var points: PackedVector2Array = PackedVector2Array()
var current_index: int = 0
var accent_color: Color = VisualTheme.EMBER


func set_points(new_points: PackedVector2Array) -> void:
	points = new_points
	queue_redraw()


func configure(new_accent_color: Color) -> void:
	accent_color = new_accent_color
	queue_redraw()


func set_progress(new_current_index: int) -> void:
	current_index = maxi(0, new_current_index)
	queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	for index in range(points.size() - 1):
		var segment_color: Color = accent_color if index < current_index else VisualTheme.BORDER_DARK
		segment_color.a = 0.86 if index < current_index else 0.68
		var curve: PackedVector2Array = _curved_segment(points[index], points[index + 1], index)
		draw_polyline(curve, Color(0.018, 0.014, 0.018, 0.94), 12.0, true)
		draw_polyline(curve, segment_color, 4.0, true)
		draw_circle(points[index], 5.0, VisualTheme.BACKGROUND_DEEP)
		draw_circle(points[index], 2.5, segment_color)
	draw_circle(points[points.size() - 1], 5.0, VisualTheme.BACKGROUND_DEEP)
	var boss_color: Color = VisualTheme.BOSS
	boss_color.a = 0.9
	draw_circle(points[points.size() - 1], 3.5, boss_color)


func _curved_segment(start: Vector2, finish: Vector2, segment_index: int) -> PackedVector2Array:
	var direction: Vector2 = finish - start
	var normal: Vector2 = Vector2(-direction.y, direction.x).normalized()
	var bend: float = 8.0 if segment_index % 2 == 0 else -8.0
	var control: Vector2 = (start + finish) * 0.5 + normal * bend
	var curve: PackedVector2Array = PackedVector2Array()
	for step: int in range(9):
		var weight: float = float(step) / 8.0
		var inverse: float = 1.0 - weight
		curve.append(inverse * inverse * start + 2.0 * inverse * weight * control + weight * weight * finish)
	return curve

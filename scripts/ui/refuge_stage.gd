class_name RefugeStage
extends Control

@export var foreground_only: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if foreground_only:
		_draw_foreground()
	else:
		_draw_sanctuary()


func _draw_sanctuary() -> void:
	var width: float = size.x
	var height: float = size.y
	for band: int in 12:
		var ratio := float(band) / 11.0
		draw_rect(Rect2(0.0, height * ratio, width, height / 11.0 + 2.0), Color("211b20").lerp(Color("0c0b0f"), ratio))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, height * 0.18), Vector2(width * 0.25, height * 0.08), Vector2(width * 0.46, height * 0.2),
		Vector2(width * 0.7, height * 0.06), Vector2(width, height * 0.16), Vector2(width, height * 0.76), Vector2(0.0, height * 0.76),
	]), Color("21181a"))
	for row: int in 8:
		var y := height * (0.1 + float(row) * 0.078)
		draw_line(Vector2(width * 0.04, y), Vector2(width * 0.96, y), Color(0.34, 0.29, 0.29, 0.22), 2.0)
		var shift := 0.05 if row % 2 == 0 else 0.0
		for column: int in 7:
			var x := width * (shift + 0.12 + float(column) * 0.14)
			draw_line(Vector2(x, y - height * 0.074), Vector2(x, y), Color(0.3, 0.25, 0.26, 0.17), 2.0)
	_draw_broken_column(width * 0.08, height * 0.2, width * 0.12, height * 0.58)
	_draw_broken_column(width * 0.79, height * 0.13, width * 0.13, height * 0.65)
	_draw_banner(width * 0.13, height * 0.13, width * 0.11, height * 0.31, Color("332028"))
	_draw_banner(width * 0.76, height * 0.1, width * 0.11, height * 0.29, Color("2b2835"))
	_draw_sconce(Vector2(width * 0.22, height * 0.39), width)
	_draw_sconce(Vector2(width * 0.78, height * 0.37), width)
	var arch_center := Vector2(width * 0.5, height * 0.53)
	# Halo radial detrás del personaje — le da presencia y separa la silueta
	# del fondo, que de otro modo queda demasiado bajo en contraste para
	# leerse como profundidad real (en vez de reconstruir el santuario, se
	# refuerza lo que ya estaba dibujado).
	draw_circle(arch_center, width * 0.62, Color(0.55, 0.24, 0.1, 0.05))
	draw_circle(arch_center, width * 0.42, Color(0.68, 0.3, 0.11, 0.09))
	draw_colored_polygon(PackedVector2Array([Vector2(width * 0.31, height * 0.08), Vector2(width * 0.69, height * 0.08), Vector2(width * 0.82, height * 0.73), Vector2(width * 0.18, height * 0.73)]), Color(0.72, 0.49, 0.24, 0.09))
	draw_circle(arch_center, width * 0.28, Color(0.83, 0.38, 0.1, 0.13))
	draw_arc(arch_center, width * 0.3, PI, TAU, 32, Color("83694f"), 20.0, true)
	draw_arc(arch_center, width * 0.25, PI, TAU, 32, Color("453530"), 8.0, true)
	draw_line(Vector2(width * 0.2, height * 0.52), Vector2(width * 0.2, height * 0.76), Color("54433b"), 18.0)
	draw_line(Vector2(width * 0.8, height * 0.52), Vector2(width * 0.8, height * 0.76), Color("54433b"), 18.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0.0, height * 0.72), Vector2(width, height * 0.72), Vector2(width, height), Vector2(0.0, height)]), Color("171216"))
	for index: int in 6:
		var y: float = height * (0.76 + float(index) * 0.04)
		draw_line(Vector2(width * 0.08, y), Vector2(width * 0.92, y + float(index % 2) * 5.0), Color("392a27"), 2.0, true)
	for index: int in 7:
		var x := width * (0.08 + float(index) * 0.14)
		draw_line(Vector2(width * 0.5, height * 0.71), Vector2(x, height), Color(0.32, 0.25, 0.24, 0.42), 2.0, true)
	var brazier_center := Vector2(width * 0.5, height * 0.7)
	draw_circle(brazier_center, width * 0.18, Color(0.65, 0.2, 0.055, 0.22))
	draw_colored_polygon(PackedVector2Array([brazier_center + Vector2(-32.0, 14.0), brazier_center + Vector2(32.0, 14.0), brazier_center + Vector2(22.0, 34.0), brazier_center + Vector2(-22.0, 34.0)]), Color("5a3a2c"))
	draw_colored_polygon(PackedVector2Array([brazier_center + Vector2(-9.0, 10.0), brazier_center + Vector2(0.0, -25.0), brazier_center + Vector2(11.0, 8.0), brazier_center + Vector2(1.0, 20.0)]), Color("e0651f"))
	var embers: Array[Vector2] = [
		Vector2(0.18, 0.34), Vector2(0.3, 0.57), Vector2(0.68, 0.28), Vector2(0.82, 0.5), Vector2(0.57, 0.16), Vector2(0.12, 0.67),
		Vector2(0.24, 0.22), Vector2(0.42, 0.12), Vector2(0.76, 0.4), Vector2(0.88, 0.2), Vector2(0.06, 0.48), Vector2(0.63, 0.62),
	]
	for index: int in embers.size():
		var ember: Vector2 = embers[index]
		var radius: float = 1.6 + fmod(float(index) * 0.7, 2.2)
		draw_circle(Vector2(width * ember.x, height * ember.y), radius, Color(0.92, 0.35, 0.1, 0.62))


func _draw_banner(x: float, y: float, banner_width: float, banner_height: float, color: Color) -> void:
	draw_line(Vector2(x - 6.0, y), Vector2(x + banner_width + 6.0, y), Color("77624b"), 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(x, y + 5.0), Vector2(x + banner_width, y + 5.0), Vector2(x + banner_width * 0.88, y + banner_height), Vector2(x + banner_width * 0.5, y + banner_height * 0.85), Vector2(x + banner_width * 0.12, y + banner_height)]), color)
	draw_line(Vector2(x + banner_width * 0.5, y + 20.0), Vector2(x + banner_width * 0.5, y + banner_height * 0.7), Color(0.7, 0.53, 0.29, 0.35), 3.0)


func _draw_sconce(center: Vector2, width: float) -> void:
	draw_circle(center, width * 0.11, Color(0.9, 0.37, 0.09, 0.14))
	draw_line(center + Vector2(-15.0, 8.0), center + Vector2(15.0, 8.0), Color("8a7156"), 5.0)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-6.0, 4.0), center + Vector2(0.0, -17.0), center + Vector2(8.0, 3.0), center + Vector2(1.0, 11.0)]), Color("d9682a"))


func _draw_broken_column(x: float, top: float, column_width: float, bottom: float) -> void:
	var points := PackedVector2Array([Vector2(x, bottom), Vector2(x + column_width, bottom), Vector2(x + column_width * 0.88, top + 28.0), Vector2(x + column_width * 0.62, top), Vector2(x + column_width * 0.42, top + 18.0), Vector2(x + column_width * 0.18, top + 5.0)])
	draw_colored_polygon(points, Color("332625"))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[5], points[0]]), Color("584039"), 3.0, true)


func _draw_foreground() -> void:
	var width: float = size.x
	var height: float = size.y
	draw_colored_polygon(PackedVector2Array([Vector2(0.0, height * 0.7), Vector2(width * 0.09, height * 0.65), Vector2(width * 0.18, height), Vector2(0.0, height)]), Color(0.035, 0.025, 0.03, 0.92))
	draw_colored_polygon(PackedVector2Array([Vector2(width, height * 0.66), Vector2(width * 0.9, height * 0.7), Vector2(width * 0.82, height), Vector2(width, height)]), Color(0.035, 0.025, 0.03, 0.92))
	draw_rect(Rect2(0.0, height * 0.92, width, height * 0.08), Color(0.025, 0.02, 0.025, 0.82))
	draw_line(Vector2(width * 0.13, height * 0.9), Vector2(width * 0.87, height * 0.9), Color(0.43, 0.34, 0.29, 0.5), 3.0)

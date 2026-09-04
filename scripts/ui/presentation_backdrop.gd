class_name PresentationBackdrop
extends Control

var mode: StringName = &"default"
var accent: Color = VisualTheme.EMBER_DARK
var secondary: Color = VisualTheme.ASH_DARK


func configure(screen_name: String) -> void:
	mode = StringName(screen_name.to_lower())
	match screen_name:
		"Combat":
			accent = VisualTheme.DANGER_DARK
			secondary = VisualTheme.ATTACK_DARK
		"Board":
			accent = VisualTheme.EMBER_DARK
			secondary = VisualTheme.ASH_DARK
		"Lobby", "MainMenu":
			accent = Color("60421f")
			secondary = Color("30272a")
		"EventScreen":
			accent = Color("4b354f")
			secondary = VisualTheme.EVENT.darkened(0.58)
		"TreasureScreen":
			accent = Color("64451f")
			secondary = VisualTheme.TREASURE.darkened(0.66)
		"RegionSelection":
			accent = Color("3d4c49")
			secondary = Color("513328")
		"Equipment":
			accent = Color("4f3826")
			secondary = Color("2e303a")
		"RunResult":
			accent = Color("49333d")
			secondary = VisualTheme.XP_DARK
		"Codex":
			accent = Color("40354b")
			secondary = Color("262331")
		_:
			accent = VisualTheme.EMBER_DARK
			secondary = VisualTheme.ASH_DARK
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var width := size.x
	var height := size.y
	_draw_depth_bands(width, height)
	_draw_far_silhouettes(width, height)
	match mode:
		&"regionselection": _draw_region_world(width, height)
		&"eventscreen": _draw_shrine(width, height)
		&"treasurescreen": _draw_vault(width, height)
		&"equipment": _draw_armory(width, height)
		&"runresult": _draw_result_arch(width, height)
		_: _draw_generic_arch(width, height)
	_draw_frame(width, height)
	_draw_motes(width, height)


func _draw_depth_bands(width: float, height: float) -> void:
	for band: int in 12:
		var ratio := float(band) / 11.0
		draw_rect(Rect2(0.0, height * ratio, width, height / 11.0 + 2.0), Color("17141a").lerp(Color("07070a"), ratio))
	var top_haze := accent
	top_haze.a = 0.1
	draw_rect(Rect2(0.0, 0.0, width, height * 0.36), top_haze)
	var lower_haze := secondary
	lower_haze.a = 0.08
	draw_rect(Rect2(0.0, height * 0.55, width, height * 0.45), lower_haze)


func _draw_far_silhouettes(width: float, height: float) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(0.0, height * 0.23), Vector2(width * 0.18, height * 0.17), Vector2(width * 0.37, height * 0.25), Vector2(width * 0.58, height * 0.15), Vector2(width * 0.78, height * 0.24), Vector2(width, height * 0.17), Vector2(width, height * 0.43), Vector2(0.0, height * 0.43)]), Color(0.025, 0.023, 0.03, 0.72))
	var ridge := accent
	ridge.a = 0.2
	draw_polyline(PackedVector2Array([Vector2(0.0, height * 0.23), Vector2(width * 0.18, height * 0.17), Vector2(width * 0.37, height * 0.25), Vector2(width * 0.58, height * 0.15), Vector2(width * 0.78, height * 0.24), Vector2(width, height * 0.17)]), ridge, 2.0, true)


func _draw_generic_arch(width: float, height: float) -> void:
	var center := Vector2(width * 0.5, height * 0.46)
	var glow := accent
	glow.a = 0.055
	draw_circle(center, width * 0.34, glow)
	draw_arc(center, width * 0.31, PI, TAU, 32, Color(0.45, 0.38, 0.34, 0.22), 12.0, true)


func _draw_region_world(width: float, height: float) -> void:
	var horizon := height * 0.72
	draw_colored_polygon(PackedVector2Array([Vector2(0.0, horizon), Vector2(width * 0.12, height * 0.58), Vector2(width * 0.25, height * 0.69), Vector2(width * 0.38, height * 0.53), Vector2(width * 0.52, horizon), Vector2(0.0, horizon)]), Color(0.15, 0.12, 0.13, 0.44))
	for x: float in [0.64, 0.72, 0.82, 0.91]:
		draw_line(Vector2(width * x, horizon), Vector2(width * (x + 0.015), height * (0.48 + fmod(x, 0.08))), Color(0.17, 0.28, 0.24, 0.48), 5.0)
	draw_line(Vector2(width * 0.5, height * 0.28), Vector2(width * 0.5, height * 0.8), Color(0.57, 0.48, 0.4, 0.12), 2.0)


func _draw_shrine(width: float, height: float) -> void:
	var center := Vector2(width * 0.5, height * 0.36)
	var glow := accent
	glow.a = 0.09
	draw_circle(center, width * 0.19, glow)
	draw_polyline(PackedVector2Array([center + Vector2(-70.0, 80.0), center + Vector2(-52.0, -45.0), center + Vector2(0.0, -96.0), center + Vector2(52.0, -45.0), center + Vector2(70.0, 80.0)]), Color(0.46, 0.39, 0.45, 0.34), 8.0, true)
	draw_arc(center, 42.0, 0.0, TAU, 24, Color(0.71, 0.57, 0.78, 0.32), 3.0, true)


func _draw_vault(width: float, height: float) -> void:
	var center := Vector2(width * 0.5, height * 0.39)
	for radius: float in [width * 0.12, width * 0.2, width * 0.3]:
		draw_arc(center, radius, PI * 1.08, PI * 1.92, 28, Color(0.76, 0.56, 0.24, 0.13), 3.0, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-55.0, 35.0), center + Vector2(55.0, 35.0), center + Vector2(45.0, 82.0), center + Vector2(-45.0, 82.0)]), Color(0.23, 0.15, 0.08, 0.48))


func _draw_armory(width: float, height: float) -> void:
	for side: float in [0.12, 0.88]:
		var x := width * side
		draw_line(Vector2(x, height * 0.18), Vector2(x, height * 0.78), Color(0.39, 0.32, 0.28, 0.28), 8.0)
		draw_line(Vector2(x - 34.0, height * 0.34), Vector2(x + 34.0, height * 0.34), Color(0.5, 0.4, 0.3, 0.25), 4.0)
		draw_line(Vector2(x - 34.0, height * 0.58), Vector2(x + 34.0, height * 0.58), Color(0.5, 0.4, 0.3, 0.25), 4.0)
	_draw_generic_arch(width, height)


func _draw_result_arch(width: float, height: float) -> void:
	var center := Vector2(width * 0.5, height * 0.36)
	var glow := secondary
	glow.a = 0.12
	draw_circle(center, width * 0.28, glow)
	for side: float in [-1.0, 1.0]:
		for index: int in 5:
			var y := height * (0.22 + float(index) * 0.055)
			var x := center.x + side * (80.0 + float(index) * 22.0)
			draw_line(Vector2(center.x + side * 38.0, center.y), Vector2(x, y), Color(0.72, 0.58, 0.38, 0.18), 3.0)


func _draw_frame(width: float, height: float) -> void:
	var frame := Color(0.57, 0.47, 0.38, 0.17)
	draw_line(Vector2(18.0, 28.0), Vector2(18.0, height - 28.0), frame, 2.0)
	draw_line(Vector2(width - 18.0, 28.0), Vector2(width - 18.0, height - 28.0), frame, 2.0)
	for corner: Vector2 in [Vector2(18.0, 28.0), Vector2(width - 18.0, 28.0), Vector2(18.0, height - 28.0), Vector2(width - 18.0, height - 28.0)]:
		draw_circle(corner, 4.0, Color(0.73, 0.57, 0.31, 0.38))


func _draw_motes(width: float, height: float) -> void:
	var positions: Array[Vector2] = [Vector2(0.09, 0.15), Vector2(0.84, 0.12), Vector2(0.73, 0.31), Vector2(0.17, 0.43), Vector2(0.91, 0.56), Vector2(0.12, 0.76), Vector2(0.79, 0.84), Vector2(0.47, 0.92)]
	for normalized: Vector2 in positions:
		var point := Vector2(width * normalized.x, height * normalized.y)
		draw_circle(point, 2.4, Color(0.88, 0.52, 0.22, 0.2))
		draw_circle(point, 1.0, Color(1.0, 0.77, 0.4, 0.34))

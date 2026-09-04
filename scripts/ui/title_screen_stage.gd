class_name TitleScreenStage
extends Control

var _time: float = 0.0
var _motes: Array[Vector3] = [
	Vector3(0.08, 0.74, 0.6), Vector3(0.14, 0.31, 0.9), Vector3(0.22, 0.57, 0.5),
	Vector3(0.31, 0.83, 0.8), Vector3(0.41, 0.39, 0.7), Vector3(0.53, 0.69, 1.0),
	Vector3(0.61, 0.24, 0.6), Vector3(0.7, 0.51, 0.85), Vector3(0.78, 0.78, 0.55),
	Vector3(0.86, 0.35, 0.9), Vector3(0.93, 0.64, 0.7), Vector3(0.49, 0.16, 0.5),
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(not SettingsManager.reduce_motion)
	queue_redraw()


func _process(delta: float) -> void:
	_time = fmod(_time + delta, 24.0)
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var width := size.x
	var height := size.y
	for band: int in 16:
		var ratio := float(band) / 15.0
		var color := Color("17151b").lerp(Color("07070a"), ratio)
		draw_rect(Rect2(0.0, height * ratio, width, height / 15.0 + 2.0), color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, height * 0.34), Vector2(width * 0.12, height * 0.26), Vector2(width * 0.25, height * 0.35),
		Vector2(width * 0.4, height * 0.22), Vector2(width * 0.57, height * 0.36), Vector2(width * 0.75, height * 0.24),
		Vector2(width, height * 0.37), Vector2(width, height * 0.62), Vector2(0.0, height * 0.62),
	]), Color("111016"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, height * 0.46), Vector2(width * 0.2, height * 0.37), Vector2(width * 0.35, height * 0.48),
		Vector2(width * 0.52, height * 0.33), Vector2(width * 0.68, height * 0.47), Vector2(width * 0.87, height * 0.35),
		Vector2(width, height * 0.42), Vector2(width, height * 0.69), Vector2(0.0, height * 0.69),
	]), Color("1b171c"))
	var center := Vector2(width * 0.5, height * 0.47)
	draw_circle(center, width * 0.37, Color(0.48, 0.34, 0.17, 0.055))
	draw_arc(center, width * 0.285, PI, TAU, 40, Color("554638"), 18.0, true)
	draw_arc(center, width * 0.235, PI, TAU, 40, Color("292329"), 7.0, true)
	draw_line(Vector2(width * 0.215, height * 0.47), Vector2(width * 0.215, height * 0.69), Color("51443a"), 16.0)
	draw_line(Vector2(width * 0.785, height * 0.47), Vector2(width * 0.785, height * 0.69), Color("51443a"), 16.0)
	draw_line(Vector2(width * 0.23, height * 0.47), Vector2(width * 0.23, height * 0.69), Color("211d22"), 5.0)
	draw_line(Vector2(width * 0.77, height * 0.47), Vector2(width * 0.77, height * 0.69), Color("211d22"), 5.0)
	_draw_title_crest(Vector2(width * 0.5, height * 0.235), width * 0.085)
	draw_colored_polygon(PackedVector2Array([Vector2(0.0, height * 0.67), Vector2(width, height * 0.67), Vector2(width, height), Vector2(0.0, height)]), Color("09090d"))
	draw_colored_polygon(PackedVector2Array([Vector2(width * 0.28, height * 0.66), Vector2(width * 0.72, height * 0.66), Vector2(width * 0.83, height * 0.72), Vector2(width * 0.17, height * 0.72)]), Color("292126"))
	draw_line(Vector2(width * 0.18, height * 0.715), Vector2(width * 0.82, height * 0.715), Color("6f573d"), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0.0, height * 0.62), Vector2(width * 0.12, height * 0.57), Vector2(width * 0.19, height), Vector2(0.0, height)]), Color("050508"))
	draw_colored_polygon(PackedVector2Array([Vector2(width, height * 0.6), Vector2(width * 0.88, height * 0.56), Vector2(width * 0.82, height), Vector2(width, height)]), Color("050508"))
	_draw_motes(width, height)


func _draw_title_crest(center: Vector2, radius: float) -> void:
	var gold := Color("b99a68")
	var dark_gold := Color(0.44, 0.31, 0.18, 0.65)
	draw_polyline(PackedVector2Array([center + Vector2(0.0, -radius), center + Vector2(radius * 0.7, 0.0), center + Vector2(0.0, radius), center + Vector2(-radius * 0.7, 0.0), center + Vector2(0.0, -radius)]), dark_gold, 5.0, true)
	draw_arc(center, radius * 0.44, 0.0, TAU, 24, gold, 2.0, true)
	draw_line(center + Vector2(0.0, -radius * 0.34), center + Vector2(0.0, radius * 0.34), gold, 2.0)
	draw_line(center + Vector2(-radius * 0.22, 0.0), center + Vector2(radius * 0.22, 0.0), gold, 2.0)


func _draw_motes(width: float, height: float) -> void:
	for index: int in _motes.size():
		var mote := _motes[index]
		var drift := 0.0 if SettingsManager.reduce_motion else sin(_time * (0.25 + mote.z * 0.1) + float(index)) * 0.018
		var rise := 0.0 if SettingsManager.reduce_motion else fmod(_time * 0.008 * mote.z + float(index) * 0.067, 0.34)
		var point := Vector2(width * (mote.x + drift), height * (mote.y - rise))
		draw_circle(point, 1.2 + mote.z, Color(0.88, 0.48, 0.17, 0.22 + mote.z * 0.2))

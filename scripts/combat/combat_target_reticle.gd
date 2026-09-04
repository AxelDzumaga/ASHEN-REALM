class_name CombatTargetReticle
extends Control

var _active: bool = false
var _accent: Color = VisualTheme.EMBER_BRIGHT
var _phase: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func set_targeted(active: bool, accent: Color = VisualTheme.EMBER_BRIGHT) -> void:
	_active = active
	_accent = accent
	visible = active
	set_process(active and not SettingsManager.reduce_motion)
	queue_redraw()


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 4.2, TAU)
	queue_redraw()


func _draw() -> void:
	if not _active or size.x <= 0.0 or size.y <= 0.0:
		return
	var pulse: float = 1.0 if SettingsManager.reduce_motion else 1.0 + sin(_phase) * 0.055
	var center := Vector2(size.x * 0.5, size.y * 0.47)
	var radius: float = minf(size.x * 0.39, size.y * 0.38) * pulse
	var glow := _accent
	glow.a = 0.16
	draw_circle(center, radius * 0.84, glow)
	var line_color := _accent.lightened(0.16)
	for quadrant: int in 4:
		var start: float = quadrant * PI * 0.5 + 0.18
		draw_arc(center, radius, start, start + 0.82, 12, line_color, 4.0, true)
	var pointer_y: float = center.y - radius - 12.0
	var pointer := PackedVector2Array([
		Vector2(center.x - 12.0, pointer_y - 8.0),
		Vector2(center.x + 12.0, pointer_y - 8.0),
		Vector2(center.x, pointer_y + 7.0),
	])
	draw_colored_polygon(pointer, line_color)
	draw_polyline(PackedVector2Array([pointer[0], pointer[1], pointer[2], pointer[0]]), Color("4b2617"), 2.0, true)

class_name CombatAtmosphereLayer
extends Control

var _accent: Color = VisualTheme.EMBER
var _boss: bool = false
var _time: float = 0.0
var _redraw_budget: float = 0.0


func configure(accent: Color, boss: bool) -> void:
	_accent = accent
	_boss = boss
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(not SettingsManager.reduce_motion)


func _process(delta: float) -> void:
	_time += delta
	_redraw_budget += delta
	if _redraw_budget >= 0.05:
		_redraw_budget = 0.0
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var haze := Color("6b4659")
	haze.a = 0.055 if not _boss else 0.085
	for index: int in 5:
		var x: float = size.x * (0.08 + float(index) * 0.22)
		var drift: float = 0.0 if SettingsManager.reduce_motion else sin(_time * 0.28 + index) * 7.0
		draw_circle(Vector2(x + drift, size.y * (0.24 + 0.035 * (index % 2))), size.x * (0.16 + index * 0.012), haze)
	var ember := _accent.lightened(0.18)
	ember.a = 0.42 if not _boss else 0.58
	for index: int in 11:
		var base_x: float = fmod(float(index * 173 + 61), 719.0) / 719.0
		var base_y: float = 0.18 + fmod(float(index * 97 + 29), 610.0) / 1000.0
		var rise: float = 0.0 if SettingsManager.reduce_motion else fmod(_time * (8.0 + index % 3) + index * 17.0, 44.0)
		var point := Vector2(size.x * base_x, size.y * base_y - rise)
		var radius: float = 1.4 + float(index % 3) * 0.65
		draw_circle(point, radius, ember)

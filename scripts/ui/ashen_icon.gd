class_name AshenIcon
extends Control

enum DisplaySize { SMALL, MEDIUM, LARGE, XLARGE }

const UNKNOWN: StringName = &"unknown"

var icon_id: StringName = UNKNOWN
var accent: Color = VisualTheme.TEXT_SECONDARY
var display_size: DisplaySize = DisplaySize.MEDIUM
var active: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_size()
	resized.connect(queue_redraw)


func configure(new_icon_id: StringName, new_accent: Color, new_size: DisplaySize = DisplaySize.MEDIUM, is_active: bool = true) -> void:
	icon_id = new_icon_id
	accent = new_accent
	display_size = new_size
	active = is_active
	_apply_size()
	queue_redraw()


func _apply_size() -> void:
	var side: float = 24.0
	match display_size:
		DisplaySize.SMALL:
			side = 20.0
		DisplaySize.LARGE:
			side = 40.0
		DisplaySize.XLARGE:
			side = 68.0
	custom_minimum_size = Vector2(side, side)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var color: Color = accent if active else VisualTheme.MUTED
	var line_width: float = maxf(1.6, minf(size.x, size.y) * 0.075)
	var resolved: StringName = _resolve_id(icon_id)
	match resolved:
		&"attack", &"weapon", &"ember_slash":
			_draw_blade(color, line_width, resolved == &"ember_slash")
		&"defense", &"armor", &"block", &"ashen_guard", &"guard":
			_draw_shield(color, line_width, resolved == &"ashen_guard" or resolved == &"guard")
		&"health", &"hp", &"heal", &"second_wind", &"low_health", &"regen":
			_draw_vital(color, line_width, resolved)
		&"weaken":
			_draw_weaken(color, line_width)
		&"armor_break":
			_draw_armor_break(color, line_width)
		&"ember", &"brasa", &"burn", &"energy_gain":
			_draw_flame(color, line_width, resolved == &"energy_gain")
		&"xp", &"level":
			_draw_progress(color, line_width, resolved == &"level")
		&"locked", &"lock":
			_draw_lock(color, line_width)
		&"equipped", &"check":
			_draw_check(color, line_width)
		&"wet", &"tide":
			_draw_drop(color, line_width)
		&"miasma":
			_draw_miasma(color, line_width)
		&"target", &"player":
			_draw_target(color, line_width, resolved == &"player")
		&"phase", &"route":
			_draw_phase(color, line_width)
		&"easy", &"medium", &"hard":
			_draw_difficulty(color, line_width, resolved)
		&"cooldown":
			_draw_cooldown(color, line_width)
		&"ash":
			_draw_ash(color)
		&"common", &"rare", &"epic":
			_draw_rarity(color, line_width, resolved)
		&"offense", &"defense_affinity", &"sustain":
			_draw_affinity(color, line_width, resolved)
		&"synergy":
			_draw_synergy(color, line_width)
		&"boon", &"skill", &"augment":
			_draw_rune(color, line_width, resolved == &"augment")
		&"elite", &"boss":
			_draw_rank(color, line_width, resolved == &"boss")
		&"treasure", &"loot":
			_draw_treasure(color, line_width)
		&"event":
			_draw_event(color, line_width)
		&"ashen_wastes", &"wastes", &"ember_marsh", &"marsh", &"biome":
			_draw_biome(color, line_width, resolved)
		&"combat", &"counter":
			_draw_combat(color, line_width, resolved == &"counter")
		&"death":
			_draw_death(color, line_width)
		_:
			_draw_unknown(color, line_width)


func _resolve_id(value: StringName) -> StringName:
	match value:
		&"burning_strike", &"relentless_flame", &"pyre_heart":
			return &"burn"
		&"ashen_bulwark", &"cinder_skin", &"reinforced_ash":
			return &"block"
		&"ember_blood", &"deep_breath", &"quick_recovery":
			return &"heal"
		&"last_ember":
			return &"low_health"
		&"ashen_reprisal", &"counter_guard":
			return &"counter"
		&"inferno_rhythm", &"ashen_vengeance", &"last_stand", &"phoenix_blood":
			return &"synergy"
		&"searing_edge", &"ember_efficiency", &"executioners_ember", &"stored_embers", &"ashen_renewal":
			return &"augment"
		&"ashen_bounty":
			return &"ash"
		&"spoils_of_the_warden":
			return &"loot"
		&"ember_cache":
			return &"ember"
		&"pyres_favor":
			return &"epic"
		_:
			return value


func _point(x: float, y: float) -> Vector2:
	return Vector2(size.x * x, size.y * y)


func _draw_blade(color: Color, width: float, ember_mark: bool) -> void:
	draw_polyline(PackedVector2Array([_point(0.22, 0.78), _point(0.7, 0.3), _point(0.82, 0.18), _point(0.76, 0.38), _point(0.3, 0.84)]), color, width, true)
	draw_line(_point(0.2, 0.65), _point(0.38, 0.83), color, width, true)
	if ember_mark:
		draw_circle(_point(0.72, 0.68), size.x * 0.075, color)


func _draw_shield(color: Color, width: float, rune: bool) -> void:
	var points: PackedVector2Array = PackedVector2Array([_point(0.5, 0.12), _point(0.82, 0.28), _point(0.75, 0.68), _point(0.5, 0.88), _point(0.25, 0.68), _point(0.18, 0.28), _point(0.5, 0.12)])
	draw_polyline(points, color, width, true)
	if rune:
		draw_line(_point(0.5, 0.3), _point(0.5, 0.68), color, width, true)
		draw_line(_point(0.36, 0.47), _point(0.64, 0.47), color, width, true)


func _draw_weaken(color: Color, width: float) -> void:
	draw_polyline(PackedVector2Array([_point(0.2, 0.28), _point(0.5, 0.62), _point(0.8, 0.28)]), color, width, true)
	draw_line(_point(0.5, 0.2), _point(0.5, 0.8), color, width, true)
	draw_polyline(PackedVector2Array([_point(0.35, 0.64), _point(0.5, 0.82), _point(0.65, 0.64)]), color, width, true)


func _draw_armor_break(color: Color, width: float) -> void:
	_draw_shield(color, width, false)
	draw_polyline(PackedVector2Array([_point(0.58, 0.22), _point(0.43, 0.46), _point(0.58, 0.58), _point(0.4, 0.82)]), color, width * 1.2, true)


func _draw_vital(color: Color, width: float, kind: StringName) -> void:
	draw_circle(_point(0.38, 0.42), size.x * 0.16, color, false, width, true)
	draw_circle(_point(0.62, 0.42), size.x * 0.16, color, false, width, true)
	draw_polyline(PackedVector2Array([_point(0.24, 0.48), _point(0.5, 0.82), _point(0.76, 0.48)]), color, width, true)
	if kind == &"heal" or kind == &"second_wind" or kind == &"regen":
		draw_line(_point(0.5, 0.34), _point(0.5, 0.64), color, width, true)
		draw_line(_point(0.36, 0.49), _point(0.64, 0.49), color, width, true)
	elif kind == &"low_health":
		draw_polyline(PackedVector2Array([_point(0.5, 0.32), _point(0.43, 0.49), _point(0.56, 0.58), _point(0.48, 0.75)]), color, width, true)


func _draw_flame(color: Color, width: float, plus: bool) -> void:
	var flame: PackedVector2Array = PackedVector2Array([_point(0.5, 0.1), _point(0.72, 0.4), _point(0.68, 0.75), _point(0.5, 0.9), _point(0.3, 0.77), _point(0.27, 0.48), _point(0.42, 0.28), _point(0.5, 0.1)])
	draw_polyline(flame, color, width, true)
	draw_polyline(PackedVector2Array([_point(0.5, 0.42), _point(0.61, 0.62), _point(0.5, 0.78), _point(0.4, 0.63), _point(0.5, 0.42)]), color, width, true)
	if plus:
		draw_line(_point(0.7, 0.2), _point(0.9, 0.2), color, width, true)
		draw_line(_point(0.8, 0.1), _point(0.8, 0.3), color, width, true)


func _draw_cooldown(color: Color, width: float) -> void:
	draw_arc(_point(0.5, 0.52), size.x * 0.32, -PI * 0.35, PI * 1.55, 24, color, width, true)
	draw_polyline(PackedVector2Array([_point(0.22, 0.3), _point(0.2, 0.55), _point(0.4, 0.43)]), color, width, true)


func _draw_progress(color: Color, width: float, level_mark: bool) -> void:
	draw_polyline(PackedVector2Array([_point(0.2, 0.72), _point(0.38, 0.52), _point(0.5, 0.62), _point(0.8, 0.26)]), color, width, true)
	if level_mark:
		draw_line(_point(0.5, 0.16), _point(0.5, 0.42), color, width, true)
		draw_polyline(PackedVector2Array([_point(0.38, 0.28), _point(0.5, 0.14), _point(0.62, 0.28)]), color, width, true)


func _draw_lock(color: Color, width: float) -> void:
	draw_rect(Rect2(_point(0.24, 0.44), Vector2(size.x * 0.52, size.y * 0.4)), color, false, width)
	draw_arc(_point(0.5, 0.44), size.x * 0.2, PI, TAU, 18, color, width, true)
	draw_circle(_point(0.5, 0.62), size.x * 0.055, color)


func _draw_check(color: Color, width: float) -> void:
	draw_arc(_point(0.5, 0.5), size.x * 0.34, 0.0, TAU, 24, color, width, true)
	draw_polyline(PackedVector2Array([_point(0.27, 0.51), _point(0.44, 0.68), _point(0.75, 0.32)]), color, width * 1.2, true)


func _draw_drop(color: Color, width: float) -> void:
	draw_polyline(PackedVector2Array([_point(0.5, 0.12), _point(0.75, 0.55), _point(0.66, 0.8), _point(0.5, 0.9), _point(0.34, 0.8), _point(0.25, 0.55), _point(0.5, 0.12)]), color, width, true)


func _draw_miasma(color: Color, width: float) -> void:
	draw_arc(_point(0.38, 0.43), size.x * 0.21, PI * 0.2, PI * 1.8, 16, color, width, true)
	draw_arc(_point(0.62, 0.58), size.x * 0.22, -PI * 0.8, PI * 0.8, 16, color, width, true)
	draw_circle(_point(0.25, 0.72), size.x * 0.05, color)


func _draw_target(color: Color, width: float, player_mark: bool) -> void:
	draw_arc(_point(0.5, 0.5), size.x * 0.3, 0.0, TAU, 24, color, width, true)
	draw_circle(_point(0.5, 0.5), size.x * 0.065, color)
	if player_mark:
		draw_line(_point(0.5, 0.08), _point(0.5, 0.24), color, width, true)


func _draw_phase(color: Color, width: float) -> void:
	for index: int in 3:
		var x: float = 0.24 + float(index) * 0.26
		if index == 1:
			draw_circle(_point(x, 0.5), size.x * 0.085, color)
		else:
			draw_circle(_point(x, 0.5), size.x * 0.085, color, false, width, true)
		if index < 2:
			draw_line(_point(x + 0.09, 0.5), _point(x + 0.17, 0.5), color, width, true)


func _draw_difficulty(color: Color, width: float, difficulty: StringName) -> void:
	var count: int = 1 if difficulty == &"easy" else (2 if difficulty == &"medium" else 3)
	for index: int in count:
		var x: float = 0.28 + float(index) * 0.22
		draw_line(_point(x, 0.72), _point(x, 0.62 - float(index) * 0.16), color, width * 1.5, true)


func _draw_ash(color: Color) -> void:
	var ash_points: Array[Vector2] = [_point(0.28, 0.64), _point(0.48, 0.38), _point(0.7, 0.66), _point(0.58, 0.78)]
	for point: Vector2 in ash_points:
		draw_circle(point, size.x * 0.075, color)


func _draw_rarity(color: Color, width: float, rarity: StringName) -> void:
	var count: int = 1 if rarity == &"common" else (2 if rarity == &"rare" else 3)
	for index: int in count:
		var center_x: float = 0.5 + (float(index) - float(count - 1) * 0.5) * 0.25
		draw_polyline(PackedVector2Array([_point(center_x, 0.22), _point(center_x + 0.12, 0.5), _point(center_x, 0.78), _point(center_x - 0.12, 0.5), _point(center_x, 0.22)]), color, width, true)


func _draw_affinity(color: Color, width: float, affinity: StringName) -> void:
	if affinity == &"offense":
		_draw_blade(color, width, false)
	elif affinity == &"defense_affinity":
		_draw_shield(color, width, false)
	else:
		draw_arc(_point(0.5, 0.5), size.x * 0.3, 0.0, TAU, 24, color, width, true)
		draw_circle(_point(0.5, 0.5), size.x * 0.08, color)


func _draw_synergy(color: Color, width: float) -> void:
	draw_arc(_point(0.38, 0.5), size.x * 0.23, 0.0, TAU, 20, color, width, true)
	draw_arc(_point(0.62, 0.5), size.x * 0.23, 0.0, TAU, 20, color, width, true)
	draw_circle(_point(0.5, 0.5), size.x * 0.055, color)


func _draw_rune(color: Color, width: float, augment_mark: bool) -> void:
	draw_polyline(PackedVector2Array([_point(0.5, 0.12), _point(0.82, 0.5), _point(0.5, 0.88), _point(0.18, 0.5), _point(0.5, 0.12)]), color, width, true)
	draw_circle(_point(0.5, 0.5), size.x * 0.09, color, false, width, true)
	if augment_mark:
		draw_line(_point(0.68, 0.72), _point(0.9, 0.72), color, width, true)
		draw_line(_point(0.79, 0.61), _point(0.79, 0.83), color, width, true)


func _draw_rank(color: Color, width: float, boss_mark: bool) -> void:
	var points: PackedVector2Array = PackedVector2Array([_point(0.18, 0.7), _point(0.25, 0.3), _point(0.45, 0.55), _point(0.5, 0.2), _point(0.55, 0.55), _point(0.75, 0.3), _point(0.82, 0.7), _point(0.18, 0.7)])
	draw_polyline(points, color, width, true)
	if boss_mark:
		draw_line(_point(0.25, 0.82), _point(0.75, 0.82), color, width * 1.4, true)


func _draw_treasure(color: Color, width: float) -> void:
	draw_rect(Rect2(_point(0.2, 0.42), Vector2(size.x * 0.6, size.y * 0.4)), color, false, width)
	draw_arc(_point(0.5, 0.43), size.x * 0.3, PI, TAU, 16, color, width, true)
	draw_rect(Rect2(_point(0.46, 0.55), Vector2(size.x * 0.08, size.y * 0.15)), color, true)


func _draw_event(color: Color, width: float) -> void:
	draw_polyline(PackedVector2Array([_point(0.32, 0.32), _point(0.5, 0.16), _point(0.7, 0.32), _point(0.54, 0.5), _point(0.5, 0.66)]), color, width, true)
	draw_circle(_point(0.5, 0.82), size.x * 0.06, color)


func _draw_biome(color: Color, width: float, kind: StringName) -> void:
	if kind == &"ember_marsh" or kind == &"marsh":
		draw_polyline(PackedVector2Array([_point(0.18, 0.72), _point(0.34, 0.62), _point(0.5, 0.72), _point(0.66, 0.62), _point(0.82, 0.72)]), color, width, true)
		for x: float in [0.3, 0.5, 0.7]:
			draw_line(_point(x, 0.62), _point(x + 0.04, 0.24), color, width, true)
			draw_line(_point(x + 0.035, 0.39), _point(x + 0.14, 0.31), color, width, true)
	else:
		draw_polyline(PackedVector2Array([_point(0.12, 0.76), _point(0.35, 0.35), _point(0.5, 0.58), _point(0.67, 0.24), _point(0.9, 0.76)]), color, width, true)
		draw_line(_point(0.2, 0.8), _point(0.82, 0.8), color, width, true)
		draw_circle(_point(0.72, 0.19), size.x * 0.055, color)


func _draw_combat(color: Color, width: float, counter_mark: bool) -> void:
	draw_line(_point(0.22, 0.22), _point(0.78, 0.78), color, width, true)
	draw_line(_point(0.78, 0.22), _point(0.22, 0.78), color, width, true)
	if counter_mark:
		draw_arc(_point(0.5, 0.5), size.x * 0.34, PI * 0.1, PI * 1.25, 14, color, width, true)


func _draw_death(color: Color, width: float) -> void:
	draw_polyline(PackedVector2Array([_point(0.5, 0.12), _point(0.4, 0.38), _point(0.58, 0.52), _point(0.42, 0.7), _point(0.5, 0.88)]), color, width, true)
	draw_line(_point(0.24, 0.76), _point(0.76, 0.24), color, width, true)


func _draw_unknown(color: Color, width: float) -> void:
	draw_polyline(PackedVector2Array([_point(0.5, 0.14), _point(0.82, 0.5), _point(0.5, 0.86), _point(0.18, 0.5), _point(0.5, 0.14)]), color, width, true)
	draw_circle(_point(0.5, 0.5), size.x * 0.07, color)

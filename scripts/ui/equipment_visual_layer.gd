class_name EquipmentVisualLayer
extends Control

enum LayerRole {
	BACK,
	ARMOR,
	WEAPON,
}

var _role: LayerRole = LayerRole.BACK
var _visual: EquipmentVisualData
var _rarity: EquipmentData.Rarity = EquipmentData.Rarity.COMMON
var _animation_name: StringName = &"idle"
var _animation_frame: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	resized.connect(queue_redraw)


func configure(role: LayerRole, visual: EquipmentVisualData, rarity: EquipmentData.Rarity) -> void:
	_role = role
	_visual = visual
	_rarity = rarity
	var base_z_index: int = 0 if role == LayerRole.BACK else (2 if role == LayerRole.ARMOR else 3)
	z_index = base_z_index + (_visual.attachment_z_index if _visual != null else 0)
	visible = _visual != null and _visual.display_mode != EquipmentVisualData.DisplayMode.NONE
	queue_redraw()


func set_character_state(animation_name: StringName) -> void:
	_animation_name = animation_name
	visible = _visual != null and _visual.display_mode != EquipmentVisualData.DisplayMode.NONE and _visual.is_visible_for(animation_name)
	queue_redraw()


func set_frame_context(animation_name: StringName, frame_index: int) -> void:
	_animation_name = animation_name
	_animation_frame = frame_index
	if _visual != null and not _visual.frame_sync_profile_id.is_empty():
		queue_redraw()


func _draw() -> void:
	if _visual == null or not visible or size.x <= 0.0 or size.y <= 0.0:
		return
	var basis: float = minf(size.x, size.y)
	var origin: Vector2 = Vector2(size.x * _visual.attachment_anchor.x, size.y * _visual.attachment_anchor.y)
	origin += _visual.attachment_offset_ratio * basis
	var unit: float = basis * 0.075 * _visual.attachment_scale
	var state_alpha: float = 0.62 if _animation_name == &"death" else 1.0
	draw_set_transform(origin, deg_to_rad(_visual.attachment_rotation_degrees), Vector2.ONE)
	if _visual.display_mode == EquipmentVisualData.DisplayMode.ATTACHMENT and _visual.attachment_texture != null:
		_draw_attachment_texture(unit, state_alpha)
	else:
		_draw_procedural(unit, state_alpha)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_attachment_texture(unit: float, alpha: float) -> void:
	var texture_size: Vector2 = _visual.attachment_texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var target_width: float = unit * 4.0
	var target_scale: float = target_width / texture_size.x
	var target_size: Vector2 = texture_size * target_scale
	var tint: Color = Color.WHITE
	tint.a = alpha
	draw_texture_rect(_visual.attachment_texture, Rect2(-target_size * 0.5, target_size), false, tint)


func _draw_procedural(unit: float, alpha: float) -> void:
	var primary: Color = _visual.accent
	var secondary: Color = _visual.secondary_accent
	var style: EquipmentVisualData.ProceduralStyle = _visual.procedural_style
	if _visual.display_mode != EquipmentVisualData.DisplayMode.ACCENT and _visual.fallback_style != EquipmentVisualData.ProceduralStyle.NONE:
		style = _visual.fallback_style
	primary.a *= alpha
	secondary.a *= alpha
	var width: float = 2.0 + float(_rarity) * 0.45
	if _role == LayerRole.BACK:
		_draw_armor_back(unit, primary, secondary, width, style)
	elif _role == LayerRole.ARMOR:
		_draw_armor_front(unit, primary, secondary, width, style)
	else:
		_draw_weapon(unit, primary, secondary, width, style)
	if _role != LayerRole.BACK:
		_draw_rarity_marks(unit, primary, width)


func _draw_weapon(unit: float, primary: Color, secondary: Color, width: float, style: EquipmentVisualData.ProceduralStyle) -> void:
	if _visual.slot != EquipmentData.Slot.WEAPON:
		return
	match style:
		EquipmentVisualData.ProceduralStyle.ASHEN_BLADE:
			draw_line(Vector2(-unit * 0.9, unit * 1.15), Vector2(unit * 0.85, -unit * 1.25), secondary, width + 2.0, true)
			draw_line(Vector2(-unit * 0.82, unit), Vector2(unit * 0.82, -unit * 1.22), primary, width, true)
			draw_circle(Vector2(-unit, unit * 1.28), unit * 0.18, primary)
		EquipmentVisualData.ProceduralStyle.CINDER_KNIFE:
			var knife: PackedVector2Array = PackedVector2Array([
				Vector2(-unit * 0.75, unit * 0.65), Vector2(unit * 0.9, -unit * 0.55),
				Vector2(unit * 0.42, unit * 0.18), Vector2(-unit * 0.75, unit * 0.65),
			])
			draw_polyline(knife, primary, width, true)
			draw_line(Vector2(-unit * 0.95, unit * 0.82), Vector2(-unit * 0.52, unit * 0.42), secondary, width + 1.0, true)
		EquipmentVisualData.ProceduralStyle.EMBER_FANG:
			var fang: PackedVector2Array = PackedVector2Array([
				Vector2(-unit * 0.85, unit * 1.0), Vector2(-unit * 0.1, unit * 0.2),
				Vector2(unit * 0.85, -unit * 0.82), Vector2(unit * 0.55, -unit * 1.2),
			])
			draw_polyline(fang, secondary, width + 2.0, true)
			draw_polyline(fang, primary, width, true)
			draw_circle(Vector2(unit * 0.18, -unit * 0.12), unit * 0.16, primary)
		EquipmentVisualData.ProceduralStyle.RUNIC_EDGE:
			draw_line(Vector2(-unit, unit * 1.15), Vector2(unit * 0.9, -unit * 1.15), secondary, width + 2.0, true)
			draw_line(Vector2(-unit * 0.9, unit), Vector2(unit * 0.82, -unit), primary, width, true)
			_draw_diamond(Vector2.ZERO, unit * 0.34, primary, width)
		EquipmentVisualData.ProceduralStyle.WARDENS_EDGE:
			draw_line(Vector2(-unit, unit * 1.25), Vector2(unit * 0.78, -unit * 1.28), secondary, width + 4.0, true)
			draw_line(Vector2(-unit * 0.88, unit * 1.12), Vector2(unit * 0.72, -unit * 1.2), primary, width + 1.0, true)
			draw_line(Vector2(-unit * 1.15, unit * 0.75), Vector2(-unit * 0.42, unit * 1.2), primary, width, true)
		EquipmentVisualData.ProceduralStyle.BLOOD_CLEAVER:
			draw_line(Vector2(-unit * 0.75, unit * 1.3), Vector2(unit * 0.35, -unit * 0.6), secondary, width + 2.0, true)
			var head: PackedVector2Array = PackedVector2Array([
				Vector2(unit * 0.18, -unit * 0.45), Vector2(unit * 0.95, -unit * 1.15),
				Vector2(unit * 1.25, -unit * 0.35), Vector2(unit * 0.48, unit * 0.05),
			])
			draw_colored_polygon(head, secondary)
			draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[3], head[0]]), primary, width, true)


func _draw_armor_back(unit: float, primary: Color, secondary: Color, width: float, style: EquipmentVisualData.ProceduralStyle) -> void:
	if _visual.slot != EquipmentData.Slot.CHEST:
		return
	var glow: Color = secondary
	glow.a *= 0.22
	match style:
		EquipmentVisualData.ProceduralStyle.WORN_ASHMAIL:
			draw_arc(Vector2(0.0, unit * 0.25), unit * 1.55, PI * 1.08, PI * 1.92, 20, glow, width, true)
		EquipmentVisualData.ProceduralStyle.CINDER_CARAPACE:
			draw_arc(Vector2.ZERO, unit * 1.65, PI * 1.12, PI * 1.88, 16, glow, width + 2.0, true)
		EquipmentVisualData.ProceduralStyle.EMBERGUARD_ARMOR:
			draw_circle(Vector2.ZERO, unit * 1.5, glow)
		EquipmentVisualData.ProceduralStyle.MIRE_VEST:
			draw_arc(Vector2(-unit * 0.4, 0.0), unit * 1.5, -PI * 0.55, PI * 0.55, 18, glow, width, true)
			draw_circle(Vector2(-unit * 1.25, unit * 0.38), unit * 0.16, primary)
		EquipmentVisualData.ProceduralStyle.WARDEN_PLATE:
			draw_arc(Vector2.ZERO, unit * 1.75, PI * 1.1, PI * 1.9, 20, glow, width + 3.0, true)
		EquipmentVisualData.ProceduralStyle.LAST_GUARD:
			draw_arc(Vector2.ZERO, unit * 1.55, PI * 1.14, PI * 1.48, 10, glow, width + 1.0, true)
			draw_arc(Vector2.ZERO, unit * 1.55, PI * 1.58, PI * 1.86, 10, glow, width + 1.0, true)


func _draw_armor_front(unit: float, primary: Color, secondary: Color, width: float, style: EquipmentVisualData.ProceduralStyle) -> void:
	if _visual.slot != EquipmentData.Slot.CHEST:
		return
	match style:
		EquipmentVisualData.ProceduralStyle.WORN_ASHMAIL:
			_draw_shoulders(unit, primary, width, 0.72)
			for link_index: int in 3:
				draw_arc(Vector2((float(link_index) - 1.0) * unit * 0.38, unit * 0.42), unit * 0.22, 0.0, TAU, 10, secondary, width, true)
		EquipmentVisualData.ProceduralStyle.CINDER_CARAPACE:
			_draw_shoulders(unit, secondary, width + 1.0, 0.95)
			for plate_index: int in 3:
				var plate_y: float = float(plate_index) * unit * 0.38
				draw_line(Vector2(-unit * (0.72 - plate_index * 0.1), plate_y), Vector2(unit * (0.72 - plate_index * 0.1), plate_y), primary, width + 1.0, true)
		EquipmentVisualData.ProceduralStyle.EMBERGUARD_ARMOR:
			_draw_shoulders(unit, primary, width + 1.0, 0.9)
			_draw_diamond(Vector2(0.0, unit * 0.34), unit * 0.42, primary, width)
			draw_line(Vector2(0.0, -unit * 0.1), Vector2(0.0, unit * 0.82), secondary, width + 1.0, true)
		EquipmentVisualData.ProceduralStyle.MIRE_VEST:
			draw_arc(Vector2(-unit * 0.35, unit * 0.2), unit * 0.92, -PI * 0.6, PI * 0.62, 16, primary, width, true)
			draw_arc(Vector2(unit * 0.32, unit * 0.28), unit * 0.72, PI * 0.45, PI * 1.5, 14, secondary, width, true)
			draw_circle(Vector2(unit * 0.32, unit * 0.18), unit * 0.18, primary)
		EquipmentVisualData.ProceduralStyle.WARDEN_PLATE:
			_draw_shoulders(unit, primary, width + 2.0, 1.05)
			var shield: PackedVector2Array = PackedVector2Array([
				Vector2(0.0, -unit * 0.45), Vector2(unit * 0.62, -unit * 0.08),
				Vector2(unit * 0.42, unit * 0.72), Vector2(0.0, unit * 1.05),
				Vector2(-unit * 0.42, unit * 0.72), Vector2(-unit * 0.62, -unit * 0.08),
			])
			draw_polyline(PackedVector2Array([shield[0], shield[1], shield[2], shield[3], shield[4], shield[5], shield[0]]), secondary, width + 1.0, true)
			draw_line(Vector2(0.0, -unit * 0.25), Vector2(0.0, unit * 0.72), primary, width, true)
		EquipmentVisualData.ProceduralStyle.LAST_GUARD:
			_draw_shoulders(unit, secondary, width + 1.0, 0.86)
			_draw_diamond(Vector2(0.0, unit * 0.24), unit * 0.52, primary, width)
			draw_line(Vector2(-unit * 0.28, -unit * 0.05), Vector2(unit * 0.18, unit * 0.28), secondary, width, true)
			draw_line(Vector2(unit * 0.18, unit * 0.28), Vector2(-unit * 0.08, unit * 0.72), secondary, width, true)


func _draw_shoulders(unit: float, color: Color, width: float, spread: float) -> void:
	draw_arc(Vector2(-unit * spread, 0.0), unit * 0.52, PI, TAU, 12, color, width, true)
	draw_arc(Vector2(unit * spread, 0.0), unit * 0.52, PI, TAU, 12, color, width, true)


func _draw_diamond(center: Vector2, radius: float, color: Color, width: float) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -radius), center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius), center + Vector2(-radius, 0.0),
		center + Vector2(0.0, -radius),
	])
	draw_polyline(points, color, width, true)


func _draw_rarity_marks(unit: float, color: Color, width: float) -> void:
	if _rarity == EquipmentData.Rarity.COMMON:
		return
	var mark_color: Color = VisualTheme.rarity_color(_rarity)
	mark_color.a = color.a * 0.58
	var mark_count: int = 1 if _rarity == EquipmentData.Rarity.RARE else 2
	for mark_index: int in mark_count:
		var mark_x: float = (float(mark_index) - float(mark_count - 1) * 0.5) * unit * 0.45
		draw_line(Vector2(mark_x - unit * 0.12, unit * 1.42), Vector2(mark_x + unit * 0.12, unit * 1.18), mark_color, width, true)

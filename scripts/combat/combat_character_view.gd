class_name CombatCharacterView
extends Control

const IDLE: StringName = &"idle"
const ATTACK: StringName = &"attack"
const BASIC_ATTACK: StringName = &"basic_attack"
const EMBER_SLASH: StringName = &"ember_slash"
const GUARD: StringName = &"guard"
const SECOND_WIND: StringName = &"second_wind"
const HIT: StringName = &"hit"
const DEATH: StringName = &"death"

# El fondo de combate es Color(0.035, 0.025, 0.03, 1) (ver combat.tscn ·
# Background). El body del fallback debe quedar por encima de ese valor para
# no fundirse con la escena cuando no hay arte real cargada.
const FALLBACK_BODY_COLOR: Color = Color(0.115, 0.095, 0.105, 0.94)
const FALLBACK_ACCENT_MIN_VALUE: float = 0.42

@onready var static_art: TextureRect = $StaticArt
@onready var fallback_label: Label = $FallbackLabel

var _animated_sprite: AnimatedSprite2D
var _visual: CharacterVisualData
var _animated_mode: bool = false
var _dead: bool = false
var _fallback_presence_enabled: bool = false
var _fallback_kind: StringName = &"normal"
var _fallback_accent: Color = VisualTheme.DANGER
var _ambient_accent: Color = VisualTheme.EMBER_DARK
var _equipment_visual_root: Control
var _equipment_back_layer: EquipmentVisualLayer
var _equipment_armor_layer: EquipmentVisualLayer
var _equipment_weapon_layer: EquipmentVisualLayer
var _current_animation_name: StringName = IDLE
var _reticle: CombatTargetReticle
var _static_tween: Tween
var _static_action_active: bool = false
var _idle_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_ensure_animated_sprite()
	_ensure_reticle()
	resized.connect(_refresh_layout)
	resized.connect(queue_redraw)
	set_process(true)


func setup_visual(visual: CharacterVisualData, fallback_text: String) -> void:
	_visual = visual
	_dead = false
	_ensure_animated_sprite()
	var frames: SpriteFrames = visual.get_sprite_frames() if visual != null else null
	_animated_mode = frames != null and _has_usable_animation(frames, IDLE)
	_animated_sprite.sprite_frames = frames
	_animated_sprite.flip_h = visual.flip_h if visual != null else false
	_animated_sprite.visible = _animated_mode
	var texture: Texture2D = visual.get_combat_texture() if visual != null else null
	static_art.texture = texture
	static_art.visible = not _animated_mode and texture != null
	fallback_label.visible = not _animated_mode and texture == null
	fallback_label.text = fallback_text
	_refresh_layout()
	queue_redraw()
	play_idle()


func setup_equipment_visuals(weapon_item: EquipmentData, armor_item: EquipmentData) -> void:
	_ensure_equipment_layers()
	if _visual != null and not _visual.allow_equipment_overlays:
		_equipment_visual_root.hide()
		return
	_equipment_visual_root.show()
	var weapon_visual: EquipmentVisualData = EquipmentVisualCatalog.get_for_item(weapon_item)
	var armor_visual: EquipmentVisualData = EquipmentVisualCatalog.get_for_item(armor_item)
	var weapon_rarity: EquipmentData.Rarity = weapon_item.rarity if weapon_item != null else EquipmentData.Rarity.COMMON
	var armor_rarity: EquipmentData.Rarity = armor_item.rarity if armor_item != null else EquipmentData.Rarity.COMMON
	_equipment_back_layer.configure(EquipmentVisualLayer.LayerRole.BACK, armor_visual, armor_rarity)
	_equipment_armor_layer.configure(EquipmentVisualLayer.LayerRole.ARMOR, armor_visual, armor_rarity)
	_equipment_weapon_layer.configure(EquipmentVisualLayer.LayerRole.WEAPON, weapon_visual, weapon_rarity)
	_set_equipment_state(_current_animation_name)
	_refresh_equipment_layout()


func configure_fallback_presence(kind: StringName, accent: Color, ambient: Color) -> void:
	_fallback_presence_enabled = true
	_fallback_kind = kind
	_fallback_accent = accent
	_ambient_accent = ambient
	# La silueta geométrica ya comunica presencia; la inicial textual hacía que
	# enemigos sin ilustración pareciesen placeholders técnicos.
	fallback_label.modulate = Color.TRANSPARENT
	queue_redraw()


func is_animated() -> bool:
	return _animated_mode


func has_animation(animation_name: StringName) -> bool:
	return _animated_mode and _has_usable_animation(_animated_sprite.sprite_frames, animation_name)


func get_attack_impact_ratio() -> float:
	return _visual.attack_impact_ratio if _visual != null else 0.55


func get_animation_contact_ratio(animation_name: StringName = ATTACK) -> float:
	return _visual.get_animation_contact_ratio(animation_name, get_attack_impact_ratio()) if _visual != null else 0.55


func set_targeted(active: bool) -> void:
	_ensure_reticle()
	_reticle.set_targeted(active, VisualTheme.EMBER_BRIGHT)


func play_idle() -> void:
	if _dead:
		return
	_set_equipment_state(IDLE)
	if not _animated_mode:
		return
	if SettingsManager.reduce_motion and _visual != null and _visual.freeze_idle_with_reduce_motion:
		_animated_sprite.animation = IDLE
		_animated_sprite.frame = 0
		_animated_sprite.stop()
		return
	_animated_sprite.speed_scale = 1.0
	_animated_sprite.play(IDLE)


func play_attack(maximum_duration: float) -> void:
	if has_animation(BASIC_ATTACK):
		_play_action(BASIC_ATTACK, maximum_duration)
	elif not has_animation(ATTACK):
		_play_static_action(ATTACK)
	else:
		_play_action(ATTACK, maximum_duration)


func play_named_animation(animation_name: StringName, maximum_duration: float, fallback_name: StringName = ATTACK) -> void:
	if has_animation(animation_name):
		_play_action(animation_name, maximum_duration)
	elif has_animation(fallback_name):
		_play_action(fallback_name, maximum_duration)
	else:
		_play_static_action(animation_name)


func play_hit(maximum_duration: float) -> void:
	if not has_animation(HIT):
		_play_static_action(HIT)
	_play_action(HIT, maximum_duration)


func play_death(maximum_duration: float) -> void:
	_dead = true
	_set_equipment_state(DEATH)
	if not has_animation(DEATH):
		_play_static_action(DEATH)
		return
	_play_animation_with_budget(DEATH, maximum_duration)


func _play_action(animation_name: StringName, maximum_duration: float) -> void:
	if _dead:
		return
	_set_equipment_state(animation_name)
	if not has_animation(animation_name):
		return
	_play_animation_with_budget(animation_name, maximum_duration)


func _play_animation_with_budget(animation_name: StringName, maximum_duration: float) -> void:
	var original_duration: float = _visual.get_animation_duration(animation_name)
	var playback_speed: float = 1.0
	if maximum_duration > 0.0 and original_duration > maximum_duration:
		playback_speed = original_duration / maximum_duration
	_animated_sprite.speed_scale = playback_speed
	_animated_sprite.play(animation_name)
	_refresh_animated_scale()


func _refresh_layout() -> void:
	if not is_node_ready():
		return
	var visual_scale: float = _visual.combat_scale if _visual != null else 1.0
	var visual_offset: Vector2 = _visual.combat_offset if _visual != null else Vector2.ZERO
	static_art.pivot_offset = static_art.size * 0.5
	static_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	static_art.scale = Vector2.ONE * visual_scale
	static_art.position = visual_offset
	fallback_label.pivot_offset = fallback_label.size * 0.5
	fallback_label.scale = Vector2.ONE * visual_scale
	fallback_label.position = visual_offset
	_refresh_equipment_layout()
	if not _animated_mode:
		return
	var frame_texture: Texture2D = _animated_sprite.sprite_frames.get_frame_texture(IDLE, 0)
	var fit_scale: float = 1.0
	if frame_texture != null:
		var texture_size: Vector2 = frame_texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			fit_scale = minf(size.x / texture_size.x, size.y / texture_size.y)
	_animated_sprite.position = size * 0.5 + visual_offset
	_animated_sprite.scale = Vector2.ONE * fit_scale * visual_scale


func _process(delta: float) -> void:
	if _animated_mode or _dead or _static_action_active or static_art == null or not static_art.visible:
		return
	var base_scale: float = _visual.combat_scale if _visual != null else 1.0
	if SettingsManager.reduce_motion:
		static_art.scale = Vector2.ONE * base_scale
		return
	_idle_time += delta
	var breath: float = sin(_idle_time * 2.4) * 0.012
	static_art.scale = Vector2(base_scale * (1.0 - breath * 0.35), base_scale * (1.0 + breath))


func _play_static_action(animation_name: StringName) -> void:
	if static_art == null or not static_art.visible:
		return
	if is_instance_valid(_static_tween):
		_static_tween.kill()
	var base_scale: float = _visual.combat_scale if _visual != null else 1.0
	var base_offset: Vector2 = _visual.combat_offset if _visual != null else Vector2.ZERO
	static_art.pivot_offset = static_art.size * 0.5
	_static_action_active = true
	if SettingsManager.reduce_motion:
		static_art.scale = Vector2.ONE * base_scale
		static_art.position = base_offset
		static_art.rotation = 0.0
		_static_action_active = false
		return
	_static_tween = create_tween()
	match animation_name:
		ATTACK:
			static_art.scale = Vector2(base_scale * 0.96, base_scale * 1.035)
			static_art.rotation = -0.025
			_static_tween.tween_property(static_art, "scale", Vector2(base_scale * 1.045, base_scale * 0.975), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		HIT:
			static_art.scale = Vector2(base_scale * 1.06, base_scale * 0.93)
			static_art.rotation = 0.035
			_static_tween.tween_property(static_art, "scale", Vector2.ONE * base_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		DEATH:
			_static_tween.set_parallel(true)
			_static_tween.tween_property(static_art, "rotation", 0.11 if _fallback_kind != &"player" else -0.11, 0.32)
			_static_tween.tween_property(static_art, "scale", Vector2(base_scale * 1.04, base_scale * 0.82), 0.32)
			return
	_static_tween.set_parallel(true)
	_static_tween.tween_property(static_art, "rotation", 0.0, 0.14)
	_static_tween.tween_property(static_art, "position", base_offset, 0.14)
	_static_tween.chain().tween_callback(func() -> void: _static_action_active = false)


func _draw() -> void:
	if not is_node_ready():
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.5)
	var shadow_ratio: float = 0.32 if _fallback_kind == &"boss" else (0.26 if _fallback_kind == &"elite" else 0.23)
	_draw_fallback_shadow(Vector2(center.x, size.y * 0.84), Vector2(size.x * shadow_ratio, size.y * 0.045))
	if not _fallback_presence_enabled or not fallback_label.visible:
		return
	if _fallback_kind == &"companion":
		_draw_companion_fallback(center)
		return
	var mass: float = 0.13
	var top_ratio: float = 0.25
	match _fallback_kind:
		&"boss":
			mass = 0.32
			top_ratio = 0.13
		&"elite":
			mass = 0.23
			top_ratio = 0.19
		&"player":
			mass = 0.2
			top_ratio = 0.2
	var readable_accent: Color = _presentable_accent(_fallback_accent)
	var halo: Color = _ambient_accent
	halo.a = 0.16 if _fallback_kind == &"normal" else (0.18 if _fallback_kind == &"elite" else 0.24)
	var halo_ratio: float = 0.19
	if _fallback_kind == &"elite":
		halo_ratio = 0.26
	elif _fallback_kind == &"boss":
		halo_ratio = 0.36
	draw_circle(center, minf(size.x, size.y) * halo_ratio, halo)
	var silhouette: PackedVector2Array = _fallback_silhouette(top_ratio, mass)
	draw_colored_polygon(silhouette, FALLBACK_BODY_COLOR)
	var outline: Color = readable_accent
	outline.a = 0.78
	var outline_points: PackedVector2Array = silhouette.duplicate()
	outline_points.append(silhouette[0])
	draw_polyline(outline_points, outline, 3.4 if _fallback_kind != &"boss" else 5.4, true)
	var rune_center: Vector2 = Vector2(center.x, size.y * 0.49)
	draw_circle(rune_center, minf(size.x, size.y) * 0.075, Color(0.02, 0.015, 0.02, 0.94))
	draw_arc(rune_center, minf(size.x, size.y) * 0.06, 0.0, TAU, 20, readable_accent, 3.0, true)
	draw_line(rune_center + Vector2(0.0, -12.0), rune_center + Vector2(0.0, 12.0), readable_accent, 2.0, true)
	if _fallback_kind == &"elite" or _fallback_kind == &"boss":
		_draw_rank_mark(center, top_ratio, readable_accent)


func _draw_companion_fallback(center: Vector2) -> void:
	var halo: Color = _ambient_accent
	halo.a = 0.16
	draw_circle(Vector2(center.x, size.y * 0.56), minf(size.x, size.y) * 0.3, halo)
	var silhouette: PackedVector2Array = PackedVector2Array([
		Vector2(size.x * 0.17, size.y * 0.62),
		Vector2(size.x * 0.28, size.y * 0.43),
		Vector2(size.x * 0.43, size.y * 0.38),
		Vector2(size.x * 0.58, size.y * 0.46),
		Vector2(size.x * 0.76, size.y * 0.42),
		Vector2(size.x * 0.86, size.y * 0.54),
		Vector2(size.x * 0.74, size.y * 0.67),
		Vector2(size.x * 0.66, size.y * 0.82),
		Vector2(size.x * 0.54, size.y * 0.68),
		Vector2(size.x * 0.34, size.y * 0.7),
		Vector2(size.x * 0.25, size.y * 0.83),
	])
	draw_colored_polygon(silhouette, Color(0.035, 0.022, 0.025, 0.97))
	var outline: Color = _fallback_accent
	outline.a = 0.78
	var outline_points: PackedVector2Array = silhouette.duplicate()
	outline_points.append(silhouette[0])
	draw_polyline(outline_points, outline, 3.0, true)
	var eye_position: Vector2 = Vector2(size.x * 0.76, size.y * 0.51)
	draw_circle(eye_position, maxf(2.0, minf(size.x, size.y) * 0.018), _fallback_accent)
	draw_arc(Vector2(size.x * 0.49, size.y * 0.55), minf(size.x, size.y) * 0.075, -0.7, 2.4, 12, _fallback_accent, 2.0, true)


func _fallback_silhouette(top_ratio: float, mass: float) -> PackedVector2Array:
	var center_x: float = size.x * 0.5
	var half_width: float = size.x * mass
	var head_width: float = half_width * (0.52 if _fallback_kind != &"boss" else 0.44)
	return PackedVector2Array([
		Vector2(center_x - head_width, size.y * (top_ratio + 0.055)),
		Vector2(center_x - head_width * 0.45, size.y * (top_ratio + 0.012)),
		Vector2(center_x + head_width * 0.45, size.y * (top_ratio + 0.012)),
		Vector2(center_x + head_width, size.y * (top_ratio + 0.055)),
		Vector2(center_x + half_width * 0.55, size.y * (top_ratio + 0.17)),
		Vector2(center_x + half_width, size.y * 0.48),
		Vector2(center_x + half_width * 0.68, size.y * 0.6),
		Vector2(center_x + half_width * 0.53, size.y * 0.82),
		Vector2(center_x + half_width * 0.17, size.y * 0.88),
		Vector2(center_x, size.y * 0.72),
		Vector2(center_x - half_width * 0.17, size.y * 0.88),
		Vector2(center_x - half_width * 0.53, size.y * 0.82),
		Vector2(center_x - half_width * 0.68, size.y * 0.6),
		Vector2(center_x - half_width, size.y * 0.48),
		Vector2(center_x - half_width * 0.55, size.y * (top_ratio + 0.17)),
	])


func _draw_fallback_shadow(center: Vector2, radius: Vector2) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, radius.y / radius.x))
	draw_circle(Vector2.ZERO, radius.x, Color(0.0, 0.0, 0.0, 0.68))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_rank_mark(center: Vector2, top_ratio: float, mark_color: Color) -> void:
	var mark_y: float = size.y * top_ratio - 8.0
	var half_width: float = 24.0 if _fallback_kind == &"elite" else 38.0
	var crown: PackedVector2Array = PackedVector2Array([
		Vector2(center.x - half_width, mark_y + 18.0),
		Vector2(center.x - half_width * 0.65, mark_y),
		Vector2(center.x, mark_y + 12.0),
		Vector2(center.x + half_width * 0.65, mark_y),
		Vector2(center.x + half_width, mark_y + 18.0),
	])
	draw_polyline(crown, mark_color, 3.0 if _fallback_kind == &"elite" else 5.0, true)


func _presentable_accent(color: Color) -> Color:
	# Piso de brillo solo para PRESENTACIÓN del fallback: no toca el accent
	# guardado en CharacterVisualData, solo el color usado para dibujar el
	# contorno/rune cuando ese accent es demasiado oscuro para leerse.
	if color.v >= FALLBACK_ACCENT_MIN_VALUE:
		return color
	var boosted: Color = color
	boosted.v = FALLBACK_ACCENT_MIN_VALUE
	return boosted


func _has_usable_animation(frames: SpriteFrames, animation_name: StringName) -> bool:
	return (
		frames != null
		and frames.has_animation(animation_name)
		and frames.get_frame_count(animation_name) > 0
		and frames.get_animation_speed(animation_name) > 0.0
	)


func _ensure_animated_sprite() -> void:
	if _animated_sprite != null:
		return
	_animated_sprite = AnimatedSprite2D.new()
	_animated_sprite.name = "AnimatedArt"
	_animated_sprite.centered = true
	_animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_animated_sprite.visible = false
	_animated_sprite.z_index = 1
	add_child(_animated_sprite)
	_animated_sprite.frame_changed.connect(_on_animated_frame_changed)


func _ensure_reticle() -> void:
	if _reticle != null:
		return
	_reticle = CombatTargetReticle.new()
	_reticle.name = "TargetReticle"
	_reticle.z_index = 20
	_reticle.hide()
	add_child(_reticle)
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ensure_equipment_layers() -> void:
	if _equipment_visual_root != null:
		return
	static_art.z_index = 1
	fallback_label.z_index = 1
	_equipment_visual_root = Control.new()
	_equipment_visual_root.name = "EquipmentVisualRoot"
	_equipment_visual_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipment_visual_root.clip_contents = false
	add_child(_equipment_visual_root)
	_equipment_visual_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_equipment_back_layer = _create_equipment_layer("BackEquipment")
	_equipment_armor_layer = _create_equipment_layer("FrontEquipment")
	_equipment_weapon_layer = _create_equipment_layer("WeaponEquipment")


func _create_equipment_layer(layer_name: String) -> EquipmentVisualLayer:
	var layer: EquipmentVisualLayer = EquipmentVisualLayer.new()
	layer.name = layer_name
	_equipment_visual_root.add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return layer


func _refresh_equipment_layout() -> void:
	if _equipment_visual_root == null:
		return
	var visual_scale: float = _visual.combat_scale if _visual != null else 1.0
	var visual_offset: Vector2 = _visual.combat_offset if _visual != null else Vector2.ZERO
	var flip_sign: float = -1.0 if _visual != null and _visual.flip_h else 1.0
	_equipment_visual_root.pivot_offset = _equipment_visual_root.size * 0.5
	_equipment_visual_root.position = visual_offset
	_equipment_visual_root.scale = Vector2(flip_sign * visual_scale, visual_scale)


func _set_equipment_state(animation_name: StringName) -> void:
	_current_animation_name = animation_name
	if _equipment_visual_root == null:
		return
	_equipment_back_layer.set_character_state(animation_name)
	_equipment_armor_layer.set_character_state(animation_name)
	_equipment_weapon_layer.set_character_state(animation_name)


func _on_animated_frame_changed() -> void:
	_refresh_animated_scale()
	if _equipment_visual_root == null:
		return
	var animation_name: StringName = _animated_sprite.animation
	var frame_index: int = _animated_sprite.frame
	_equipment_back_layer.set_frame_context(animation_name, frame_index)
	_equipment_armor_layer.set_frame_context(animation_name, frame_index)
	_equipment_weapon_layer.set_frame_context(animation_name, frame_index)


func _refresh_animated_scale() -> void:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return
	var texture: Texture2D = _animated_sprite.sprite_frames.get_frame_texture(_animated_sprite.animation, _animated_sprite.frame)
	if texture == null:
		return
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var visual_scale: float = _visual.combat_scale if _visual != null else 1.0
	var fit_scale: float = minf(size.x / texture_size.x, size.y / texture_size.y)
	_animated_sprite.scale = Vector2.ONE * fit_scale * visual_scale

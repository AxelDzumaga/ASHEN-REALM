class_name CharacterVisualData
extends Resource

@export var portrait: Texture2D
@export var combat_texture: Texture2D
@export_file("*.png", "*.webp") var portrait_path: String
@export_file("*.png", "*.webp") var combat_texture_path: String
@export var sprite_frames: SpriteFrames
@export_file("*.tres") var sprite_frames_path: String
@export var accent: Color = Color("e6a23c")
@export_range(0.5, 2.0, 0.01) var combat_scale: float = 1.0
@export var combat_offset: Vector2 = Vector2.ZERO
@export_range(0.1, 0.9, 0.01) var attack_impact_ratio: float = 0.55
@export var animation_contact_times: Dictionary = {}
@export var flip_h: bool = false
@export var freeze_idle_with_reduce_motion: bool = false
@export var allow_equipment_overlays: bool = true

var _portrait_cache: Texture2D
var _combat_cache: Texture2D
var _sprite_frames_cache: SpriteFrames


func get_combat_texture() -> Texture2D:
	if combat_texture != null:
		return combat_texture
	if _combat_cache == null:
		_combat_cache = _load_optional_texture(combat_texture_path)
	if _combat_cache != null:
		return _combat_cache
	return get_portrait()


func get_portrait() -> Texture2D:
	if portrait != null:
		return portrait
	if _portrait_cache == null:
		_portrait_cache = _load_optional_texture(portrait_path)
	if _portrait_cache != null:
		return _portrait_cache
	if combat_texture != null:
		return combat_texture
	if _combat_cache == null:
		_combat_cache = _load_optional_texture(combat_texture_path)
	return _combat_cache


func get_sprite_frames() -> SpriteFrames:
	if sprite_frames != null:
		return sprite_frames
	if _sprite_frames_cache == null:
		_sprite_frames_cache = _load_optional_sprite_frames(sprite_frames_path)
	return _sprite_frames_cache


func get_animation_duration(animation_name: StringName) -> float:
	var frames: SpriteFrames = get_sprite_frames()
	if frames == null or not frames.has_animation(animation_name):
		return 0.0
	var frame_count: int = frames.get_frame_count(animation_name)
	var frames_per_second: float = frames.get_animation_speed(animation_name)
	if frame_count <= 0 or frames_per_second <= 0.0:
		return 0.0
	return float(frame_count) / frames_per_second


func get_animation_contact_ratio(animation_name: StringName, fallback: float = 0.55) -> float:
	var value: Variant = animation_contact_times.get(animation_name, fallback)
	return clampf(float(value), 0.0, 1.0)


func _load_optional_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	var loaded: Resource = ResourceLoader.load(path, "Texture2D")
	return loaded as Texture2D


func _load_optional_sprite_frames(path: String) -> SpriteFrames:
	if path.is_empty() or not ResourceLoader.exists(path, "SpriteFrames"):
		return null
	var loaded: Resource = ResourceLoader.load(path, "SpriteFrames")
	return loaded as SpriteFrames

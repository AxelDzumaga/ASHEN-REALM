class_name BiomeEnvironmentLayer
extends Control

const CONTEXT_BOARD := &"board"
const CONTEXT_COMBAT := &"combat"
const CONTEXT_AMBIENT := &"ambient"
const CONTEXT_RESULT := &"result"

var _background: TextureRect
var _atmosphere: CombatAtmosphereLayer
var _overlay: ColorRect
var _foreground: TextureRect


func configure(biome: BiomeData, context: StringName, boss: bool = false) -> void:
	_ensure_layers()
	if biome == null:
		hide()
		return
	var background_texture: Texture2D = biome.get_environment_texture()
	if context == CONTEXT_COMBAT:
		background_texture = biome.get_combat_background()
	var foreground_texture: Texture2D = biome.get_foreground_texture()
	_background.texture = background_texture
	_foreground.texture = foreground_texture
	_background.modulate = biome.ambient_tint
	_foreground.modulate = biome.ambient_tint
	_atmosphere.visible = context == CONTEXT_COMBAT
	_atmosphere.configure(biome.accent_color, boss)
	_overlay.color = biome.get_overlay_color(context, boss)
	modulate.a = 0.34 if context == CONTEXT_RESULT else 1.0
	visible = background_texture != null or foreground_texture != null


func _ensure_layers() -> void:
	if _background != null:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background = _create_texture_layer("BiomeBackground")
	add_child(_background)
	_atmosphere = CombatAtmosphereLayer.new()
	_atmosphere.name = "CombatAtmosphere"
	_fill_parent(_atmosphere)
	add_child(_atmosphere)
	_foreground = _create_texture_layer("BiomeForeground")
	add_child(_foreground)
	_overlay = ColorRect.new()
	_overlay.name = "BiomeContrastOverlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_parent(_overlay)
	add_child(_overlay)


func _create_texture_layer(layer_name: String) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_fill_parent(layer)
	return layer


func _fill_parent(control: Control) -> void:
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	control.grow_vertical = Control.GROW_DIRECTION_BOTH

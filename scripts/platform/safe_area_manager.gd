extends Node

## Centraliza los insets del sistema para que fondos sigan cubriendo la pantalla
## y solamente el contenido interactivo se mantenga dentro del area segura.
const CONTENT_NODE_NAMES: PackedStringArray = [
	"Margin", "MarginContainer", "Frame", "LobbyFrame", "CombatFrame",
]

var _registered: Array[Control] = []


func _ready() -> void:
	get_viewport().size_changed.connect(_refresh_registered)


func register_screen(screen: Control) -> void:
	if screen == null:
		return
	var content := _find_content_root(screen)
	if content == null:
		return
	_register_control(content)


func register_control(control: Control) -> void:
	if control != null:
		_register_control(control)


func get_safe_insets() -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var screen_size := DisplayServer.screen_get_size()
	var safe_rect := DisplayServer.get_display_safe_area()
	var viewport_size := get_viewport().get_visible_rect().size
	if screen_size.x <= 0 or screen_size.y <= 0 or safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		return Vector4.ZERO
	var scale := Vector2(viewport_size.x / float(screen_size.x), viewport_size.y / float(screen_size.y))
	return Vector4(
		maxf(0.0, safe_rect.position.x * scale.x),
		maxf(0.0, safe_rect.position.y * scale.y),
		maxf(0.0, (screen_size.x - safe_rect.end.x) * scale.x),
		maxf(0.0, (screen_size.y - safe_rect.end.y) * scale.y),
	)


func _find_content_root(screen: Control) -> Control:
	for node_name: String in CONTENT_NODE_NAMES:
		var candidate := screen.get_node_or_null(NodePath(node_name)) as Control
		if candidate != null:
			return candidate
	return null


func _register_control(control: Control) -> void:
	if not control.has_meta(&"safe_area_base_offsets"):
		control.set_meta(&"safe_area_base_offsets", Vector4(
			control.offset_left, control.offset_top, control.offset_right, control.offset_bottom,
		))
	if control not in _registered:
		_registered.append(control)
	_apply(control)


func _refresh_registered() -> void:
	for index: int in range(_registered.size() - 1, -1, -1):
		var control := _registered[index]
		if not is_instance_valid(control):
			_registered.remove_at(index)
		else:
			_apply(control)


func _apply(control: Control) -> void:
	var base: Vector4 = control.get_meta(&"safe_area_base_offsets", Vector4.ZERO) as Vector4
	var insets := get_safe_insets()
	control.offset_left = base.x + insets.x
	control.offset_top = base.y + insets.y
	control.offset_right = base.z - insets.z
	control.offset_bottom = base.w - insets.w

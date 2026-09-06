class_name MapCameraController
extends Node3D

enum State { NAVIGATION, ROUTE_SELECTION, MOVING, ARRIVAL }

@onready var camera: Camera3D = $Camera3D

var state: State = State.NAVIGATION
var _active_tween: Tween


func _ready() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(11.5, 14.0, 12.5)
	camera.look_at(Vector3.ZERO, Vector3.UP)


func focus_navigation(current_index: int, positions: Array[Vector3], duration: float = 0.35) -> void:
	state = State.NAVIGATION
	if current_index < 0 or current_index >= positions.size():
		return
	var look_ahead_index: int = mini(positions.size() - 1, current_index + 4)
	# Sesgo hacia el jugador: mantiene la casilla actual dentro del encuadre y
	# reserva espacio visual para las próximas cuatro posiciones.
	var target: Vector3 = positions[current_index].lerp(positions[look_ahead_index], 0.42)
	_move_rig(target, duration)
	var target_size: float = 18.5 if current_index >= positions.size() - 4 else 20.0
	var size_tween := create_tween()
	size_tween.tween_property(camera, "size", target_size, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func focus_route(destinations: Array[int], positions: Array[Vector3]) -> void:
	state = State.ROUTE_SELECTION
	var focus_points: Array[Vector3] = []
	for destination: int in destinations:
		if destination >= 0 and destination < positions.size():
			focus_points.append(positions[destination])
	_focus(focus_points, 0.28, 15.5)


## Encuadra puntos de mundo arbitrarios (p.ej. ambos carriles de un fork
## verdadero, que no pertenecen al array `positions` del spine).
func focus_world_points(points: Array[Vector3], duration: float = 0.32, size: float = 17.0) -> void:
	state = State.ROUTE_SELECTION
	_focus(points, duration, size)


func follow_step(from_index: int, to_index: int, positions: Array[Vector3], duration: float) -> void:
	state = State.MOVING
	if from_index < 0 or to_index < 0 or to_index >= positions.size():
		return
	var look_ahead_index: int = mini(positions.size() - 1, to_index + 2)
	var target: Vector3 = positions[to_index].lerp(positions[look_ahead_index], 0.28)
	_move_rig(target, duration)


## Igual que follow_step, pero recibe las posiciones ya resueltas (spine o
## carril de rama activo) en vez de derivarlas de un índice — necesario
## mientras el jugador camina dentro de una rama, donde el índice lógico no
## corresponde a una única posición fija del spine.
func follow_step_to_position(current_world: Vector3, look_ahead_world: Vector3, duration: float) -> void:
	state = State.MOVING
	var target: Vector3 = current_world.lerp(look_ahead_world, 0.28)
	_move_rig(target, duration)


func focus_arrival(index: int, positions: Array[Vector3]) -> void:
	state = State.ARRIVAL
	if index >= 0 and index < positions.size():
		_move_rig(positions[index], 0.18)


func focus_full_map(positions: Array[Vector3], duration: float = 0.35) -> void:
	state = State.NAVIGATION
	_focus(positions, duration, 88.0)


func _focus(points: Array[Vector3], duration: float, target_size: float) -> void:
	if points.is_empty():
		return
	var center := Vector3.ZERO
	for point: Vector3 in points:
		center += point
	center /= float(points.size())
	_move_rig(center, duration)
	if is_instance_valid(camera):
		var tween := create_tween()
		tween.tween_property(camera, "size", target_size, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _move_rig(target: Vector3, duration: float) -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

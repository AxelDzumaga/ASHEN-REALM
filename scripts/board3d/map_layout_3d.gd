class_name MapLayout3D
extends RefCounted

## Mapping visual determinista. No consume board_seed ni RNG de gameplay.

const POSITION_COUNT := 30
const FORWARD_SPACING := 2.65


static func get_world_position(board_index: int, count: int = POSITION_COUNT) -> Vector3:
	var safe_count: int = maxi(2, count)
	var index: int = clampi(board_index, 0, safe_count - 1)
	var progress: float = float(index)
	var lateral: float = sin(progress * 0.55) * 5.2 + sin(progress * 0.19) * 1.8
	var elevation: float = sin(progress * 0.43) * 0.42 + progress * 0.035
	var forward: float = -progress * FORWARD_SPACING
	if index == safe_count - 1:
		# La explanada del boss queda apenas más alta y separada del último tramo.
		elevation += 0.65
		forward -= 0.8
	return Vector3(lateral, elevation, forward)


static func get_positions(count: int = POSITION_COUNT) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for index: int in range(maxi(0, count)):
		result.append(get_world_position(index, count))
	return result


## Posición de una casilla de rama (fork/merge no incluidos). `side` es +1
## para una ruta y -1 para la otra: divergen desde el fork y vuelven a
## converger en el merge, formando dos caminos físicamente separados en vez
## de compartir el mismo trazo. Geometría conceptual/procedural — sin arte
## final. Desconoce a propósito RouteBranchData (helper puramente geométrico).
static func get_branch_position(fork_index: int, merge_index: int, side: int, local_position: int, branch_length: int, main_positions: Array[Vector3]) -> Vector3:
	if fork_index < 0 or merge_index < 0 or merge_index >= main_positions.size():
		return main_positions[clampi(fork_index, 0, main_positions.size() - 1)]
	var fork_point: Vector3 = main_positions[fork_index]
	var merge_point: Vector3 = main_positions[merge_index]
	var t: float = float(local_position) / float(branch_length + 1)
	var base: Vector3 = fork_point.lerp(merge_point, t)
	var forward: Vector3 = merge_point - fork_point
	var lateral: Vector3 = Vector3(forward.z, 0.0, -forward.x).normalized() if forward.length() > 0.001 else Vector3.RIGHT
	var bulge: float = sin(t * PI)
	return base + lateral * float(side) * bulge * 3.6 + Vector3(0.0, bulge * 0.4, 0.0)


static func get_bounds(positions: Array[Vector3]) -> AABB:
	if positions.is_empty():
		return AABB()
	var bounds := AABB(positions[0], Vector3.ZERO)
	for point: Vector3 in positions:
		bounds = bounds.expand(point)
	return bounds


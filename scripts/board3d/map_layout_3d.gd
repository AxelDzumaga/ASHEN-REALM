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


static func get_bounds(positions: Array[Vector3]) -> AABB:
	if positions.is_empty():
		return AABB()
	var bounds := AABB(positions[0], Vector3.ZERO)
	for point: Vector3 in positions:
		bounds = bounds.expand(point)
	return bounds


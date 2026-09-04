extends Node

const MapLayout3DSource = preload("res://scripts/board3d/map_layout_3d.gd")


func _ready() -> void:
	var failures: Array[String] = []
	var positions: Array[Vector3] = MapLayout3DSource.get_positions(30)
	if positions.size() != 30:
		failures.append("position_count")
	var unique: Dictionary = {}
	for index: int in positions.size():
		var point: Vector3 = positions[index]
		if not point.is_finite():
			failures.append("non_finite_%d" % index)
		var key := "%0.5f:%0.5f:%0.5f" % [point.x, point.y, point.z]
		if unique.has(key):
			failures.append("duplicate_%d" % index)
		unique[key] = true
		if index > 0:
			var distance := point.distance_to(positions[index - 1])
			if distance < 1.5 or distance > 6.0:
				failures.append("distance_%d_%0.3f" % [index, distance])
	if MapLayout3DSource.get_world_position(0) != positions[0]:
		failures.append("start_mapping")
	if MapLayout3DSource.get_world_position(29) != positions[29]:
		failures.append("boss_mapping")
	print(JSON.stringify({"positions": positions.size(), "unique": unique.size(), "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)


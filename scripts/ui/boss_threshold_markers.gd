class_name BossThresholdMarkers
extends Control

var thresholds: Array[int] = [70, 35]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	for threshold: int in thresholds:
		var marker_x: float = size.x * float(threshold) / 100.0
		draw_line(Vector2(marker_x, 2.0), Vector2(marker_x, size.y - 2.0), Color(0.95, 0.76, 0.42, 0.9), 2.0)

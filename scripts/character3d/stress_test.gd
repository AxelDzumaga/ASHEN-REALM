extends Node3D

## Character3D Technical Pilot (Tier 5) — C3D.7 stress/perf harness.
## Engineering-only: spawns N fully-equipped CharacterVisual3D instances,
## lets them run a few seconds of idle animation under the real (non-
## headless) Mobile renderer, then prints Performance monitors and quits.
## Not part of the pilot's production API — a throwaway measurement tool.

const VISUAL_SCENE := preload("res://scenes/character3d/character_visual_3d.tscn")
const WEAPON_A := preload("res://data/character3d_pilot/weapon_a.tres")
const HELMET_A := preload("res://data/character3d_pilot/helmet_a.tres")
const CHEST_A := preload("res://data/character3d_pilot/chest_a.tres")
const CAPE_A := preload("res://data/character3d_pilot/cape_a.tres")

var _actor_count: int = 1
var _elapsed: float = 0.0
var _sampled: bool = false
var _sample_after_seconds: float = 1.5
var _quit_after_seconds: float = 2.5


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--actors="):
			_actor_count = int(arg.get_slice("=", 1))
	_spawn_actors(_actor_count)
	print("[STRESS_TEST] spawned actors=%d" % _actor_count)


func _spawn_actors(count: int) -> void:
	var columns: int = maxi(1, ceili(sqrt(float(count))))
	for i in count:
		var visual: CharacterVisual3D = VISUAL_SCENE.instantiate()
		add_child(visual)
		var col: int = i % columns
		var row: int = i / columns
		visual.position = Vector3(col * 1.2, 0.0, row * 1.2)
		visual.set_weapon(WEAPON_A)
		visual.set_head(HELMET_A)
		visual.set_chest(CHEST_A)
		visual.set_cape(CAPE_A)
		visual.play_idle()


func _process(delta: float) -> void:
	_elapsed += delta
	if not _sampled and _elapsed >= _sample_after_seconds:
		_sampled = true
		_print_performance()
	if _elapsed >= _quit_after_seconds:
		get_tree().quit(0)


func _print_performance() -> void:
	var report: Dictionary = {
		"actor_count": _actor_count,
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"frame_time_process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"objects_in_frame": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"video_mem_used_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	}
	print("[STRESS_TEST_REPORT] %s" % JSON.stringify(report))

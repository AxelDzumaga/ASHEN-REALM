extends Node3D

## Character3D Technical Pilot (Tier 5) — C3D.6 real-render engineering
## smoke. Not part of the pilot's production API. Cycles every equip
## combination through every animation, checks AnimationPlayer state and
## engine error/warning output, and saves one reference screenshot per
## combination to build/character3d_pilot_smoke/ for human/AI visual
## review later. "Human visual beauty" is explicitly NOT the pass/fail
## criterion here — only structural playback correctness is.

const VISUAL_SCENE := preload("res://scenes/character3d/character_visual_3d.tscn")
const WEAPON_A := preload("res://data/character3d_pilot/weapon_a.tres")
const HELMET_A := preload("res://data/character3d_pilot/helmet_a.tres")
const CHEST_A := preload("res://data/character3d_pilot/chest_a.tres")
const CAPE_A := preload("res://data/character3d_pilot/cape_a.tres")

const OUT_DIR := "res://build/character3d_pilot_smoke"

var _visual: CharacterVisual3D
var _combos: Array = [
	{"name": "base_only", "weapon": false, "head": false, "chest": false, "cape": false},
	{"name": "base_weapon", "weapon": true, "head": false, "chest": false, "cape": false},
	{"name": "base_helmet", "weapon": false, "head": true, "chest": false, "cape": false},
	{"name": "base_chest", "weapon": false, "head": false, "chest": true, "cape": false},
	{"name": "base_cape", "weapon": false, "head": false, "chest": false, "cape": true},
	{"name": "all_equipped", "weapon": true, "head": true, "chest": true, "cape": true},
]
var _animations: Array[StringName] = [&"idle", &"basic_attack", &"hit", &"death"]

var _combo_index: int = 0
var _anim_index: int = 0
var _frames_in_state: int = 0
var _failures: Array[String] = []
var _done: bool = false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_visual = VISUAL_SCENE.instantiate()
	add_child(_visual)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 1.4, 3.2)
	cam.look_at(Vector3(0, 1.2, 0), Vector3.UP)
	cam.current = true
	var light := DirectionalLight3D.new()
	light.position = Vector3(0, 4, 2)
	light.rotation_degrees = Vector3(-45, 20, 0)
	add_child(light)
	_apply_combo(_combos[0])


func _apply_combo(combo: Dictionary) -> void:
	_visual.set_weapon(WEAPON_A if combo["weapon"] else null)
	_visual.set_head(HELMET_A if combo["head"] else null)
	_visual.set_chest(CHEST_A if combo["chest"] else null)
	_visual.set_cape(CAPE_A if combo["cape"] else null)
	_visual.play_idle()


func _check(label: String, condition: bool) -> void:
	print("[ANIM_COMPAT_SMOKE] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


func _process(_delta: float) -> void:
	if _done:
		return
	_frames_in_state += 1
	if _frames_in_state == 3:
		var combo: Dictionary = _combos[_combo_index]
		var anim: StringName = _animations[_anim_index]
		_visual._play(anim)
	if _frames_in_state == 6:
		var combo: Dictionary = _combos[_combo_index]
		var anim: StringName = _animations[_anim_index]
		var ap: AnimationPlayer = _visual.animation_player
		_check("%s__%s_is_current" % [combo["name"], anim], ap.current_animation == String(anim))
		if _anim_index == 0:
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png(OUT_DIR + "/" + String(combo["name"]) + ".png")
	if _frames_in_state >= 8:
		_frames_in_state = 0
		_anim_index += 1
		if _anim_index >= _animations.size():
			_anim_index = 0
			_combo_index += 1
			if _combo_index >= _combos.size():
				_finish()
				return
			_apply_combo(_combos[_combo_index])


func _finish() -> void:
	_done = true
	print("[ANIM_COMPAT_SMOKE] failures=%s" % JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)

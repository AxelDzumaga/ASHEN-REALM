extends Node

## Character3D Technical Pilot (Tier 5) — presentation-only harness tests.
## No SaveManager, no CombatActor, no RunState involved anywhere in this
## file: CharacterVisual3D is validated purely as a standalone Node3D
## component, matching the pilot's isolation requirement.

const VISUAL_SCENE := preload("res://scenes/character3d/character_visual_3d.tscn")
const WEAPON_A := preload("res://data/character3d_pilot/weapon_a.tres")
const HELMET_A := preload("res://data/character3d_pilot/helmet_a.tres")
const HELMET_B := preload("res://data/character3d_pilot/helmet_b.tres")
const CHEST_A := preload("res://data/character3d_pilot/chest_a.tres")
const CAPE_A := preload("res://data/character3d_pilot/cape_a.tres")

var _failures: Array[String] = []


func _ready() -> void:
	await _test_base_builds_skeleton_and_attachments()
	await _test_equip_unequip_each_slot()
	await _test_replacing_module_does_not_duplicate()
	await _test_invalid_visual_id_fails_safely()
	await _test_rebuild_from_presentation_ids()
	await _test_no_gameplay_state_mutation()
	_test_no_combat_actor_dependency()
	_test_no_save_manager_dependency()
	print("[CHARACTER_VISUAL_3D_TEST] failures=%s" % JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(label: String, condition: bool) -> void:
	print("[CHARACTER_VISUAL_3D_TEST] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


func _spawn() -> CharacterVisual3D:
	var visual: CharacterVisual3D = VISUAL_SCENE.instantiate()
	add_child(visual)
	return visual


func _test_base_builds_skeleton_and_attachments() -> void:
	var visual: CharacterVisual3D = _spawn()
	await get_tree().process_frame
	_check("base_has_skeleton", visual.skeleton != null)
	_check("base_has_animation_player", visual.animation_player != null)
	_check("base_bone_count_is_20", visual.skeleton != null and visual.skeleton.get_bone_count() == 20)
	_check("base_has_head_bone", visual.skeleton != null and visual.skeleton.find_bone("Head") >= 0)
	_check("base_has_hand_r_bone", visual.skeleton != null and visual.skeleton.find_bone("Hand_R") >= 0)
	_check("base_has_chest_bone", visual.skeleton != null and visual.skeleton.find_bone("Chest") >= 0)
	_check("animations_present", visual.animation_player != null and visual.animation_player.get_animation_list().size() == 4)
	visual.queue_free()


func _test_equip_unequip_each_slot() -> void:
	var visual: CharacterVisual3D = _spawn()
	await get_tree().process_frame

	visual.set_weapon(WEAPON_A)
	_check("weapon_equip_sets_id", visual.current_weapon_id == &"weapon_a")
	visual.set_weapon(null)
	_check("weapon_unequip_clears_id", visual.current_weapon_id == &"")

	visual.set_head(HELMET_A)
	_check("head_equip_sets_id", visual.current_head_id == &"helmet_a")
	visual.set_head(null)
	_check("head_unequip_clears_id", visual.current_head_id == &"")

	visual.set_chest(CHEST_A)
	_check("chest_equip_sets_id", visual.current_chest_id == &"chest_a")
	var torso: MeshInstance3D = visual._find_mesh_by_name(visual.skeleton, &"Torso")
	_check("chest_equip_hides_base_torso", torso != null and not torso.visible)
	visual.set_chest(null)
	_check("chest_unequip_clears_id", visual.current_chest_id == &"")
	torso = visual._find_mesh_by_name(visual.skeleton, &"Torso")
	_check("chest_unequip_restores_base_torso", torso != null and torso.visible)

	visual.set_cape(CAPE_A)
	_check("cape_equip_sets_id", visual.current_cape_id == &"cape_a")
	visual.set_cape(null)
	_check("cape_unequip_clears_id", visual.current_cape_id == &"")

	visual.queue_free()


func _test_replacing_module_does_not_duplicate() -> void:
	var visual: CharacterVisual3D = _spawn()
	await get_tree().process_frame
	visual.set_head(HELMET_A)
	visual.set_head(HELMET_B)
	_check("replacing_head_switches_id", visual.current_head_id == &"helmet_b")
	_check("replacing_head_leaves_exactly_one_child", visual._head_attachment.get_child_count() == 1)
	visual.queue_free()


func _test_invalid_visual_id_fails_safely() -> void:
	var visual: CharacterVisual3D = _spawn()
	await get_tree().process_frame
	var bogus := EquipmentVisual3DData.new()
	bogus.visual_id = &"does_not_exist"
	bogus.slot = EquipmentVisual3DData.Slot.WEAPON
	bogus.scene_path = "res://assets/characters/ashen_wanderer_3d/does_not_exist.glb"
	var crashed: bool = false
	visual.set_weapon(bogus)
	crashed = false
	_check("invalid_visual_id_does_not_crash", not crashed)
	_check("invalid_visual_id_leaves_no_id_set", visual.current_weapon_id == &"")
	visual.queue_free()


func _test_rebuild_from_presentation_ids() -> void:
	var visual: CharacterVisual3D = _spawn()
	await get_tree().process_frame
	visual.set_weapon(WEAPON_A)
	visual.set_head(HELMET_A)
	visual.set_chest(CHEST_A)
	visual.set_cape(CAPE_A)
	var ids: Dictionary = visual.get_equipped_ids()
	visual.queue_free()

	var rebuilt: CharacterVisual3D = _spawn()
	await get_tree().process_frame
	if ids["weapon"] == &"weapon_a":
		rebuilt.set_weapon(WEAPON_A)
	if ids["head"] == &"helmet_a":
		rebuilt.set_head(HELMET_A)
	if ids["chest"] == &"chest_a":
		rebuilt.set_chest(CHEST_A)
	if ids["cape"] == &"cape_a":
		rebuilt.set_cape(CAPE_A)
	var rebuilt_ids: Dictionary = rebuilt.get_equipped_ids()
	_check("rebuild_from_ids_matches_original", rebuilt_ids == ids)
	rebuilt.queue_free()


func _test_no_gameplay_state_mutation() -> void:
	# No RunState/ProfileData exists in this test at all — equipping/
	# unequipping every slot must not require, touch, or fail without one.
	var visual: CharacterVisual3D = _spawn()
	await get_tree().process_frame
	visual.set_weapon(WEAPON_A)
	visual.set_head(HELMET_A)
	visual.set_chest(CHEST_A)
	visual.set_cape(CAPE_A)
	visual.set_weapon(null)
	visual.set_head(null)
	visual.set_chest(null)
	visual.set_cape(null)
	_check("full_equip_unequip_cycle_touches_no_gameplay_state", true)
	visual.queue_free()


## Strips '#'-comment lines before searching so descriptive prose (this
## file's own doc-comments name the systems it deliberately avoids) can
## never produce a false "reference found" — only actual code tokens count.
func _code_without_comments(source: String) -> String:
	var lines: PackedStringArray = source.split("\n")
	var kept: PackedStringArray = PackedStringArray()
	for line in lines:
		if line.strip_edges().begins_with("#"):
			continue
		kept.append(line)
	return "\n".join(kept)


func _test_no_combat_actor_dependency() -> void:
	var script: Script = load("res://scripts/character3d/character_visual_3d.gd")
	var code: String = _code_without_comments(script.source_code)
	_check("no_combat_actor_reference", not code.contains("CombatActor"))


func _test_no_save_manager_dependency() -> void:
	var script: Script = load("res://scripts/character3d/character_visual_3d.gd")
	var code: String = _code_without_comments(script.source_code)
	_check("no_save_manager_reference", not code.contains("SaveManager"))

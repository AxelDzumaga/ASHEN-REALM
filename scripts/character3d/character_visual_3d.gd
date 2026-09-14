class_name CharacterVisual3D
extends Node3D

## Character3D Technical Pilot (Tier 5) — presentation-only harness.
##
## Isolated from gameplay/domain by construction: this component never
## references CombatActor, RunState, ProfileData, SaveManager, combat.gd, or
## any productive EquipmentData/catalog. It exists to validate the modular
## equipment/skeleton-sharing architecture ahead of Combat3D — nothing here
## is wired into production, and no Node3D/mesh/skeleton state is ever
## persisted to a save.
##
## Base body (res://assets/characters/ashen_wanderer_3d/mannequin_base.glb)
## is instanced as a child; its single Skeleton3D is the shared skinning
## target for both the base meshes and an equipped CHEST module. WEAPON,
## HEAD and CAPE are simple non-skinned meshes carried by BoneAttachment3D
## nodes created under that same Skeleton3D.

const BASE_SCENE_PATH: String = "res://assets/characters/ashen_wanderer_3d/mannequin_base.glb"

const HEAD_BONE: StringName = &"Head"
const WEAPON_BONE: StringName = &"Hand_R"
const CAPE_BONE: StringName = &"Chest"

var skeleton: Skeleton3D
var animation_player: AnimationPlayer

var _head_attachment: BoneAttachment3D
var _weapon_attachment: BoneAttachment3D
var _cape_attachment: BoneAttachment3D

var _head_module: Node3D
var _weapon_module: Node3D
var _cape_module: Node3D
var _chest_mesh: MeshInstance3D

var _base_mesh_visibility_refs: int = 0
var _hidden_base_meshes: Dictionary = {}  # StringName mesh name -> bool (currently hidden by a module)

var current_weapon_id: StringName = &""
var current_head_id: StringName = &""
var current_chest_id: StringName = &""
var current_cape_id: StringName = &""


func _ready() -> void:
	_build_base()


func _build_base() -> void:
	var base_scene: PackedScene = load(BASE_SCENE_PATH)
	var base_instance: Node3D = base_scene.instantiate()
	add_child(base_instance)
	skeleton = _find_first(base_instance, "Skeleton3D") as Skeleton3D
	animation_player = _find_first(base_instance, "AnimationPlayer") as AnimationPlayer
	if skeleton == null:
		push_error("CharacterVisual3D: mannequin_base.glb did not contain a Skeleton3D")
		return
	_head_attachment = _make_attachment("HeadAttachment", HEAD_BONE)
	_weapon_attachment = _make_attachment("WeaponAttachment", WEAPON_BONE)
	_cape_attachment = _make_attachment("CapeAttachment", CAPE_BONE)


func _make_attachment(node_name: StringName, bone_name: StringName) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = node_name
	skeleton.add_child(attachment)
	attachment.bone_name = bone_name
	return attachment


## Recursive search for a node instance by class name. Used instead of a
## hardcoded NodePath so this component does not depend on the exact node
## naming a future re-export of mannequin_base.glb happens to produce.
func _find_first(node: Node, class_name_query: String) -> Node:
	if node.get_class() == class_name_query:
		return node
	for child in node.get_children():
		var found: Node = _find_first(child, class_name_query)
		if found != null:
			return found
	return null


func _find_mesh_by_name(root: Node, mesh_name: StringName) -> MeshInstance3D:
	if root is MeshInstance3D and root.name == mesh_name:
		return root
	for child in root.get_children():
		var found: MeshInstance3D = _find_mesh_by_name(child, mesh_name)
		if found != null:
			return found
	return null


## Checks existence before load() so an invalid visual_id fails with one
## quiet push_warning instead of an engine-level resource-not-found error.
func _load_module_scene(scene_path: String) -> PackedScene:
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		push_warning("CharacterVisual3D: invalid scene_path '%s'" % scene_path)
		return null
	var scene: Resource = load(scene_path)
	if not (scene is PackedScene):
		push_warning("CharacterVisual3D: scene_path '%s' is not a PackedScene" % scene_path)
		return null
	return scene


func _set_base_mesh_hidden(mesh_name: StringName, hidden: bool) -> void:
	if mesh_name == &"":
		return
	var mesh_node: MeshInstance3D = _find_mesh_by_name(skeleton, mesh_name)
	if mesh_node != null:
		mesh_node.visible = not hidden


## --- WEAPON (rigid, BoneAttachment3D @ Hand_R) --------------------------

func set_weapon(visual: EquipmentVisual3DData) -> void:
	if _weapon_module != null:
		_weapon_attachment.remove_child(_weapon_module)
		_weapon_module.queue_free()
		_weapon_module = null
	current_weapon_id = &""
	if visual == null:
		return
	var scene: PackedScene = _load_module_scene(visual.scene_path)
	if scene == null:
		return
	_weapon_module = scene.instantiate()
	_weapon_attachment.add_child(_weapon_module)
	current_weapon_id = visual.visual_id


## --- HEAD / helmet (rigid, BoneAttachment3D @ Head) ----------------------

func set_head(visual: EquipmentVisual3DData) -> void:
	if _head_module != null:
		_head_attachment.remove_child(_head_module)
		_head_module.queue_free()
		_head_module = null
	current_head_id = &""
	if visual == null:
		return
	var scene: PackedScene = _load_module_scene(visual.scene_path)
	if scene == null:
		return
	_head_module = scene.instantiate()
	_head_attachment.add_child(_head_module)
	current_head_id = visual.visual_id


## --- CAPE (rigid, BoneAttachment3D @ Chest) -------------------------------

func set_cape(visual: EquipmentVisual3DData) -> void:
	if _cape_module != null:
		_cape_attachment.remove_child(_cape_module)
		_cape_module.queue_free()
		_cape_module = null
	current_cape_id = &""
	if visual == null:
		return
	var scene: PackedScene = _load_module_scene(visual.scene_path)
	if scene == null:
		return
	_cape_module = scene.instantiate()
	_cape_attachment.add_child(_cape_module)
	current_cape_id = visual.visual_id


## --- CHEST (skinned mesh, re-parented onto the SHARED base Skeleton3D) ---
##
## The chest module's source .glb carries its own reference Armature/
## Skeleton3D, built by the exact same generator function as the base
## skeleton (see generate_mannequin.py) so bone names/hierarchy/rest pose
## match exactly. Godot's glTF import uses named skin binds
## (skins/use_named_skins=true), so a Skin resolves against whichever
## Skeleton3D it is pointed at by bone NAME, not by node identity — that is
## the mechanism this reparenting relies on.

func set_chest(visual: EquipmentVisual3DData) -> void:
	if _chest_mesh != null:
		_set_base_mesh_hidden(_current_chest_hidden_mesh, false)
		skeleton.remove_child(_chest_mesh)
		_chest_mesh.queue_free()
		_chest_mesh = null
	current_chest_id = &""
	_current_chest_hidden_mesh = &""
	if visual == null:
		return
	var scene: PackedScene = _load_module_scene(visual.scene_path)
	if scene == null:
		return
	var temp_root: Node3D = scene.instantiate()
	var mesh_node: MeshInstance3D = _find_first(temp_root, "MeshInstance3D") as MeshInstance3D
	if mesh_node == null:
		push_warning("CharacterVisual3D.set_chest: no MeshInstance3D found in '%s'" % visual.scene_path)
		temp_root.queue_free()
		return
	mesh_node.get_parent().remove_child(mesh_node)
	mesh_node.owner = null
	temp_root.queue_free()
	skeleton.add_child(mesh_node)
	mesh_node.skeleton = mesh_node.get_path_to(skeleton)
	_chest_mesh = mesh_node
	current_chest_id = visual.visual_id
	if visual.hides_base_mesh != &"":
		_set_base_mesh_hidden(visual.hides_base_mesh, true)
		_current_chest_hidden_mesh = visual.hides_base_mesh


var _current_chest_hidden_mesh: StringName = &""


## --- Animation passthrough -------------------------------------------------

func play_idle() -> void:
	_play(&"idle")


func play_attack() -> void:
	_play(&"basic_attack")


func play_hit() -> void:
	_play(&"hit")


func play_death() -> void:
	_play(&"death")


func _play(anim_name: StringName) -> void:
	if animation_player != null and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)


## --- Introspection helpers used by tests/stress harness --------------------

func get_equipped_ids() -> Dictionary:
	return {
		"weapon": current_weapon_id,
		"head": current_head_id,
		"chest": current_chest_id,
		"cape": current_cape_id,
	}

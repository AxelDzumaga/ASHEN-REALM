"""Ashen Realm — Character3D Technical Pilot (Tier 5).

Blender 5.2 headless generator for the technical mannequin used to validate
the modular-equipment/skeleton-sharing architecture before Combat3D exists.
Run with:

    blender --background --python generate_mannequin.py

Regenerates every .glb in this directory from scratch (idempotent). This
script IS the source asset — no .blend file is kept; re-running it is the
supported way to reproduce or tweak the mannequin.

Canonical skeleton (vendor-neutral, documented in
docs/character3d_pilot.md): Root, Hips, Spine, Chest, Neck, Head,
Shoulder_L/R, UpperArm_L/R, Forearm_L/R, Hand_L/R, UpperLeg_L/R,
LowerLeg_L/R, Foot_L/R (20 bones). Built in Blender's Z-up space, T-pose
bind pose; the glTF exporter's default +Y-up conversion makes Godot see the
character standing with feet at Y=0, height along +Y, facing -Z.

Five .glb files, one per independently-swappable module (matches the
production intent of equipment being authored as separate files by
different artists later):
  - mannequin_base.glb   — Skeleton + Torso mesh + Limbs mesh (skinned) + 4 animations
  - mannequin_chest_a.glb — a second Skeleton (identical bones/rest pose) + Chest mesh
                            (skinned) — only used in Godot to donate its mesh+skin to
                            the base Skeleton3D; its own skeleton node is discarded.
  - mannequin_helmet_a.glb / mannequin_helmet_b.glb — small non-skinned meshes
  - mannequin_weapon_a.glb — small non-skinned mesh
  - mannequin_cape_a.glb — small non-skinned mesh
"""

import bpy
import os

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

BONES = [
    # (name, parent, head_xyz, tail_xyz)
    ("Root", None, (0.0, 0.0, 0.0), (0.0, 0.0, 0.10)),
    ("Hips", "Root", (0.0, 0.0, 0.95), (0.0, 0.0, 1.05)),
    ("Spine", "Hips", (0.0, 0.0, 1.05), (0.0, 0.0, 1.15)),
    ("Chest", "Spine", (0.0, 0.0, 1.15), (0.0, 0.0, 1.35)),
    ("Neck", "Chest", (0.0, 0.0, 1.35), (0.0, 0.0, 1.42)),
    ("Head", "Neck", (0.0, 0.0, 1.42), (0.0, 0.0, 1.58)),

    ("Shoulder_L", "Chest", (0.06, 0.0, 1.32), (0.16, 0.0, 1.32)),
    ("UpperArm_L", "Shoulder_L", (0.16, 0.0, 1.32), (0.40, 0.0, 1.32)),
    ("Forearm_L", "UpperArm_L", (0.40, 0.0, 1.32), (0.62, 0.0, 1.32)),
    ("Hand_L", "Forearm_L", (0.62, 0.0, 1.32), (0.74, 0.0, 1.32)),

    ("Shoulder_R", "Chest", (-0.06, 0.0, 1.32), (-0.16, 0.0, 1.32)),
    ("UpperArm_R", "Shoulder_R", (-0.16, 0.0, 1.32), (-0.40, 0.0, 1.32)),
    ("Forearm_R", "UpperArm_R", (-0.40, 0.0, 1.32), (-0.62, 0.0, 1.32)),
    ("Hand_R", "Forearm_R", (-0.62, 0.0, 1.32), (-0.74, 0.0, 1.32)),

    ("UpperLeg_L", "Hips", (0.10, 0.0, 0.95), (0.10, 0.0, 0.52)),
    ("LowerLeg_L", "UpperLeg_L", (0.10, 0.0, 0.52), (0.10, 0.0, 0.10)),
    ("Foot_L", "LowerLeg_L", (0.10, 0.0, 0.10), (0.10, 0.14, 0.02)),

    ("UpperLeg_R", "Hips", (-0.10, 0.0, 0.95), (-0.10, 0.0, 0.52)),
    ("LowerLeg_R", "UpperLeg_R", (-0.10, 0.0, 0.52), (-0.10, 0.0, 0.10)),
    ("Foot_R", "LowerLeg_R", (-0.10, 0.0, 0.10), (-0.10, 0.14, 0.02)),
]

BONE_NAMES = [b[0] for b in BONES]
assert len(BONE_NAMES) == 20
assert len(set(BONE_NAMES)) == 20


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def build_armature(name):
    arm_data = bpy.data.armatures.new(name + "Data")
    arm_obj = bpy.data.objects.new(name, arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    edit_bones = arm_data.edit_bones
    created = {}
    for bone_name, parent_name, head, tail in BONES:
        eb = edit_bones.new(bone_name)
        eb.head = head
        eb.tail = tail
        eb.roll = 0.0
        created[bone_name] = eb
    for bone_name, parent_name, _head, _tail in BONES:
        if parent_name is not None:
            created[bone_name].parent = created[parent_name]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm_obj


def add_box(name, center, size):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0], size[1], size[2])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def add_cylinder_between(name, p0, p1, radius):
    import mathutils
    v0 = mathutils.Vector(p0)
    v1 = mathutils.Vector(p1)
    mid = (v0 + v1) / 2.0
    length = (v1 - v0).length
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=length, location=mid)
    obj = bpy.context.active_object
    obj.name = name
    direction = (v1 - v0).normalized()
    z_axis = mathutils.Vector((0, 0, 1))
    rot_quat = z_axis.rotation_difference(direction)
    obj.rotation_euler = rot_quat.to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return obj


def add_sphere(name, center, radius):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=center, segments=12, ring_count=8)
    obj = bpy.context.active_object
    obj.name = name
    return obj


def join_objects(objs, result_name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    merged = bpy.context.active_object
    merged.name = result_name
    return merged


def skin_to_armature(mesh_obj, armature_obj):
    bpy.ops.object.select_all(action="DESELECT")
    mesh_obj.select_set(True)
    armature_obj.select_set(True)
    bpy.context.view_layer.objects.active = armature_obj
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")


def build_torso_mesh(name):
    parts = []
    parts.append(add_box(name + "_pelvis", (0, 0, 0.90), (0.14, 0.09, 0.05)))
    parts.append(add_box(name + "_chest", (0, 0, 1.20), (0.16, 0.10, 0.10)))
    parts.append(add_box(name + "_shoulders", (0, 0, 1.31), (0.20, 0.10, 0.03)))
    return join_objects(parts, name)


def build_limbs_mesh(name):
    parts = []
    parts.append(add_sphere(name + "_head", (0, 0, 1.52), 0.12))
    parts.append(add_cylinder_between(name + "_neck", (0, 0, 1.35), (0, 0, 1.42), 0.045))
    parts.append(add_cylinder_between(name + "_upperarm_l", (0.16, 0, 1.32), (0.40, 0, 1.32), 0.045))
    parts.append(add_cylinder_between(name + "_forearm_l", (0.40, 0, 1.32), (0.62, 0, 1.32), 0.038))
    parts.append(add_box(name + "_hand_l", (0.70, 0, 1.32), (0.04, 0.03, 0.06)))
    parts.append(add_cylinder_between(name + "_upperarm_r", (-0.16, 0, 1.32), (-0.40, 0, 1.32), 0.045))
    parts.append(add_cylinder_between(name + "_forearm_r", (-0.40, 0, 1.32), (-0.62, 0, 1.32), 0.038))
    parts.append(add_box(name + "_hand_r", (-0.70, 0, 1.32), (0.04, 0.03, 0.06)))
    parts.append(add_cylinder_between(name + "_upperleg_l", (0.10, 0, 0.95), (0.10, 0, 0.52), 0.06))
    parts.append(add_cylinder_between(name + "_lowerleg_l", (0.10, 0, 0.52), (0.10, 0, 0.10), 0.05))
    parts.append(add_box(name + "_foot_l", (0.10, 0.05, 0.03), (0.05, 0.11, 0.03)))
    parts.append(add_cylinder_between(name + "_upperleg_r", (-0.10, 0, 0.95), (-0.10, 0, 0.52), 0.06))
    parts.append(add_cylinder_between(name + "_lowerleg_r", (-0.10, 0, 0.52), (-0.10, 0, 0.10), 0.05))
    parts.append(add_box(name + "_foot_r", (-0.10, 0.05, 0.03), (0.05, 0.11, 0.03)))
    return join_objects(parts, name)


def make_material(name, color):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = 0.7
    return mat


def assign_material(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def export_glb(path, objects, use_animations=False):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    kwargs = dict(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_skins=True,
        export_animations=use_animations,
    )
    if use_animations:
        kwargs["export_animation_mode"] = "ACTIONS"
    bpy.ops.export_scene.gltf(**kwargs)


def keyframe_pose_bone(armature_obj, bone_name, frame, location=None, rotation_euler=None):
    pbone = armature_obj.pose.bones[bone_name]
    if location is not None:
        pbone.location = location
        pbone.keyframe_insert(data_path="location", frame=frame)
    if rotation_euler is not None:
        pbone.rotation_mode = "XYZ"
        pbone.rotation_euler = rotation_euler
        pbone.keyframe_insert(data_path="rotation_euler", frame=frame)


def build_animation(armature_obj, action_name, keyframes_fn):
    bpy.context.view_layer.objects.active = armature_obj
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.pose.transforms_clear()
    action = bpy.data.actions.new(action_name)
    armature_obj.animation_data_create()
    armature_obj.animation_data.action = action
    keyframes_fn(armature_obj)
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.pose.transforms_clear()
    bpy.ops.object.mode_set(mode="OBJECT")
    action.use_fake_user = True
    return action


def kf_idle(arm):
    import math
    keyframe_pose_bone(arm, "Chest", 1, location=(0, 0, 0.0))
    keyframe_pose_bone(arm, "Chest", 30, location=(0, 0, 0.012))
    keyframe_pose_bone(arm, "Chest", 60, location=(0, 0, 0.0))


def kf_basic_attack(arm):
    import math
    keyframe_pose_bone(arm, "UpperArm_R", 1, rotation_euler=(0, 0, 0))
    keyframe_pose_bone(arm, "UpperArm_R", 8, rotation_euler=(0, math.radians(-35), 0))
    keyframe_pose_bone(arm, "UpperArm_R", 14, rotation_euler=(0, math.radians(40), 0))
    keyframe_pose_bone(arm, "UpperArm_R", 22, rotation_euler=(0, 0, 0))
    keyframe_pose_bone(arm, "Forearm_R", 1, rotation_euler=(0, 0, 0))
    keyframe_pose_bone(arm, "Forearm_R", 14, rotation_euler=(0, math.radians(-20), 0))
    keyframe_pose_bone(arm, "Forearm_R", 22, rotation_euler=(0, 0, 0))


def kf_hit(arm):
    import math
    keyframe_pose_bone(arm, "Spine", 1, rotation_euler=(0, 0, 0))
    keyframe_pose_bone(arm, "Spine", 5, rotation_euler=(math.radians(12), 0, 0))
    keyframe_pose_bone(arm, "Spine", 14, rotation_euler=(0, 0, 0))


def kf_death(arm):
    import math
    keyframe_pose_bone(arm, "Hips", 1, rotation_euler=(0, 0, 0))
    keyframe_pose_bone(arm, "Hips", 30, rotation_euler=(math.radians(85), 0, 0))
    keyframe_pose_bone(arm, "Hips", 40, rotation_euler=(math.radians(85), 0, 0))


def generate_base():
    reset_scene()
    arm = build_armature("Armature")
    torso = build_torso_mesh("Torso")
    limbs = build_limbs_mesh("Limbs")
    mat_body = make_material("MannequinBody", (0.55, 0.53, 0.5))
    assign_material(torso, mat_body)
    assign_material(limbs, mat_body)
    skin_to_armature(torso, arm)
    skin_to_armature(limbs, arm)

    idle = build_animation(arm, "idle", kf_idle)
    attack = build_animation(arm, "basic_attack", kf_basic_attack)
    hit = build_animation(arm, "hit", kf_hit)
    death = build_animation(arm, "death", kf_death)

    export_glb(os.path.join(OUT_DIR, "mannequin_base.glb"), [arm, torso, limbs], use_animations=True)
    print("[GEN] mannequin_base.glb written, bones=%d actions=%s" % (
        len(arm.data.bones), [a.name for a in bpy.data.actions]))


def generate_chest_alt():
    reset_scene()
    arm = build_armature("Armature")
    chest = add_box("ChestA", (0, 0, 1.22), (0.18, 0.115, 0.13))
    mat_chest = make_material("MannequinChestA", (0.62, 0.32, 0.18))
    assign_material(chest, mat_chest)
    skin_to_armature(chest, arm)
    export_glb(os.path.join(OUT_DIR, "mannequin_chest_a.glb"), [arm, chest], use_animations=False)
    print("[GEN] mannequin_chest_a.glb written, bones=%d" % len(arm.data.bones))


def generate_simple_module(filename, build_fn, color):
    reset_scene()
    obj = build_fn()
    mat = make_material(os.path.splitext(filename)[0] + "Mat", color)
    assign_material(obj, mat)
    export_glb(os.path.join(OUT_DIR, filename), [obj], use_animations=False)
    print("[GEN] %s written" % filename)


def build_helmet_a():
    return add_sphere("HelmetA", (0, 0, 0.14), 0.145)


def build_helmet_b():
    return add_box("HelmetB", (0, 0, 0.15), (0.15, 0.15, 0.16))


def build_weapon_a():
    import mathutils
    obj = add_cylinder_between("WeaponA", (0, 0, 0.0), (0, 0, 0.55), 0.02)
    guard = add_box("WeaponA_guard", (0, 0, 0.0), (0.07, 0.02, 0.02))
    return join_objects([obj, guard], "WeaponA")


def build_cape_a():
    # Character faces -Y in this Blender-space script; after the glTF
    # exporter's +Y-up conversion (gltf_z = -blender_y), "behind" the
    # character is +Z in Godot, which requires a NEGATIVE Blender Y here.
    return add_box("CapeA", (0, -0.06, -0.28), (0.16, 0.02, 0.30))


def main():
    generate_base()
    generate_chest_alt()
    generate_simple_module("mannequin_helmet_a.glb", build_helmet_a, (0.35, 0.35, 0.4))
    generate_simple_module("mannequin_helmet_b.glb", build_helmet_b, (0.4, 0.3, 0.3))
    generate_simple_module("mannequin_weapon_a.glb", build_weapon_a, (0.6, 0.6, 0.65))
    generate_simple_module("mannequin_cape_a.glb", build_cape_a, (0.3, 0.15, 0.18))
    print("[GEN] all mannequin GLBs generated in %s" % OUT_DIR)


main()

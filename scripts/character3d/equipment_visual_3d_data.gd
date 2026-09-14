class_name EquipmentVisual3DData
extends Resource

## Character3D Technical Pilot (Tier 5) — presentation-only data. Maps one
## visual_id to the .glb module Godot should instantiate and where it
## attaches. Deliberately isolated from the 2D CharacterVisualData
## (scripts/data/character_visual_data.gd) and from any productive
## EquipmentData/catalog — this is a technical seam for the pilot, not a
## connection to the real equipment system.

enum Slot { WEAPON, HEAD, CHEST, CAPE }

@export var visual_id: StringName = &""
@export var slot: Slot = Slot.WEAPON
@export var scene_path: String = ""
## Bone this module attaches to, when the slot is a rigid (non-skinned)
## BoneAttachment3D module. Ignored for CHEST (which shares the base
## Skeleton3D directly instead of using a BoneAttachment3D).
@export var socket_bone: StringName = &""
## Name of a base-mesh MeshInstance3D to hide while this module is equipped
## (e.g. "Torso" for a CHEST piece), empty if nothing should be hidden.
@export var hides_base_mesh: StringName = &""

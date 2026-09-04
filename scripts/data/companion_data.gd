class_name CompanionData
extends Resource

@export var companion_id: StringName
@export var display_name: String
@export_multiline var description: String
@export_range(1, 999, 1) var max_hp: int = 40
@export_range(0, 999, 1) var attack: int = 8
@export_range(0, 999, 1) var defense: int = 2
@export var visual_data: CharacterVisualData
@export var passive_id: StringName
@export var passive_name: String
@export_multiline var passive_description: String
@export_range(1.0, 3.0, 0.01) var passive_damage_multiplier: float = 1.0
@export var ability_id: StringName
@export var ability_name: String
@export_multiline var ability_description: String
@export_range(1, 20, 1) var ability_every_actions: int = 3
@export var ability_status_id: StringName
@export_range(1, 10, 1) var ability_status_stacks: int = 1
@export var unlocked_by_default: bool = false
@export var tags: Array[StringName] = []

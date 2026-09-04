class_name EquipmentRuntimeState
extends RefCounted

var combat_start_applied: bool = false
var first_hit_available: bool = true
var sundering_edge_available: bool = true
var guarded_regrowth_available: bool = true


func reset() -> void:
	combat_start_applied = false
	first_hit_available = true
	sundering_edge_available = true
	guarded_regrowth_available = true

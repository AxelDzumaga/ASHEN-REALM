class_name CodexEntry
extends RefCounted

var category: StringName
var id: StringName
var display_name: String
var region_id: StringName


func _init(entry_category: StringName, entry_id: StringName, title: String, entry_region_id: StringName = &"") -> void:
	category = entry_category
	id = entry_id
	display_name = title
	region_id = entry_region_id

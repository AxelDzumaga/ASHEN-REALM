class_name BuildTagReport
extends RefCounted

var tag_sources: Dictionary = {}
var source_tags: Dictionary = {}


func add_source(source_id: StringName, raw_tags: Array[StringName]) -> void:
	if source_id.is_empty():
		return
	var unique_tags: Array[StringName] = []
	for tag: StringName in raw_tags:
		if not tag.is_empty() and tag not in unique_tags:
			unique_tags.append(tag)
	if unique_tags.is_empty():
		return
	var existing_tags: Array = source_tags.get(source_id, [])
	for tag: StringName in unique_tags:
		if tag not in existing_tags:
			existing_tags.append(tag)
		var sources: Array = tag_sources.get(tag, [])
		if source_id not in sources:
			sources.append(source_id)
		tag_sources[tag] = sources
	source_tags[source_id] = existing_tags


func get_count(tag: StringName) -> int:
	return tag_sources.get(tag, []).size()


func has_source(source_id: StringName) -> bool:
	return source_tags.has(source_id)


func get_sources_for_tags(tags: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for tag: StringName in tags:
		for raw_source: Variant in tag_sources.get(tag, []):
			var source_id: StringName = StringName(raw_source)
			if source_id not in result:
				result.append(source_id)
	return result

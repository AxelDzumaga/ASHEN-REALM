class_name CompanionCatalog
extends RefCounted

const EMBER_HOUND_ID: StringName = &"ember_hound"
const DEFAULT_COMPANION_ID: StringName = EMBER_HOUND_ID
const EMBER_HOUND: CompanionData = preload("res://data/companions/ember_hound.tres")

const ALL: Array[CompanionData] = [EMBER_HOUND]


static func get_by_id(companion_id: StringName) -> CompanionData:
	for companion: CompanionData in ALL:
		if companion.companion_id == companion_id:
			return companion
	return null


static func get_all() -> Array[CompanionData]:
	return ALL.duplicate()


static func get_default_unlocked_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for companion: CompanionData in ALL:
		if companion.unlocked_by_default:
			result.append(companion.companion_id)
	return result


static func sanitize_unlocked_ids(raw_ids: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for companion_id: StringName in raw_ids:
		if get_by_id(companion_id) != null and companion_id not in result:
			result.append(companion_id)
	for default_id: StringName in get_default_unlocked_ids():
		if default_id not in result:
			result.append(default_id)
	return result


static func sanitize_equipped_id(companion_id: StringName, unlocked_ids: Array[StringName]) -> StringName:
	if companion_id.is_empty():
		return &""
	if companion_id not in unlocked_ids or get_by_id(companion_id) == null:
		return &""
	return companion_id

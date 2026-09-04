class_name MetaUnlockCatalog
extends RefCounted

const EMBER_FOCUS: StringName = &"ember_focus"
const VIGIL_FOCUS: StringName = &"vigil_focus"
const RENEWAL_FOCUS: StringName = &"renewal_focus"
const DEFAULT_OPTION: StringName = &""

const ALL: Array[Dictionary] = [
	{
		"id": EMBER_FOCUS,
		"display_name": "Senda de Brasa",
		"description": "Inclina levemente las ofertas hacia Ofensiva y Ember Slash.",
		"cost": 45,
		"required_milestone": &"",
		"affinity": UpgradeData.Affinity.OFFENSE,
		"skill_id": &"ember_slash",
		"icon_id": &"attack",
	},
	{
		"id": VIGIL_FOCUS,
		"display_name": "Senda de Vigilia",
		"description": "Inclina levemente las ofertas hacia Defensa y Ashen Guard.",
		"cost": 90,
		"required_milestone": &"first_expedition",
		"affinity": UpgradeData.Affinity.DEFENSE,
		"skill_id": &"ashen_guard",
		"icon_id": &"defense",
	},
	{
		"id": RENEWAL_FOCUS,
		"display_name": "Senda de Renovación",
		"description": "Inclina levemente las ofertas hacia Sustain y Second Wind.",
		"cost": 120,
		"required_milestone": &"first_victory",
		"affinity": UpgradeData.Affinity.SUSTAIN,
		"skill_id": &"second_wind",
		"icon_id": &"health",
	},
]


static func get_all() -> Array[Dictionary]:
	return ALL.duplicate(true)


static func get_by_id(unlock_id: StringName) -> Dictionary:
	for unlock: Dictionary in ALL:
		if unlock["id"] == unlock_id:
			return unlock
	return {}


static func is_owned(profile: ProfileData, unlock_id: StringName) -> bool:
	return unlock_id in profile.owned_meta_unlock_ids


static func meets_condition(profile: ProfileData, unlock_id: StringName) -> bool:
	var unlock: Dictionary = get_by_id(unlock_id)
	if unlock.is_empty():
		return false
	var milestone_id: StringName = unlock["required_milestone"]
	return milestone_id.is_empty() or String(milestone_id) in profile.completed_milestone_ids


static func sanitize_owned_ids(raw_ids: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for unlock_id: StringName in raw_ids:
		if not get_by_id(unlock_id).is_empty() and unlock_id not in result:
			result.append(unlock_id)
	return result


static func sanitize_selected_id(selected_id: StringName, owned_ids: Array[StringName]) -> StringName:
	return selected_id if selected_id in owned_ids and not get_by_id(selected_id).is_empty() else DEFAULT_OPTION


static func get_affinity(unlock_id: StringName) -> UpgradeData.Affinity:
	var unlock: Dictionary = get_by_id(unlock_id)
	return int(unlock.get("affinity", UpgradeData.Affinity.NONE)) as UpgradeData.Affinity


static func get_skill_id(unlock_id: StringName) -> StringName:
	return StringName(get_by_id(unlock_id).get("skill_id", &""))


static func get_display_name(unlock_id: StringName) -> String:
	if unlock_id.is_empty():
		return "Sin enfoque"
	return String(get_by_id(unlock_id).get("display_name", "Sin enfoque"))


static func get_newly_available_for_milestones(profile: ProfileData, milestone_ids: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for unlock: Dictionary in ALL:
		var unlock_id: StringName = unlock["id"]
		var required: StringName = unlock["required_milestone"]
		if not required.is_empty() and required in milestone_ids and not is_owned(profile, unlock_id):
			result.append(unlock_id)
	return result

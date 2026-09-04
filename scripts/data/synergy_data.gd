class_name SynergyData
extends Resource

enum ActivationMode {
	ALL_REQUIREMENTS,
	SOURCES_OR_TAGS,
}

@export var synergy_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon_id: StringName = &"synergy"
@export var category: StringName
@export var activation_mode: ActivationMode = ActivationMode.ALL_REQUIREMENTS
@export var required_tags: Array[StringName] = []
@export var required_counts: Array[int] = []
@export var required_source_ids: Array[StringName] = []
@export_range(1, 20, 1) var minimum_distinct_sources: int = 1
@export_multiline var requirements_text: String
@export var effect_id: StringName
@export var effect_value: float = 0.0
@export var secondary_value: float = 0.0
@export_multiline var effect_text: String
@export var tags: Array[StringName] = []


func has_valid_requirements() -> bool:
	return (
		not synergy_id.is_empty()
		and not effect_id.is_empty()
		and required_tags.size() == required_counts.size()
		and (not required_tags.is_empty() or not required_source_ids.is_empty())
	)

class_name EncounterTemplateData
extends Resource

enum DuplicatePolicy {
	DISALLOW,
	ALLOW,
}

@export var id: StringName
@export_range(1, 3, 1) var slots: int = 1
@export var roles: Array[int] = []
@export_range(0, 100, 1) var minimum_progress_percent: int = 0
@export_range(0, 100, 1) var maximum_progress_percent: int = 100
@export_range(1, 20, 1) var minimum_budget: int = 1
@export_range(1, 1000, 1) var weight: int = 100
@export var duplicate_policy: DuplicatePolicy = DuplicatePolicy.DISALLOW
@export var tags: Array[StringName] = []
@export var compatible_biome_ids: Array[StringName] = []


func is_eligible(biome_id: StringName, progress_percent: int, budget: int) -> bool:
	return (
		not id.is_empty()
		and slots >= 1
		and slots <= 3
		and roles.size() == slots
		and progress_percent >= minimum_progress_percent
		and progress_percent <= maximum_progress_percent
		and budget >= minimum_budget
		and (compatible_biome_ids.is_empty() or biome_id in compatible_biome_ids)
	)

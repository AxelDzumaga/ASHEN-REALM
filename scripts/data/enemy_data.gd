class_name EnemyData
extends Resource

@export var id: StringName
@export var display_name: String = "Enemigo"
@export var visual: CharacterVisualData
@export var ai_profile: EnemyAIData
@export var boss_encounter: BossEncounterData
@export_range(1, 999) var max_health: int = 30
@export_range(1, 999) var attack: int = 8
@export_range(0, 999) var defense: int = 2
@export_range(0, 20, 1) var encounter_cost: int = 0
@export_group("Afinidades (wireadas en combat.gd — ver AffinityResolver)")
@export var primary_damage_type: StringName = &"physical"
@export var resistance_tags: Array[StringName] = []
@export var weakness_tags: Array[StringName] = []
@export var immunity_tags: Array[StringName] = []


func get_affinity_summary() -> String:
	var parts: Array[String] = []
	if not resistance_tags.is_empty():
		parts.append("RESISTE: %s" % _affinity_labels(resistance_tags))
	if not weakness_tags.is_empty():
		parts.append("DÉBIL: %s" % _affinity_labels(weakness_tags))
	if not immunity_tags.is_empty():
		parts.append("INMUNE: %s" % _affinity_labels(immunity_tags))
	return " · ".join(parts) if not parts.is_empty() else "AFINIDADES: SIN DATOS RELEVANTES"


func _affinity_labels(values: Array[StringName]) -> String:
	var labels: Array[String] = []
	for value: StringName in values:
		labels.append(AffinityResolver.get_type_label(value))
	return ", ".join(labels)

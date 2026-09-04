class_name EncounterCatalog
extends RefCounted

const SOLO_ASSAULT: EncounterTemplateData = preload("res://data/encounter_templates/solo_assault.tres")
const SOLO_BRUTE: EncounterTemplateData = preload("res://data/encounter_templates/solo_brute.tres")
const SOLO_DEFENDER: EncounterTemplateData = preload("res://data/encounter_templates/solo_defender.tres")
const SOLO_SUPPORT: EncounterTemplateData = preload("res://data/encounter_templates/solo_support.tres")
const DUO_ASSAULT: EncounterTemplateData = preload("res://data/encounter_templates/duo_assault.tres")
const ASSAULT_SUPPORT: EncounterTemplateData = preload("res://data/encounter_templates/assault_support.tres")
const DEFENDER_ASSAULT: EncounterTemplateData = preload("res://data/encounter_templates/defender_assault.tres")
const BRUTE_ASSAULT: EncounterTemplateData = preload("res://data/encounter_templates/brute_assault.tres")
const ASSAULT_ASSAULT_SUPPORT: EncounterTemplateData = preload("res://data/encounter_templates/assault_assault_support.tres")
const DEFENDER_ASSAULT_SUPPORT: EncounterTemplateData = preload("res://data/encounter_templates/defender_assault_support.tres")
const BRUTE_SUPPORT: EncounterTemplateData = preload("res://data/encounter_templates/brute_support.tres")
const DEFENDER_BRUTE: EncounterTemplateData = preload("res://data/encounter_templates/defender_brute.tres")

const ALL: Array[EncounterTemplateData] = [
	SOLO_ASSAULT,
	SOLO_BRUTE,
	SOLO_DEFENDER,
	SOLO_SUPPORT,
	DUO_ASSAULT,
	ASSAULT_SUPPORT,
	DEFENDER_ASSAULT,
	BRUTE_ASSAULT,
	ASSAULT_ASSAULT_SUPPORT,
	DEFENDER_ASSAULT_SUPPORT,
	BRUTE_SUPPORT,
	DEFENDER_BRUTE,
]


static func get_all() -> Array[EncounterTemplateData]:
	return ALL.duplicate()


static func get_by_id(template_id: StringName) -> EncounterTemplateData:
	for template: EncounterTemplateData in ALL:
		if template.id == template_id:
			return template
	return null

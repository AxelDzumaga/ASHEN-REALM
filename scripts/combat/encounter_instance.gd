class_name EncounterInstance
extends RefCounted

var template: EncounterTemplateData
var enemies: Array[EnemyData] = []
var total_cost: int = 0
var progress_percent: int = 0
var signature: StringName


func refresh_signature() -> void:
	var ids: Array[String] = []
	for enemy: EnemyData in enemies:
		if enemy != null:
			ids.append(String(enemy.id))
	ids.sort()
	signature = StringName("|".join(ids))

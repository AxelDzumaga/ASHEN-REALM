class_name EquipmentSetResolver
extends RefCounted

## Equipment 2.0 Fase 1 — foundation de set bonus, únicamente 2 piezas (4/6
## piezas quedan fuera de scope de esta etapa). ashen_warden_set es el
## piloto real: wardens_edge (weapon) y warden_plate (chest, ex-armor) ya
## traían set_id="ashen_warden_set" en el catálogo desde antes de esta
## feature — lo que no existía era ningún resolver que lo consumiera.
const ASHEN_WARDEN_SET: StringName = &"ashen_warden_set"

## set_id -> passive_effect_id otorgado con 2+ piezas equipadas de ese set.
## Reutiliza el mecanismo de pasivos por ítem ya existente en
## EquipmentEffectResolver/run.equipment_passive_ids — no es un sistema de
## bonus paralelo, es el mismo dispatch con un id más en la lista.
const SET_BONUS_PASSIVES: Dictionary[StringName, StringName] = {
	ASHEN_WARDEN_SET: &"warden_set_resonance",
}


## Muta run.equipment_passive_ids in-place. equipped_set_ids es la lista de
## set_id (con repetición) de todos los ítems equipados en los 5 slots
## activos — normalmente construida en RunState.apply_permanent_upgrades().
static func apply_set_bonuses(run: RunState, equipped_set_ids: Array[StringName]) -> void:
	var counts: Dictionary[StringName, int] = {}
	for set_id: StringName in equipped_set_ids:
		if set_id.is_empty():
			continue
		counts[set_id] = int(counts.get(set_id, 0)) + 1
	for set_id: StringName in counts:
		if int(counts[set_id]) < 2:
			continue
		var passive_id: StringName = SET_BONUS_PASSIVES.get(set_id, &"")
		if not passive_id.is_empty() and passive_id not in run.equipment_passive_ids:
			run.equipment_passive_ids.append(passive_id)


static func get_equipped_piece_count(set_id: StringName, equipped_set_ids: Array[StringName]) -> int:
	if set_id.is_empty():
		return 0
	var count: int = 0
	for candidate: StringName in equipped_set_ids:
		if candidate == set_id:
			count += 1
	return count

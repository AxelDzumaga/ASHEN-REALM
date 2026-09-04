class_name TreasureChoiceResolver
extends RefCounted

const KIND_BOON := "boon"
const KIND_AUGMENT := "augment"
const KIND_ASH := "ash"
const KIND_RECOVERY := "recovery"
const KIND_VITALITY := "vitality"
const SAFE_ASH := 25
const FALLBACK_ASH := 15
const RECOVERY_HEAL := 25


static func generate_offers(run: RunState) -> Array[Dictionary]:
	if run == null:
		return []
	if run.pending_treasure_position == run.board_position and not run.pending_treasure_offers.is_empty():
		return run.pending_treasure_offers.duplicate(true)
	var offers: Array[Dictionary] = []
	var boon_seed: int = BuildRewardResolver.make_seed(run, &"treasure_boon", run.treasures_found)
	var boons: Array[UpgradeData] = BuildRewardResolver.generate_boon_options(run, false, boon_seed)
	if not boons.is_empty():
		var boon: UpgradeData = boons[0]
		offers.append({
			"id": "boon:%s" % boon.id, "kind": KIND_BOON, "reward_id": String(boon.id),
			"label": "BRASA DE BUILD", "description": "%s · %s · %s" % [UpgradeCatalog.get_rarity_name(boon.rarity), UpgradeCatalog.get_affinity_name(boon.affinity), boon.display_name],
		})
	var augment_seed: int = BuildRewardResolver.make_seed(run, &"treasure_augment", run.treasures_found)
	var augments: Array[SkillAugmentData] = BuildRewardResolver.generate_augment_options(run, augment_seed)
	if not augments.is_empty():
		var augment: SkillAugmentData = augments[0]
		offers.append({
			"id": "augment:%s" % augment.id, "kind": KIND_AUGMENT, "reward_id": String(augment.id),
			"label": "TÉCNICA EQUIPADA", "description": "%s · %s" % [augment.display_name, augment.description],
		})
	else:
		offers.append({"id": "recovery", "kind": KIND_RECOVERY, "reward_id": "", "label": "RESERVA CURATIVA", "description": "Recuperás hasta %d de Vida" % RECOVERY_HEAL})
	offers.append({"id": "ash", "kind": KIND_ASH, "reward_id": "", "label": "CENIZA SEGURA", "description": "+%d de Ceniza para esta partida" % SAFE_ASH})
	# Pool de boons agotado: usa un efecto de Treasure ya existente, no contenido nuevo.
	if offers.size() == 2:
		offers.push_front({"id": "vitality", "kind": KIND_VITALITY, "reward_id": "", "label": "BRASA VITAL", "description": "+6 de Vida máxima y actual"})
	run.pending_treasure_position = run.board_position
	run.pending_treasure_offers = offers.duplicate(true)
	return offers


static func apply_offer(run: RunState, offer: Dictionary) -> Dictionary:
	if run == null or run.board_position in run.resolved_treasure_positions:
		return {"applied": false, "text": "El tesoro ya fue reclamado.", "kind": "none"}
	var kind: String = String(offer.get("kind", ""))
	var text: String = ""
	match kind:
		KIND_BOON:
			var boon: UpgradeData = UpgradeCatalog.get_by_id(StringName(offer.get("reward_id", "")))
			if boon == null or run.get_boon_count(boon.id) >= boon.max_stacks:
				run.run_ash += FALLBACK_ASH
				kind = KIND_ASH
				text = "+%d de Ceniza (recompensa agotada)" % FALLBACK_ASH
			else:
				run.add_boon(boon.id)
				text = "Bendición obtenida: %s" % boon.display_name
		KIND_AUGMENT:
			var augment: SkillAugmentData = SkillAugmentCatalog.get_by_id(StringName(offer.get("reward_id", "")))
			if augment == null or run.get_skill_augment_count(augment.id) >= augment.max_stacks:
				run.run_ash += FALLBACK_ASH
				kind = KIND_ASH
				text = "+%d de Ceniza (aumento agotado)" % FALLBACK_ASH
			else:
				run.add_skill_augment(augment.id)
				text = "Aumento obtenido: %s" % augment.display_name
		KIND_ASH:
			run.run_ash += SAFE_ASH
			text = "+%d de Ceniza para esta partida" % SAFE_ASH
		KIND_RECOVERY:
			var healed: int = run.heal(RECOVERY_HEAL)
			text = "Recuperaste %d de Vida" % healed
		KIND_VITALITY:
			run.max_health += 6
			run.heal_structural(6)
			text = "+6 de Vida máxima y actual"
		_:
			return {"applied": false, "text": "Recompensa inválida.", "kind": "none"}
	run.resolved_treasure_positions.append(run.board_position)
	run.pending_treasure_position = -1
	run.pending_treasure_offers.clear()
	run.treasures_found += 1
	return {"applied": true, "text": text, "kind": kind}

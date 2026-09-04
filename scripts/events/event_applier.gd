class_name EventApplier
extends RefCounted

## Placeholder de balance — confirmado dentro del rango 10%-20% aprobado,
## ajustable en la pasada de balance final. Ver docs/refinement_extension_and_event_drops_spec.md.
const MATERIAL_DROP_CHANCE: float = 0.15
const MATERIAL_DROP_MIN: int = 1
const MATERIAL_DROP_MAX: int = 2


static func apply(event: EventData, choose_option_a: bool, run: RunState) -> String:
	return String(apply_detailed(event, choose_option_a, run).get("text", "Nada cambia."))


static func apply_detailed(event: EventData, choose_option_a: bool, run: RunState) -> Dictionary:
	if run != null and run.board_position in run.resolved_event_positions:
		return {"applied": false, "text": "El evento ya fue resuelto.", "reward_type": "none"}
	if not EventResolver.can_choose(event, choose_option_a, run):
		return {"applied": false, "text": "La opción ya no está disponible.", "reward_type": "none"}
	var health_delta: int = event.option_a_health_delta if choose_option_a else event.option_b_health_delta
	var max_health_delta: int = event.option_a_max_health_delta if choose_option_a else event.option_b_max_health_delta
	var attack_delta: int = event.option_a_attack_delta if choose_option_a else event.option_b_attack_delta
	var defense_delta: int = event.option_a_defense_delta if choose_option_a else event.option_b_defense_delta
	var run_ash_delta: int = event.option_a_run_ash_delta if choose_option_a else event.option_b_run_ash_delta
	var effect_text: String = event.option_a_effect_text if choose_option_a else event.option_b_effect_text
	var reward: EventData.OptionReward = event.option_a_reward if choose_option_a else event.option_b_reward
	var set_flags: Array[StringName] = event.option_a_set_flag_ids if choose_option_a else event.option_b_set_flag_ids

	run.max_health = maxi(1, run.max_health + max_health_delta)
	run.attack = maxi(0, run.attack + attack_delta)
	run.defense = maxi(0, run.defense + defense_delta)
	run.run_ash = maxi(0, run.run_ash + run_ash_delta)
	if health_delta >= 0:
		run.heal(health_delta)
	else:
		run.current_health = maxi(1, run.current_health + health_delta)
	run.current_health = clampi(run.current_health, 1, run.max_health)
	for flag_id: StringName in set_flags:
		run.add_event_flag(flag_id)
	var reward_text: String = ""
	var reward_type: String = "none"
	if reward == EventData.OptionReward.BUILD_BOON:
		var boons: Array[UpgradeData] = BuildRewardResolver.generate_boon_options(run, false, BuildRewardResolver.make_seed(run, event.option_id(choose_option_a), run.events_resolved))
		if not boons.is_empty():
			var boon: UpgradeData = boons[0]
			run.add_boon(boon.id)
			reward_text = "Bendición: %s" % boon.display_name
			reward_type = "boon"
	elif reward == EventData.OptionReward.BUILD_AUGMENT:
		var augments: Array[SkillAugmentData] = BuildRewardResolver.generate_augment_options(run, BuildRewardResolver.make_seed(run, event.option_id(choose_option_a), run.events_resolved))
		if not augments.is_empty():
			var augment: SkillAugmentData = augments[0]
			run.add_skill_augment(augment.id)
			reward_text = "Aumento: %s" % augment.display_name
			reward_type = "augment"
	var material_text: String = _roll_material_drop(event, choose_option_a, run)
	var parts: Array[String] = []
	if not effect_text.is_empty():
		parts.append(effect_text)
	if not reward_text.is_empty():
		parts.append(reward_text)
	if not material_text.is_empty():
		parts.append(material_text)
	if event.id not in run.seen_event_ids:
		run.seen_event_ids.append(event.id)
	run.resolved_event_positions.append(run.board_position)
	return {"applied": true, "text": " · ".join(parts) if not parts.is_empty() else "Nada cambia.", "reward_type": reward_type, "flags": set_flags}


## Drop silencioso de moneda de bioma — Event nunca otorga equipment/cofres,
## solo esta moneda, determinista por seed como el resto de las recompensas de
## evento (mismo patrón que ChestResolver/BuildRewardResolver). Se acumula en
## el RunState y se deposita recién en Results, junto con el resto del loot.
static func _roll_material_drop(event: EventData, choose_option_a: bool, run: RunState) -> String:
	if run == null or run.biome_data == null:
		return ""
	var context := StringName("%s:material" % String(event.option_id(choose_option_a)))
	var rng := RandomNumberGenerator.new()
	rng.seed = BuildRewardResolver.make_seed(run, context, run.events_resolved)
	if rng.randf() >= MATERIAL_DROP_CHANCE:
		return ""
	var amount: int = rng.randi_range(MATERIAL_DROP_MIN, MATERIAL_DROP_MAX)
	run.biome_material_earned += amount
	var material_name: String = run.biome_data.material_name
	if material_name.is_empty():
		material_name = "Material de Bioma"
	return "%s +%d" % [material_name, amount]

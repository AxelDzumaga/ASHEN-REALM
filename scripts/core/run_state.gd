class_name RunState
extends RefCounted

## preload (no class_name directo): scripts class_name recién creados
## necesitan que el editor escanee el global class cache al menos una vez;
## en este proyecto se corre siempre headless por CLI, así que preload
## evita depender de ese timing.
const _EquipmentSetResolver = preload("res://scripts/equipment/equipment_set_resolver.gd")

const BASE_MAX_HEALTH := 100
const BASE_CURRENT_HEALTH_OFFSET := 20
const BASE_ATTACK := 20
const BASE_DEFENSE := 5
const NORMAL_COMBAT_ASH := 5
const ELITE_COMBAT_ASH := 10
const BOSS_VICTORY_ASH := 50

var started_at_unix: int
var biome_id: StringName
var biome_data: BiomeData
var board_seed: int = BoardGenerator.NO_SEED
var board_tile_sequence: Array[int] = []
var last_normal_encounter_signature: StringName = &""
var biome_intro_shown: bool = false
var active_skill_id: StringName = ActiveSkillCatalog.DEFAULT_SKILL_ID
var equipped_skill_ids: Array[StringName] = []
var equipped_companion_id: StringName = &""
var player_name: String = "Ashen Wanderer"
var max_health: int = BASE_MAX_HEALTH
var current_health: int = BASE_MAX_HEALTH - BASE_CURRENT_HEALTH_OFFSET
var attack: int = BASE_ATTACK
var defense: int = BASE_DEFENSE
var board_position: int = 0
var board_locked: bool = false
## Estado transitorio de agency; vive solo durante la run activa y no migra perfil.
var route_choice_count: int = 0
var route_option_a: int = -1
var route_option_b: int = -1
var chosen_destination: int = -1
var chosen_tile_type: int = -1
var route_choice_cooldown: bool = false
var combats_won: int = 0
var elites_won: int = 0
var events_resolved: int = 0
var treasures_found: int = 0
## Memoria local de decisiones narrativas; nunca se copia a ProfileData.
var event_flag_ids: Array[StringName] = []
var seen_event_ids: Array[StringName] = []
var resolved_event_positions: Array[int] = []
var resolved_treasure_positions: Array[int] = []
var pending_treasure_position: int = -1
var pending_treasure_offers: Array[Dictionary] = []
var upgrades_obtained: int = 0
var run_completed: bool = false
var run_ash: int = 0
var biome_material_earned: int = 0
var rewards_deposited: bool = false
## Resumen de progresión permanente rellenado al depositar Results.
var player_xp_earned: int = 0
var player_level_before: int = PlayerProgressionConfig.START_LEVEL
var player_level_after: int = PlayerProgressionConfig.START_LEVEL
var player_xp_before: int = 0
var player_xp_after: int = 0
var player_levels_gained: int = 0
var completed_milestone_ids_this_run: Array[StringName] = []
var milestone_ash_awarded: int = 0
var loot_rolled: bool = false
var pending_loot_id: String = ""
var duplicate_converted_id: StringName = &""
var duplicate_ash_awarded: int = 0
var boss_reward_id: StringName = &""
var boss_reward_applied: bool = false
var boss_chest_id: StringName = &""
var boss_chest_awarded: bool = false
var guardian_sigils_awarded: int = 0
var loot_minimum_rarity: EquipmentData.Rarity = EquipmentData.Rarity.COMMON
var loot_rarity_upgrades: int = 0
var active_boons: Dictionary[StringName, int] = {}
var skill_augments: Dictionary[StringName, int] = {}
var active_synergy_ids: Array[StringName] = []
var activated_synergy_ids: Array[StringName] = []
var pending_synergy_announcement_ids: Array[StringName] = []
var upgrade_rerolls: int = 2
var reward_offers_generated: int = 0
var phoenix_blood_empowered: bool = false
## Recurso transitorio de la run; no se persiste en ProfileData ni requiere migración.
var combat_energy_carryover: int = 0
var run_level: int = RunLevelConfig.START_LEVEL
var current_xp: int = 0
var total_xp_gained: int = 0
var pending_level_ups: int = 0
var level_up_choices_generated: int = 0
var pending_level_up_option_ids: Array[StringName] = []
var run_level_upgrade_stacks: Dictionary[StringName, int] = {}
var equipped_weapon_id: StringName = &""
var equipped_armor_id: StringName = &""
var owned_equipment_ids_at_start: Array[String] = []
var equipment_passive_ids: Array[StringName] = []
var equipment_crit_chance: float = 0.0
var equipment_crit_damage_bonus: float = 0.0
var equipment_ember_gain_bonus: float = 0.0
var equipment_healing_power_bonus: float = 0.0
var equipment_skill_damage_bonus: float = 0.0
## Equipment 2.0 Fase 1 — affinity_id (genérico, ver AffinityResolver) -> %
## de resistencia acumulada de CHEST/HEAD/CAPE/RELIC equipados. Consumido
## por combat.gd:_resolve_elemental_damage cuando el jugador es el target.
var equipment_resistance_bonuses: Dictionary[StringName, float] = {}
var telemetry_started: bool = false
var telemetry_finished: bool = false
var telemetry_started_unix: int = 0
var telemetry_skill_uses: Dictionary[String, int] = {}
var telemetry_synergy_ids: Array[StringName] = []
var telemetry_last_boss_id: StringName = &""
var telemetry_boss_phase_reached: int = 0
var starting_option_id: StringName = &""


func get_reward_affinity_count(affinity: UpgradeData.Affinity) -> int:
	var total: int = get_affinity_count(affinity)
	if MetaUnlockCatalog.get_affinity(starting_option_id) == affinity:
		total += 1
	return total


func _init() -> void:
	started_at_unix = int(Time.get_unix_time_from_system())


func heal(amount: int) -> int:
	var equipment_multiplier: float = 1.0 + equipment_healing_power_bonus
	var effective_amount: int = BiomeModifierResolver.effective_healing(amount, biome_data, equipment_multiplier)
	return heal_structural(effective_amount)


func has_event_flag(flag_id: StringName) -> bool:
	return flag_id in event_flag_ids


func add_event_flag(flag_id: StringName) -> void:
	if not flag_id.is_empty() and flag_id not in event_flag_ids:
		event_flag_ids.append(flag_id)


func heal_structural(amount: int) -> int:
	var previous_health: int = current_health
	current_health = mini(current_health + maxi(0, amount), max_health)
	return current_health - previous_health


func get_xp_to_next_level() -> int:
	return RunLevelConfig.xp_required_for_level(run_level)


func add_run_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	total_xp_gained += amount
	current_xp += amount
	var levels_gained: int = 0
	while run_level < RunLevelConfig.MAX_RUN_LEVEL:
		var requirement: int = get_xp_to_next_level()
		if requirement <= 0 or current_xp < requirement:
			break
		current_xp -= requirement
		run_level += 1
		pending_level_ups += 1
		levels_gained += 1
	if run_level >= RunLevelConfig.MAX_RUN_LEVEL:
		current_xp = 0
	return levels_gained


func get_run_level_upgrade_count(upgrade_id: StringName) -> int:
	return int(run_level_upgrade_stacks.get(upgrade_id, 0))


func record_run_level_upgrade(upgrade: UpgradeData) -> void:
	if upgrade == null:
		return
	var count: int = get_run_level_upgrade_count(upgrade.id)
	run_level_upgrade_stacks[upgrade.id] = mini(upgrade.max_stacks, count + 1)
	upgrades_obtained += 1
	pending_level_ups = maxi(0, pending_level_ups - 1)
	pending_level_up_option_ids.clear()
	recalculate_synergies()


func add_boon(boon_id: StringName, amount: int = 1) -> int:
	if boon_id.is_empty() or amount <= 0:
		return get_boon_count(boon_id)
	var boon: UpgradeData = UpgradeCatalog.get_by_id(boon_id)
	var maximum: int = boon.max_stacks if boon != null else 99
	active_boons[boon_id] = mini(maximum, get_boon_count(boon_id) + amount)
	recalculate_synergies()
	return active_boons[boon_id]


func next_reward_offer_seed(context: StringName) -> int:
	var seed: int = BuildRewardResolver.make_seed(self, context, reward_offers_generated)
	reward_offers_generated += 1
	return seed


func get_boon_count(boon_id: StringName) -> int:
	return int(active_boons.get(boon_id, 0))


func add_skill_augment(augment_id: StringName, amount: int = 1) -> int:
	var augment: SkillAugmentData = SkillAugmentCatalog.get_by_id(augment_id)
	if augment == null or augment.skill_id not in equipped_skill_ids or amount <= 0:
		return get_skill_augment_count(augment_id)
	var next_count: int = mini(augment.max_stacks, get_skill_augment_count(augment_id) + amount)
	skill_augments[augment_id] = next_count
	recalculate_synergies()
	return next_count


func recalculate_synergies() -> Array[StringName]:
	var newly_activated: Array[StringName] = SynergyResolver.recalculate(self)
	if telemetry_started:
		for synergy_id: StringName in newly_activated:
			TelemetryManager.track_synergy_activated(self, synergy_id)
	return newly_activated


func consume_pending_synergy_announcements() -> Array[StringName]:
	var result: Array[StringName] = pending_synergy_announcement_ids.duplicate()
	pending_synergy_announcement_ids.clear()
	return result


func get_skill_augment_count(augment_id: StringName) -> int:
	return int(skill_augments.get(augment_id, 0))


func get_affinity_count(affinity: UpgradeData.Affinity) -> int:
	var total: int = 0
	for boon_id: StringName in active_boons:
		var upgrade: UpgradeData = UpgradeCatalog.get_by_id(boon_id)
		if upgrade != null and upgrade.category == UpgradeData.Category.PASSIVE and upgrade.affinity == affinity:
			total += get_boon_count(boon_id)
	return total


func apply_permanent_upgrades(profile: ProfileData) -> void:
	equipped_weapon_id = &""
	equipped_armor_id = &""
	equipment_passive_ids.clear()
	equipment_crit_chance = 0.0
	equipment_crit_damage_bonus = 0.0
	equipment_ember_gain_bonus = 0.0
	equipment_healing_power_bonus = 0.0
	equipment_skill_damage_bonus = 0.0
	equipment_resistance_bonuses.clear()
	max_health = BASE_MAX_HEALTH + PermanentUpgradeConfig.get_total_bonus(
		PermanentUpgradeConfig.UpgradeType.VITALITY,
		profile.permanent_health_level,
	)
	current_health = max_health - BASE_CURRENT_HEALTH_OFFSET
	attack = BASE_ATTACK + PermanentUpgradeConfig.get_total_bonus(
		PermanentUpgradeConfig.UpgradeType.MIGHT,
		profile.permanent_attack_level,
	)
	defense = BASE_DEFENSE + PermanentUpgradeConfig.get_total_bonus(
		PermanentUpgradeConfig.UpgradeType.GUARD,
		profile.permanent_defense_level,
	)
	var equipped_ids: Array[String] = [profile.equipped_weapon_id, profile.equipped_armor_id]
	for slot_name: String in profile.equipped_slots:
		equipped_ids.append(profile.equipped_slots[slot_name])
	var equipped_set_ids: Array[StringName] = []
	for equipped_id: String in equipped_ids:
		_apply_equipped_item(equipped_id, int(profile.equipment_refinement.get(equipped_id, 0)))
		var equipped_item: EquipmentData = EquipmentCatalog.get_by_id(equipped_id)
		if equipped_item != null and not equipped_item.set_id.is_empty():
			equipped_set_ids.append(equipped_item.set_id)
	_EquipmentSetResolver.apply_set_bonuses(self, equipped_set_ids)
	current_health = maxi(1, max_health - BASE_CURRENT_HEALTH_OFFSET)


func prepare_loot(is_victory: bool) -> void:
	if loot_rolled:
		return
	loot_rolled = true
	var item: EquipmentData = EquipmentCatalog.roll_run_loot(
		is_victory,
		loot_minimum_rarity,
		loot_rarity_upgrades,
		owned_equipment_ids_at_start,
		biome_id,
	)
	pending_loot_id = "" if item == null else String(item.id)


func _apply_equipped_item(equipment_id: String, refinement_level: int = 0) -> void:
	var item: EquipmentData = EquipmentCatalog.get_by_id(equipment_id)
	if item == null:
		return
	max_health += item.max_health_bonus
	attack += item.attack_bonus
	defense += item.defense_bonus
	# Refinamiento: WEAPON aporta a ATQ, el resto de los 5 slots (CHEST/HEAD/
	# CAPE/RELIC) aporta a DEF — mismo criterio binario que ya existía para
	# WEAPON/ARMOR, generalizado. INITIAL TUNING, sin balance final.
	var refinement_bonus: int = RefinementConfig.get_primary_bonus(refinement_level)
	if item.slot == EquipmentData.Slot.WEAPON:
		attack += refinement_bonus
		equipped_weapon_id = item.id
	else:
		defense += refinement_bonus
		if item.slot == EquipmentData.Slot.CHEST:
			equipped_armor_id = item.id
	if not item.resistance_affinity_id.is_empty():
		equipment_resistance_bonuses[item.resistance_affinity_id] = float(equipment_resistance_bonuses.get(item.resistance_affinity_id, 0.0)) + item.resistance_bonus
	equipment_crit_chance += item.crit_chance
	equipment_crit_damage_bonus += item.crit_damage_bonus
	equipment_ember_gain_bonus += item.ember_gain_bonus
	equipment_healing_power_bonus += item.healing_power_bonus
	equipment_skill_damage_bonus += item.skill_damage_bonus
	if not item.passive_effect_id.is_empty() and item.passive_effect_id not in equipment_passive_ids:
		equipment_passive_ids.append(item.passive_effect_id)


func has_equipment_passive(passive_id: StringName) -> bool:
	return passive_id in equipment_passive_ids


func record_normal_combat_victory() -> void:
	combats_won += 1
	run_ash += NORMAL_COMBAT_ASH


func record_elite_combat_victory() -> void:
	combats_won += 1
	elites_won += 1
	run_ash += ELITE_COMBAT_ASH


func record_boss_victory() -> void:
	run_completed = true
	run_ash += BOSS_VICTORY_ASH

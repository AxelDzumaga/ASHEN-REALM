extends Node

const SCHEMA_VERSION := 7
const DEFAULT_RUNS := 1000
const BASE_SEED := 620062
const MAX_COMBAT_TURNS := 80
const HEAL_TILE_AMOUNT := 20
const POLICIES: Array[StringName] = [&"random", &"aggressive", &"defensive", &"tactical"]
const BIOMES: Array[StringName] = [&"ashen_wastes", &"ember_marsh"]

var _runs_per_configuration: int = DEFAULT_RUNS
var _base_seed: int = BASE_SEED
var _output_path: String = "res://build/stage62/runs.jsonl"
var _mode: StringName = &"simulate"
var _reward_rules: StringName = &"candidate"
var _plan_sequence: int = 0
var _experiment_label: String = "baseline_65"
var _rarity_mode: StringName = &"renormalized"
var _board_agency: bool = true
var _routing_policy: StringName = &"matched"
var _branch_percent: int = RouteChoiceResolver.DEFAULT_BRANCH_PERCENT
var _event_treasure_agency: bool = true
var _event_policy: StringName = &"matched"
var _treasure_policy: StringName = &"matched"
var _starting_option_id: StringName = &""
var _balance_overrides: Dictionary = {"effect_scales": {}, "effect_caps": {}, "max_effect_stacks": {}, "skill_costs": {}, "status_duration_bonuses": {}, "status_stack_bonuses": {}, "energy_carryover_fraction": 0.2, "energy_carryover_cap": 0, "burning_strike_burn_stacks": 1, "inferno_burn_bonus_stacks": 1, "warden_defense_delta": 0, "disable_companion": false, "disable_companion_burn": false}


func _ready() -> void:
	_parse_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_path.get_base_dir()))
	var exit_code: int = _run_tests() if _mode == &"test" else _run_simulation()
	get_tree().quit(exit_code)


func _parse_args() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="):
			_runs_per_configuration = maxi(1, int(argument.get_slice("=", 1)))
		elif argument.begins_with("--seed="):
			_base_seed = int(argument.get_slice("=", 1))
		elif argument.begins_with("--output="):
			_output_path = argument.get_slice("=", 1)
		elif argument.begins_with("--mode="):
			_mode = StringName(argument.get_slice("=", 1))
		elif argument.begins_with("--reward-rules="):
			_reward_rules = StringName(argument.get_slice("=", 1))
		elif argument.begins_with("--experiment="):
			_experiment_label = argument.get_slice("=", 1)
		elif argument.begins_with("--boon-rarity="):
			_rarity_mode = StringName(argument.get_slice("=", 1))
		elif argument.begins_with("--board-agency="):
			_board_agency = argument.get_slice("=", 1).to_lower() not in ["off", "false", "0"]
		elif argument.begins_with("--routing-policy="):
			_routing_policy = StringName(argument.get_slice("=", 1))
		elif argument.begins_with("--branch-percent="):
			_branch_percent = clampi(int(argument.get_slice("=", 1)), 0, 100)
		elif argument.begins_with("--event-treasure-agency="):
			_event_treasure_agency = argument.get_slice("=", 1).to_lower() not in ["off", "false", "0"]
		elif argument.begins_with("--event-policy="):
			_event_policy = StringName(argument.get_slice("=", 1))
		elif argument.begins_with("--treasure-policy="):
			_treasure_policy = StringName(argument.get_slice("=", 1))
		elif argument.begins_with("--starting-option="):
			var requested_option := StringName(argument.get_slice("=", 1))
			_starting_option_id = requested_option if not MetaUnlockCatalog.get_by_id(requested_option).is_empty() else &""
		elif argument.begins_with("--basic-energy="):
			_balance_overrides["basic_energy"] = int(argument.get_slice("=", 1))
		elif argument.begins_with("--skill-cost="):
			_parse_override_pairs(argument.get_slice("=", 1), "skill_costs", false)
		elif argument.begins_with("--status-duration-bonus="):
			_parse_override_pairs(argument.get_slice("=", 1), "status_duration_bonuses", false)
		elif argument.begins_with("--status-stack-bonus="):
			_parse_override_pairs(argument.get_slice("=", 1), "status_stack_bonuses", false)
		elif argument.begins_with("--energy-carryover="):
			_balance_overrides["energy_carryover_fraction"] = clampf(float(argument.get_slice("=", 1)), 0.0, 1.0)
		elif argument.begins_with("--energy-carryover-cap="):
			_balance_overrides["energy_carryover_cap"] = maxi(0, int(argument.get_slice("=", 1)))
		elif argument.begins_with("--burning-strike-burn="):
			_balance_overrides["burning_strike_burn_stacks"] = maxi(0, int(argument.get_slice("=", 1)))
		elif argument.begins_with("--inferno-burn-bonus="):
			_balance_overrides["inferno_burn_bonus_stacks"] = maxi(0, int(argument.get_slice("=", 1)))
		elif argument.begins_with("--warden-defense-delta="):
			_balance_overrides["warden_defense_delta"] = int(argument.get_slice("=", 1))
		elif argument == "--disable-companion":
			_balance_overrides["disable_companion"] = true
		elif argument == "--disable-companion-burn":
			_balance_overrides["disable_companion_burn"] = true
		elif argument.begins_with("--disable-effect="):
			for effect_id: String in argument.get_slice("=", 1).split(",", false):
				_balance_overrides["effect_scales"][effect_id.strip_edges()] = 0.0
		elif argument.begins_with("--effect-scale="):
			_parse_override_pairs(argument.get_slice("=", 1), "effect_scales", true)
		elif argument.begins_with("--effect-cap="):
			_parse_override_pairs(argument.get_slice("=", 1), "effect_caps", false)
		elif argument.begins_with("--max-effect-stacks="):
			_parse_override_pairs(argument.get_slice("=", 1), "max_effect_stacks", false)


func _parse_override_pairs(specification: String, target_key: String, floating: bool) -> void:
	for pair: String in specification.split(",", false):
		var separator: int = pair.find(":")
		if separator <= 0:
			continue
		var effect_id: String = pair.left(separator).strip_edges()
		var raw_value: String = pair.substr(separator + 1).strip_edges()
		_balance_overrides[target_key][effect_id] = float(raw_value) if floating else int(raw_value)


func _run_simulation() -> int:
	SynergyResolver.use_stage62_baseline_rules = _reward_rules == &"baseline"
	var started_usec: int = Time.get_ticks_usec()
	var file: FileAccess = FileAccess.open(_output_path, FileAccess.WRITE)
	if file == null:
		push_error("Stage 62 could not open output: %s" % _output_path)
		return 2
	var total_runs: int = BIOMES.size() * POLICIES.size() * _runs_per_configuration
	var completed: int = 0
	for biome_index: int in range(BIOMES.size()):
		for policy_index: int in range(POLICIES.size()):
			for sample_index: int in range(_runs_per_configuration):
				var seed: int = _seed_for(biome_index, policy_index, sample_index)
				var result: Dictionary = _simulate_run(BIOMES[biome_index], POLICIES[policy_index], seed)
				file.store_line(JSON.stringify(result))
				completed += 1
	file.close()
	var elapsed_seconds: float = float(Time.get_ticks_usec() - started_usec) / 1_000_000.0
	var metadata: Dictionary = {
		"schema": SCHEMA_VERSION,
		"base_seed": _base_seed,
		"runs_per_configuration": _runs_per_configuration,
		"total_runs": total_runs,
		"completed_runs": completed,
		"elapsed_seconds": snappedf(elapsed_seconds, 0.0001),
		"runs_per_second": snappedf(float(completed) / maxf(0.0001, elapsed_seconds), 0.01),
		"biomes": BIOMES,
		"policies": POLICIES,
		"profile": "new_run_level_0_no_equipment_default_skills_ember_hound",
		"reward_rules": String(_reward_rules),
		"experiment": _experiment_label,
		"balance_overrides": _balance_overrides,
		"baseline_contract": "BASELINE_67=STATE_AFTER_STAGE66_OFFENSIVE_IDENTITY",
		"boon_rarity_mode": String(_rarity_mode),
		"board_agency": _board_agency,
		"routing_policy": String(_routing_policy),
		"branch_percent": _branch_percent,
		"event_treasure_agency": _event_treasure_agency,
		"event_policy": String(_event_policy),
		"treasure_policy": String(_treasure_policy),
		"starting_option_id": String(_starting_option_id),
		"save_or_profile_written": false,
	}
	_write_json(_output_path.get_base_dir().path_join("simulation_metadata.json"), metadata)
	print(JSON.stringify(metadata))
	return 0


func _seed_for(biome_index: int, policy_index: int, sample_index: int) -> int:
	# Same sample index intentionally shares a board seed across policies.
	return absi(_base_seed + biome_index * 10_000_019 + sample_index * 104729)


func _simulate_run(biome_id: StringName, policy: StringName, seed: int) -> Dictionary:
	var biome: BiomeData = BiomeCatalog.get_or_default(biome_id)
	var run: RunState = RunState.new()
	run.biome_id = biome.id
	run.biome_data = biome
	run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	run.active_skill_id = ActiveSkillCatalog.DEFAULT_SKILL_ID
	run.equipped_companion_id = CompanionCatalog.EMBER_HOUND_ID
	run.starting_option_id = _starting_option_id
	BoardGenerator.generate_for_run(run, biome, seed)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = absi(seed ^ String(policy).hash() ^ 0x6200F)
	var metrics: Dictionary = _new_run_metrics(run, policy, seed)
	var visited: Dictionary = {0: true}
	while run.current_health > 0 and run.board_position < run.board_tile_sequence.size() - 1:
		var roll: int = rng.randi_range(DiceRoller.MIN_RESULT, DiceRoller.MAX_RESULT)
		var origin: int = run.board_position
		var was_on_cooldown: bool = run.route_choice_cooldown
		var destinations: Array[int] = [mini(origin + roll, run.board_tile_sequence.size() - 1)]
		if _board_agency:
			destinations = RouteChoiceResolver.get_destinations(
				run.board_tile_sequence, origin, roll, run.board_seed,
				run.route_choice_count, was_on_cooldown, _branch_percent,
			)
		if was_on_cooldown:
			run.route_choice_cooldown = false
		metrics["route_auto_moves"] += 1 if destinations.size() == 1 else 0
		var destination: int = destinations[0]
		if destinations.size() == 2:
			destination = _choose_route_destination(run, policy, destinations, metrics)
			run.route_choice_cooldown = true
		run.board_position = destination
		metrics["dice_rolls"] += 1
		metrics["tiles_visited"] += 1
		var tile_type: int = run.board_tile_sequence[run.board_position]
		visited[run.board_position] = true
		metrics["visited_tile_counts"][str(tile_type)] = int(metrics["visited_tile_counts"].get(str(tile_type), 0)) + 1
		var survived: bool = _resolve_tile(run, biome, policy, rng, tile_type, metrics)
		_record_curve_point(run, metrics)
		if not survived:
			break
	metrics["outcome"] = "victory" if run.run_completed else "defeat"
	metrics["final_tile"] = run.board_position
	metrics["final_hp"] = run.current_health
	metrics["max_hp"] = run.max_health
	metrics["attack"] = run.attack
	metrics["defense"] = run.defense
	metrics["xp"] = run.total_xp_gained
	metrics["level"] = run.run_level
	metrics["ash_before_boss_reward"] = run.run_ash
	_finalize_rewards(run, policy, rng, metrics)
	metrics["ash"] = run.run_ash
	metrics["loot_id"] = run.pending_loot_id
	var loot: EquipmentData = EquipmentCatalog.get_by_id(run.pending_loot_id)
	metrics["loot_rarity"] = loot.rarity if loot != null else -1
	metrics["boss_reward_id"] = String(run.boss_reward_id)
	metrics["boons"] = _counter_to_plain(run.active_boons)
	metrics["augments"] = _counter_to_plain(run.skill_augments)
	metrics["level_upgrades"] = _counter_to_plain(run.run_level_upgrade_stacks)
	metrics["synergies"] = _names_to_strings(run.activated_synergy_ids)
	metrics["primary_build"] = _primary_build(metrics["reward_archetype_counts"])
	var tags: BuildTagReport = BuildTagResolver.resolve(run)
	metrics["build_tags"] = _build_tag_counts(tags)
	metrics["board_hash"] = hash(run.board_tile_sequence)
	metrics["result_hash"] = hash(JSON.stringify(metrics))
	metrics.erase("_energy_carryover")
	return metrics


func _choose_route_destination(run: RunState, combat_policy: StringName, destinations: Array[int], metrics: Dictionary) -> int:
	var routing: StringName = _routing_policy
	if routing == &"matched":
		match combat_policy:
			&"random": routing = &"route_random"
			&"aggressive": routing = &"route_reward"
			&"defensive": routing = &"route_safe"
			_: routing = &"route_tactical"
	metrics["route_choice_count"] += 1
	metrics["route_meaningful_choices"] += 1 if RouteChoiceResolver.is_meaningful(run.board_tile_sequence, destinations) else 0
	for destination: int in destinations:
		var option_key: String = _route_tile_key(run.board_tile_sequence[destination])
		metrics["route_options_by_type"][option_key] = int(metrics["route_options_by_type"].get(option_key, 0)) + 1
	var selected_index: int = 0
	if routing == &"route_random":
		var mixed: int = absi(run.board_seed ^ ((run.board_position + 1) * 104729) ^ ((run.route_choice_count + 1) * 65537) ^ 0x6711)
		selected_index = mixed % destinations.size()
	else:
		var best_score: float = -9999.0
		for index: int in destinations.size():
			var destination: int = destinations[index]
			var score: float = _route_score(run, run.board_tile_sequence[destination], routing)
			if score > best_score:
				best_score = score
				selected_index = index
	var selected: int = destinations[selected_index]
	var selected_key: String = _route_tile_key(run.board_tile_sequence[selected])
	metrics["route_chosen_tile_types"][selected_key] = int(metrics["route_chosen_tile_types"].get(selected_key, 0)) + 1
	for destination: int in destinations:
		if destination == selected:
			continue
		var avoided_key: String = _route_tile_key(run.board_tile_sequence[destination])
		metrics["route_avoided_tile_types"][avoided_key] = int(metrics["route_avoided_tile_types"].get(avoided_key, 0)) + 1
	run.route_choice_count += 1
	run.route_option_a = destinations[0]
	run.route_option_b = destinations[1]
	run.chosen_destination = selected
	run.chosen_tile_type = run.board_tile_sequence[selected]
	return selected


func _route_score(run: RunState, tile_type: int, routing: StringName) -> float:
	var hp_ratio: float = float(run.current_health) / float(maxi(1, run.max_health))
	if routing == &"route_safe":
		match tile_type:
			BoardTileData.TileType.HEAL: return 10.0 if hp_ratio < 0.9 else 4.0
			BoardTileData.TileType.EMPTY: return 7.0
			BoardTileData.TileType.EVENT: return 5.0
			BoardTileData.TileType.TREASURE: return 4.0
			BoardTileData.TileType.COMBAT: return 2.0
			BoardTileData.TileType.ELITE: return -8.0 if hp_ratio < 0.65 else 1.0
	if routing == &"route_reward":
		match tile_type:
			BoardTileData.TileType.ELITE: return 10.0
			BoardTileData.TileType.TREASURE: return 9.0
			BoardTileData.TileType.COMBAT: return 7.0
			BoardTileData.TileType.EVENT: return 5.0
			BoardTileData.TileType.HEAL: return 3.0 if hp_ratio < 0.45 else 0.0
			BoardTileData.TileType.EMPTY: return -1.0
	# Tactical usa sólo estado observable: HP y categoría visible.
	match tile_type:
		BoardTileData.TileType.HEAL: return 12.0 if hp_ratio < 0.62 else 2.0
		BoardTileData.TileType.ELITE: return 9.0 if hp_ratio >= 0.72 else -6.0
		BoardTileData.TileType.TREASURE: return 8.0
		BoardTileData.TileType.EVENT: return 6.0
		BoardTileData.TileType.COMBAT: return 5.0 if hp_ratio >= 0.45 else 1.0
		BoardTileData.TileType.EMPTY: return 4.0 if hp_ratio < 0.5 else 0.0
		BoardTileData.TileType.BOSS: return 100.0
	return 0.0


func _route_tile_key(tile_type: int) -> String:
	match tile_type:
		BoardTileData.TileType.COMBAT: return "combat"
		BoardTileData.TileType.HEAL: return "heal"
		BoardTileData.TileType.BOSS: return "boss"
		BoardTileData.TileType.EVENT: return "event"
		BoardTileData.TileType.TREASURE: return "treasure"
		BoardTileData.TileType.ELITE: return "elite"
		_: return "empty"


func _new_run_metrics(run: RunState, policy: StringName, seed: int) -> Dictionary:
	var generated_counts: Dictionary = {}
	for tile_type: int in run.board_tile_sequence:
		generated_counts[str(tile_type)] = int(generated_counts.get(str(tile_type), 0)) + 1
	return {
		"schema": SCHEMA_VERSION,
		"run_id": "%s-%s-%d" % [run.biome_id, policy, seed],
		"seed": seed,
		"biome": String(run.biome_id),
		"policy": String(policy),
		"outcome": "",
		"board_length": run.board_tile_sequence.size(),
		"generated_tile_counts": generated_counts,
		"visited_tile_counts": {},
		"tiles_visited": 0,
		"dice_rolls": 0,
		"board_agency": _board_agency,
		"routing_policy": String(_routing_policy),
		"route_choice_count": 0,
		"route_meaningful_choices": 0,
		"route_auto_moves": 0,
		"route_options_by_type": {},
		"route_chosen_tile_types": {},
		"route_avoided_tile_types": {},
		"combats": 0,
		"normal_combats": 0,
		"elites": 0,
		"bosses": 0,
		"combat_wins": 0,
		"combat_turns": 0,
		"damage_taken": 0,
		"damage_dealt": 0,
		"player_basic_damage": 0,
		"skill_damage": 0,
		"companion_damage": 0,
		"burning_strike_damage": 0,
		"burn_damage": 0,
		"boss_burn_damage": 0,
		"retaliation_damage": 0,
		"boss_damage_dealt": 0,
		"damage_mitigated_cinder": 0,
		"damage_mitigated_guard": 0,
		"effective_defense_sum": 0,
		"effective_defense_samples": 0,
		"max_temporary_defense": 0,
		"healing": 0,
		"healing_ember_blood": 0,
		"healing_iron_vigil": 0,
		"healing_second_wind": 0,
		"overheal": 0,
		"heal_tiles": 0,
		"events": 0,
		"treasures": 0,
		"guard_uses": 0,
		"second_wind_uses": 0,
		"ember_slash_uses": 0,
		"basic_attacks": 0,
		"target_switches": 0,
		"intents_seen": 0,
		"enemy_intents_executed": 0,
		"high_intents_seen": 0,
		"enemies_killed_before_intent": 0,
		"energy_generated": 0,
		"energy_spent": 0,
		"energy_wasted_at_cap": 0,
		"energy_unspent_combat_end": 0,
		"energy_lost_on_combat_end": 0,
		"energy_lost_on_reset": 0,
		"turns_at_100_energy": 0,
		"turns_with_skill_available_but_not_used": 0,
		"ember_slash_opportunities": 0,
		"second_wind_opportunities": 0,
		"guard_opportunities": 0,
		"both_slash_wind_available": 0,
		"both_chose_slash": 0,
		"both_chose_wind": 0,
		"skill_choice_hp_sum": 0,
		"skill_choice_threat_sum": 0,
		"energy_flow": {"CAP_WASTE": 0, "COMBAT_END_WASTE": 0, "SKILL_THRESHOLD": 0, "HELD_FOR_HEAL": 0, "HELD_FOR_ATTACK": 0, "NO_VALID_SKILL": 0, "POLICY_DECISION": 0, "OTHER": 0},
		"energy_carried_between_combats": 0,
		"combat_start_energy": 0,
		"combat_starts_with_second_wind_energy": 0,
		"first_ember_slash_turn": -1,
		"_energy_carryover": 0,
		"ember_slash_damage": 0,
		"ember_slash_kills": 0,
		"ember_slash_intents_prevented": 0,
		"ember_slash_estimated_damage_prevented": 0,
		"boss_ember_slash_damage": 0,
		"second_wind_lethal_threat_uses": 0,
		"turns_without_usable_skill": 0,
		"burn_applications": 0,
		"burn_stack_samples": 0,
		"burn_stack_sum": 0,
		"burn_waste_stacks": 0,
		"burn_ticks": 0,
		"burn_ticks_lost_on_death": 0,
		"burn_max_stacks": 0,
		"burn_active_enemy_turns": 0,
		"boss_burn_active_turns": 0,
		"warden_rebuke_intents": 0,
		"warden_rebuke_armed": 0,
		"warden_rebuke_counters": 0,
		"warden_rebuke_damage": 0,
		"warden_basic_attacks_punished": 0,
		"first_burn_tile": -1,
		"first_burn_combat_turn": -1,
		"first_low_hp_tile": -1,
		"effect_triggers": {},
		"summons": 0,
		"boss_phase_reached": 0,
		"boss_turns": 0,
		"boss_entry_hp": -1,
		"boss_entry_attack": -1,
		"boss_entry_defense": -1,
		"boss_id": "",
		"boss_outcome": "not_reached",
		"boss_hp_remaining": -1,
		"death_encounter": "",
		"combat_log": [],
		"upgrade_offers": {},
		"upgrade_picks": {},
		"augment_picks": {},
		"offer_quality": {"off_build": 0, "neutral": 0, "on_build": 0, "synergy_completing": 0},
		"offer_sets": {"no_useful": 0, "one_useful": 0, "multiple_useful": 0},
		"rarity_rolls": {},
		"rarity_fallbacks": 0,
		"reward_archetype_counts": {"offense": 0, "defense": 0, "sustain": 0},
		"synergy_activation_tiles": {},
		"treasure_rewards": {},
		"event_choices": {},
		"events_seen_ids": {},
		"event_options_shown": 0,
		"event_meaningful_choices": 0,
		"event_hp_cost": 0,
		"event_ash_cost": 0,
		"event_rewards_received": {},
		"event_flags_set": 0,
		"event_chain_completions": 0,
		"event_deaths": 0,
		"treasure_choices": {},
		"treasure_options_shown": 0,
		"treasure_meaningful_choices": 0,
		"treasure_reward_types": {},
		"level_up_tiles": [],
		"curve": [],
	}


func _resolve_tile(run: RunState, biome: BiomeData, policy: StringName, rng: RandomNumberGenerator, tile_type: int, metrics: Dictionary) -> bool:
	match tile_type:
		BoardTileData.TileType.COMBAT:
			return _resolve_combat_tile(run, biome, policy, rng, false, false, metrics)
		BoardTileData.TileType.ELITE:
			return _resolve_combat_tile(run, biome, policy, rng, true, false, metrics)
		BoardTileData.TileType.BOSS:
			return _resolve_combat_tile(run, biome, policy, rng, false, true, metrics)
		BoardTileData.TileType.HEAL:
			metrics["heal_tiles"] += 1
			_apply_heal(run, HEAL_TILE_AMOUNT, metrics)
		BoardTileData.TileType.EVENT:
			_resolve_event(run, biome, policy, rng, metrics)
		BoardTileData.TileType.TREASURE:
			_resolve_treasure(run, rng, metrics)
	return run.current_health > 0


func _resolve_combat_tile(run: RunState, biome: BiomeData, policy: StringName, rng: RandomNumberGenerator, is_elite: bool, is_boss: bool, metrics: Dictionary) -> bool:
	var enemies: Array[EnemyData] = []
	var encounter_id: String = ""
	if is_boss:
		enemies.append(biome.boss)
		encounter_id = String(biome.boss.id)
		metrics["boss_entry_hp"] = run.current_health
		metrics["boss_entry_attack"] = run.attack
		metrics["boss_entry_defense"] = run.defense
		metrics["boss_id"] = String(biome.boss.id)
	elif is_elite:
		var pick_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		pick_rng.seed = absi(run.board_seed ^ String(biome.id).hash() ^ run.board_position * 104729 ^ 0x37B)
		var elite: EnemyData = biome.elite_enemy_pool[pick_rng.randi_range(0, biome.elite_enemy_pool.size() - 1)]
		enemies.append(elite)
		encounter_id = String(elite.id)
	else:
		var encounter: EncounterInstance = EncounterResolver.build_normal(biome, run)
		if encounter == null or encounter.enemies.is_empty():
			return false
		enemies = encounter.enemies
		encounter_id = String(encounter.signature)
	metrics["combats"] += 1
	metrics["bosses" if is_boss else ("elites" if is_elite else "normal_combats")] += 1
	var combat: Dictionary = _simulate_combat(run, enemies, is_elite, is_boss, policy, rng, metrics)
	combat["encounter_id"] = encounter_id
	combat["tile"] = run.board_position
	metrics["combat_log"].append(combat)
	metrics["combat_turns"] += int(combat["turns"])
	metrics["damage_taken"] += int(combat["damage_taken"])
	metrics["healing"] += int(combat["healing"])
	if is_boss:
		metrics["boss_turns"] = combat["turns"]
		metrics["boss_phase_reached"] = combat["phase_reached"]
		metrics["boss_outcome"] = combat["outcome"]
	if combat["outcome"] != "victory":
		metrics["death_encounter"] = encounter_id
		return false
	metrics["combat_wins"] += 1
	if is_boss:
		run.record_boss_victory()
		run.add_run_xp(RunLevelConfig.BOSS_COMBAT_XP)
		return true
	if is_elite:
		run.record_elite_combat_victory()
		run.add_run_xp(RunLevelConfig.ELITE_COMBAT_XP)
	else:
		run.record_normal_combat_victory()
		run.add_run_xp(RunLevelConfig.NORMAL_COMBAT_XP)
	_resolve_level_ups(run, policy, metrics)
	_resolve_post_combat_reward(run, policy, rng, is_elite, metrics)
	return true


func _simulate_combat(run: RunState, enemy_data: Array[EnemyData], is_elite: bool, is_boss: bool, policy: StringName, rng: RandomNumberGenerator, metrics: Dictionary) -> Dictionary:
	var start_hp: int = run.current_health
	var player: CombatActor = CombatActor.from_player(&"player_0", run, null)
	var companion_data: CompanionData = null if bool(_balance_overrides.get("disable_companion", false)) else CompanionCatalog.get_by_id(run.equipped_companion_id)
	var companion: CombatActor = CombatActor.from_companion(&"companion_0", companion_data) if companion_data != null else null
	if companion != null:
		companion.formation_slot = 1
	var enemies: Array[CombatActor] = []
	var ai_states: Dictionary = {}
	for index: int in range(enemy_data.size()):
		var kind: CombatActor.ActorType = CombatActor.ActorType.BOSS if is_boss else (CombatActor.ActorType.ELITE if is_elite else CombatActor.ActorType.NORMAL_ENEMY)
		var actor: CombatActor = CombatActor.from_enemy(StringName("enemy_%d" % index), enemy_data[index], kind)
		actor.formation_slot = index
		enemies.append(actor)
		ai_states[actor.actor_id] = EnemyAIRuntimeState.new()
	var statuses: CombatStatusController = CombatStatusController.new(_balance_overrides)
	var skills: CombatSkillController = CombatSkillController.new(run.equipped_skill_ids, run, _balance_overrides)
	var carried_energy: int = clampi(int(metrics.get("_energy_carryover", 0)), 0, CombatSkillController.MAX_ENERGY)
	skills.current_energy = carried_energy
	metrics["combat_start_energy"] += carried_energy
	var wind_at_start: ActiveSkillController = skills.get_by_id(&"second_wind")
	if wind_at_start != null and carried_energy >= wind_at_start.get_effective_energy_cost():
		metrics["combat_starts_with_second_wind_energy"] += 1
	metrics["_energy_carryover"] = 0
	var boons: BoonController = BoonController.new(run, _balance_overrides)
	var synergy_runtime: SynergyRuntimeState = SynergyRuntimeState.new()
	var companion_runtime: CompanionRuntimeState = CompanionRuntimeState.new() if companion != null else null
	var boss: CombatActor = enemies[0] if is_boss else null
	var boss_controller: BossEncounterController = null
	if boss != null and (boss.source_data as EnemyData).boss_encounter != null:
		boss_controller = BossEncounterController.new((boss.source_data as EnemyData).boss_encounter, boss)
	var state: Dictionary = {
		"run": run, "player": player, "companion": companion, "companion_data": companion_data,
		"companion_runtime": companion_runtime, "enemies": enemies, "ai_states": ai_states,
		"statuses": statuses, "skills": skills, "boons": boons, "boss": boss,
		"synergy_runtime": synergy_runtime,
		"boss_controller": boss_controller, "intents": {}, "next_minion": 0,
		"last_target_id": &"", "turns": 0, "damage_taken": 0, "damage_dealt": 0, "healing": 0,
		"phase_reached": 1 if is_boss else 0, "metrics": metrics,
	}
	boons.on_combat_started()
	if boons.has_pyre_heart_active():
		_record_trigger(metrics, &"pyre_heart")
	if boons.is_phoenix_empowered():
		_record_trigger(metrics, &"phoenix_blood")
	if _effect_enabled(&"mire_bloom"):
		SynergyEffectResolver.apply_combat_start(run, player, statuses)
	_plan_all_intents(state, metrics)
	while player.is_alive() and not _alive_enemies(state).is_empty() and int(state["turns"]) < MAX_COMBAT_TURNS:
		state["turns"] += 1
		synergy_runtime.begin_player_turn()
		_apply_turn_start(state, player)
		if not player.is_alive():
			break
		var usable_skills: int = 0
		for controller: ActiveSkillController in skills.skills:
			if _effect_enabled(controller.skill.id) and skills.can_use(controller):
				usable_skills += 1
		if usable_skills == 0:
			metrics["turns_without_usable_skill"] += 1
		var choice: Dictionary = _choose_player_action(state, policy, rng)
		_record_energy_decision(state, choice, usable_skills, metrics)
		_execute_player_action(state, choice, rng, metrics)
		statuses.process_turn_end(player)
		if _alive_enemies(state).is_empty():
			break
		_run_companion_turn(state, metrics)
		if _alive_enemies(state).is_empty():
			break
		_run_enemy_round(state, metrics)
		if player.is_alive() and not _alive_enemies(state).is_empty():
			_plan_all_intents(state, metrics)
	var victory: bool = player.is_alive() and _alive_enemies(state).is_empty()
	if victory:
		var ember_heal: int = boons.on_enemy_defeated()
		state["healing"] += ember_heal
		metrics["healing_ember_blood"] += ember_heal
		if ember_heal > 0:
			_record_trigger(metrics, &"ember_blood")
	boons.on_combat_ended()
	metrics["energy_unspent_combat_end"] += skills.current_energy
	var carry_fraction: float = float(_balance_overrides.get("energy_carryover_fraction", 0.0))
	var retained: int = floori(float(skills.current_energy) * carry_fraction)
	var carry_cap: int = int(_balance_overrides.get("energy_carryover_cap", 0))
	if carry_cap > 0:
		retained = mini(retained, carry_cap)
	if not victory or is_boss:
		retained = 0
	retained = clampi(retained, 0, CombatSkillController.MAX_ENERGY)
	var lost_energy: int = skills.current_energy - retained
	metrics["_energy_carryover"] = retained
	metrics["energy_carried_between_combats"] += retained
	metrics["energy_lost_on_combat_end"] += lost_energy
	metrics["energy_lost_on_reset"] += lost_energy
	metrics["energy_flow"]["COMBAT_END_WASTE"] += lost_energy
	if is_boss and boss != null:
		metrics["boss_hp_remaining"] = boss.get_current_hp()
	return {
		"outcome": "victory" if victory else "defeat",
		"is_elite": is_elite,
		"is_boss": is_boss,
		"enemies": _enemy_ids(enemy_data),
		"turns": state["turns"],
		"starting_hp": start_hp,
		"ending_hp": run.current_health,
		"damage_taken": state["damage_taken"],
		"damage_dealt": state.get("damage_dealt", 0),
		"healing": state["healing"],
		"phase_reached": state["phase_reached"],
		"turn_cap_reached": int(state["turns"]) >= MAX_COMBAT_TURNS,
	}


func _plan_all_intents(state: Dictionary, metrics: Dictionary) -> void:
	state["intents"] = {}
	for enemy: CombatActor in _alive_enemies(state):
		_plan_one_intent(state, enemy, metrics)


func _plan_one_intent(state: Dictionary, enemy: CombatActor, metrics: Dictionary) -> EnemyIntent:
	var ai_state: EnemyAIRuntimeState = state["ai_states"][enemy.actor_id]
	var profile: EnemyAIData = _enemy_profile(state, enemy)
	var boss_controller: BossEncounterController = state["boss_controller"]
	var forced: EnemyActionData = boss_controller.get_forced_action(enemy) if boss_controller != null else null
	var excluded: Array[StringName] = []
	if boss_controller != null:
		excluded = boss_controller.get_excluded_action_ids(enemy)
	_plan_sequence += 1
	var intent_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var run: RunState = state["run"]
	intent_rng.seed = absi(run.board_seed ^ String(enemy.actor_id).hash() ^ (run.board_position + 1) * 104729 ^ (run.combats_won + 1) * 4099 ^ (ai_state.turn_count + 1) * 65537 ^ 0x46A1)
	var intent: EnemyIntent = EnemyIntentPlanner.plan(enemy, profile, ai_state, _alive_players(state), intent_rng, _plan_sequence, forced, excluded)
	if intent == null:
		return null
	_populate_intent(state, intent)
	state["intents"][enemy.actor_id] = intent
	metrics["intents_seen"] += 1
	if intent.action != null and intent.action.action_id == &"warden_rebuke":
		metrics["warden_rebuke_intents"] += 1
	if intent.intensity >= EnemyIntent.Intensity.HIGH:
		metrics["high_intents_seen"] += 1
	return intent


func _populate_intent(state: Dictionary, intent: EnemyIntent) -> void:
	if intent.category == EnemyIntent.Category.SUMMON:
		var controller: BossEncounterController = state["boss_controller"]
		if controller != null:
			var phase: BossPhaseData = controller.get_pending_summon_phase()
			if phase != null and phase.summon_data != null:
				intent.summon_type = phase.summon_data.id
				intent.summon_count = controller.get_pending_summon_count()
		return
	if intent.action_type not in [EnemyAIEnums.ActionType.ATTACK, EnemyAIEnums.ActionType.ATTACK_STATUS] or intent.target_actor == null:
		return
	var attack: int = intent.source_actor.get_attack()
	var controller: BossEncounterController = state["boss_controller"]
	if controller != null and controller.owns_actor(intent.source_actor):
		attack = maxi(1, roundi(float(attack) * controller.get_attack_multiplier()))
	attack = (state["statuses"] as CombatStatusController).get_effective_attack(intent.source_actor, attack)
	var damage: int = CombatMath.calculate_damage(attack, _effective_defense(state, intent.target_actor))
	damage = maxi(1, roundi(float(damage) * intent.action.power_multiplier))
	intent.update_damage_estimate(damage, intent.target_actor, false)


func _choose_player_action(state: Dictionary, policy: StringName, rng: RandomNumberGenerator) -> Dictionary:
	var player: CombatActor = state["player"]
	var skills: CombatSkillController = state["skills"]
	var enemies: Array[CombatActor] = _alive_enemies(state)
	var threat: Dictionary = _threat_summary(state)
	var target: CombatActor = _choose_target(state, policy, rng)
	var available: Array[ActiveSkillController] = []
	for controller: ActiveSkillController in skills.skills:
		if _effect_enabled(controller.skill.id) and skills.can_use(controller):
			available.append(controller)
	if policy == &"random" and not available.is_empty() and rng.randf() < 0.45:
		return {"type": "skill", "skill": available[rng.randi_range(0, available.size() - 1)], "target": target}
	var heal: ActiveSkillController = skills.get_by_id(&"second_wind")
	var guard: ActiveSkillController = skills.get_by_id(&"ashen_guard")
	var slash: ActiveSkillController = skills.get_by_id(&"ember_slash")
	var hp_ratio: float = float(player.get_current_hp()) / float(player.get_max_hp())
	if policy == &"defensive":
		if heal != null and skills.can_use(heal) and hp_ratio <= 0.55:
			return {"type": "skill", "skill": heal, "target": player}
		if guard != null and skills.can_use(guard) and (int(threat["total"]) >= maxi(16, player.get_current_hp() / 3) or int(threat["high_count"]) > 0):
			return {"type": "skill", "skill": guard, "target": player}
	if policy == &"tactical":
		if heal != null and skills.can_use(heal) and (int(threat["total"]) >= player.get_current_hp() or hp_ratio <= 0.40):
			return {"type": "skill", "skill": heal, "target": player}
		if guard != null and skills.can_use(guard) and (int(threat["lethal_count"]) > 0 or int(threat["high_count"]) > 0 or int(threat["total"]) >= maxi(18, player.get_current_hp() / 2)):
			return {"type": "skill", "skill": guard, "target": player}
		if slash != null and skills.can_use(slash) and target != null:
			return {"type": "skill", "skill": slash, "target": target}
	if policy == &"aggressive":
		# Una policy ofensiva puede asumir riesgo, pero no debe rechazar una
		# curación disponible cuando el plan enemigo ya representa muerte segura.
		if heal != null and skills.can_use(heal) and (hp_ratio <= 0.25 or int(threat["total"]) >= player.get_current_hp()):
			return {"type": "skill", "skill": heal, "target": player}
		if slash != null and skills.can_use(slash):
			return {"type": "skill", "skill": slash, "target": target}
	return {"type": "basic", "skill": null, "target": target}


func _record_energy_decision(state: Dictionary, choice: Dictionary, usable_count: int, metrics: Dictionary) -> void:
	var skills: CombatSkillController = state["skills"]
	var player: CombatActor = state["player"]
	var threat: Dictionary = _threat_summary(state)
	if skills.current_energy >= CombatSkillController.MAX_ENERGY:
		metrics["turns_at_100_energy"] += 1
	var slash: ActiveSkillController = skills.get_by_id(&"ember_slash")
	var wind: ActiveSkillController = skills.get_by_id(&"second_wind")
	var guard: ActiveSkillController = skills.get_by_id(&"ashen_guard")
	var slash_ready: bool = slash != null and _effect_enabled(&"ember_slash") and skills.can_use(slash)
	var wind_ready: bool = wind != null and _effect_enabled(&"second_wind") and skills.can_use(wind)
	var guard_ready: bool = guard != null and _effect_enabled(&"ashen_guard") and skills.can_use(guard)
	metrics["ember_slash_opportunities"] += int(slash_ready)
	metrics["second_wind_opportunities"] += int(wind_ready)
	metrics["guard_opportunities"] += int(guard_ready)
	var chosen_id: StringName = &""
	if choice["type"] == "skill" and choice["skill"] != null:
		chosen_id = (choice["skill"] as ActiveSkillController).skill.id
	if slash_ready and wind_ready:
		metrics["both_slash_wind_available"] += 1
		metrics["skill_choice_hp_sum"] += player.get_current_hp()
		metrics["skill_choice_threat_sum"] += int(threat["total"])
		if chosen_id == &"ember_slash":
			metrics["both_chose_slash"] += 1
			metrics["energy_flow"]["HELD_FOR_ATTACK"] += 1
		elif chosen_id == &"second_wind":
			metrics["both_chose_wind"] += 1
			metrics["energy_flow"]["HELD_FOR_HEAL"] += 1
	if usable_count > 0 and choice["type"] == "basic":
		metrics["turns_with_skill_available_but_not_used"] += 1
		metrics["energy_flow"]["POLICY_DECISION"] += 1
	elif usable_count == 0:
		var minimum_cost: int = 100000
		for controller: ActiveSkillController in skills.skills:
			if _effect_enabled(controller.skill.id):
				minimum_cost = mini(minimum_cost, controller.get_effective_energy_cost())
		if skills.current_energy < minimum_cost:
			metrics["energy_flow"]["SKILL_THRESHOLD"] += 1
		else:
			metrics["energy_flow"]["NO_VALID_SKILL"] += 1


func _choose_target(state: Dictionary, policy: StringName, rng: RandomNumberGenerator) -> CombatActor:
	var enemies: Array[CombatActor] = _alive_enemies(state)
	if enemies.is_empty():
		return null
	if policy == &"random":
		return enemies[rng.randi_range(0, enemies.size() - 1)]
	var chosen: CombatActor = enemies[0]
	var best: float = -1e9
	for enemy: CombatActor in enemies:
		var data: EnemyData = enemy.source_data as EnemyData
		var intent: EnemyIntent = state["intents"].get(enemy.actor_id) as EnemyIntent
		var score: float = 0.0
		if policy == &"aggressive":
			score = 1000.0 / float(maxi(1, enemy.get_current_hp())) + float(enemy.get_attack())
		elif policy == &"defensive":
			score = float(enemy.get_attack()) * 2.0 - float(enemy.get_current_hp()) * 0.1
			if data != null and data.ai_profile != null and (
				data.ai_profile.role == EnemyAIEnums.Role.SUPPORT or _profile_is_disruptive(data.ai_profile)
			):
				score += 20.0
		else:
			if intent != null:
				score += float(intent.priority) * 25.0 + float(maxi(0, intent.estimated_damage))
				if intent.estimated_damage >= enemy.get_current_hp():
					score += 35.0
			if data != null and data.ai_profile != null:
				if data.ai_profile.role == EnemyAIEnums.Role.SUPPORT:
					score += 45.0
				elif _profile_is_disruptive(data.ai_profile):
					score += 35.0
			if enemy.actor_type == CombatActor.ActorType.MINION:
				score += 30.0
		if score > best:
			best = score
			chosen = enemy
	return chosen


func _execute_player_action(state: Dictionary, choice: Dictionary, rng: RandomNumberGenerator, metrics: Dictionary) -> void:
	var target: CombatActor = choice["target"]
	if target == null or not target.is_alive():
		target = _alive_enemies(state)[0] if not _alive_enemies(state).is_empty() else null
	if target == null:
		return
	if state["last_target_id"] != &"" and state["last_target_id"] != target.actor_id:
		metrics["target_switches"] += 1
	state["last_target_id"] = target.actor_id
	var run: RunState = state["run"]
	var player: CombatActor = state["player"]
	var statuses: CombatStatusController = state["statuses"]
	var skills: CombatSkillController = state["skills"]
	var boons: BoonController = state["boons"]
	if boons.is_last_ember_active():
		_record_trigger(metrics, &"last_ember")
		if int(metrics["first_low_hp_tile"]) < 0:
			metrics["first_low_hp_tile"] = run.board_position
	if boons.get_relentless_attack_bonus() > 0:
		_record_trigger(metrics, &"relentless_flame")
	if choice["type"] == "skill":
		var controller: ActiveSkillController = choice["skill"]
		if not _effect_enabled(controller.skill.id):
			return
		var energy_before: int = skills.current_energy
		if not skills.try_use(controller):
			return
		var spent: int = energy_before - skills.current_energy
		metrics["energy_spent"] += spent
		match controller.skill.id:
			&"ember_slash":
				metrics["ember_slash_uses"] += 1
				if int(metrics["first_ember_slash_turn"]) < 0:
					metrics["first_ember_slash_turn"] = int(state["turns"])
				var damage: int = controller.calculate_skill_damage(statuses.get_effective_attack(player, boons.get_effective_attack()), _effective_defense(state, target), target.get_current_hp(), target.get_max_hp())
				var pending: EnemyIntent = state["intents"].get(target.actor_id) as EnemyIntent
				var actual_slash: int = _deal_damage(state, target, damage, "skill_damage")
				metrics["ember_slash_damage"] += actual_slash
				if target == state["boss"]:
					metrics["boss_ember_slash_damage"] += actual_slash
				if not target.is_alive():
					metrics["ember_slash_kills"] += 1
					if pending != null and pending.is_valid:
						metrics["ember_slash_intents_prevented"] += 1
						metrics["ember_slash_estimated_damage_prevented"] += maxi(0, pending.estimated_damage)
			&"ashen_guard":
				metrics["guard_uses"] += 1
				statuses.apply_status(player, &"guard", player, 1, 1)
			&"second_wind":
				metrics["second_wind_uses"] += 1
				if int(_threat_summary(state)["total"]) >= player.get_current_hp() - controller.last_heal_amount:
					metrics["second_wind_lethal_threat_uses"] += 1
				state["healing"] += controller.last_heal_amount
				metrics["healing_second_wind"] += controller.last_heal_amount
		if _effect_enabled(&"runic_flow"):
			var runic_requested: int = roundi(SynergyCatalog.RUNIC_FLOW.effect_value * _effect_scale(&"runic_flow")) if SynergyResolver.is_active(&"runic_flow", run) else 0
			_add_energy_measured(skills, runic_requested, metrics, run)
	else:
		metrics["basic_attacks"] += 1
		var target_was_burning: bool = target.has_status(&"burn")
		var attack: int = statuses.get_effective_attack(player, boons.before_player_attack())
		var damage: int = EquipmentEffectResolver.apply_basic_attack_damage(CombatMath.calculate_damage(attack, _effective_defense(state, target)), run)
		_deal_damage(state, target, damage, "player_basic_damage")
		EquipmentEffectResolver.apply_basic_hit_status(run, player, target, statuses)
		var bonus: int = boons.after_player_attack()
		if bonus > 0:
			_deal_damage(state, target, bonus, "burning_strike_damage")
			_record_trigger(metrics, &"burning_strike")
			if target.is_alive():
				var burn_stacks: int = int(_balance_overrides.get("burning_strike_burn_stacks", 0))
				if SynergyResolver.is_active(&"inferno_rhythm", run):
					burn_stacks += int(_balance_overrides.get("inferno_burn_bonus_stacks", 0))
				if burn_stacks > 0:
					_record_burn_application(statuses.apply_status(target, &"burn", player, burn_stacks), state, metrics)
		if boons.was_inferno_triggered():
			_record_trigger(metrics, &"inferno_rhythm")
		if target_was_burning and _effect_enabled(&"inferno_rhythm") and SynergyResolver.is_active(&"inferno_rhythm", run):
			_add_energy_measured(skills, roundi(SynergyCatalog.INFERNO_RHYTHM.secondary_value * _effect_scale(&"inferno_rhythm")), metrics, run)
		var basic_requested: int = int(_balance_overrides.get("basic_energy", CombatSkillController.BASIC_ATTACK_ENERGY))
		var before_basic_energy: int = skills.current_energy
		var basic_gained: int = skills.on_basic_attack_completed()
		metrics["energy_generated"] += basic_gained
		var basic_waste: int = maxi(0, BiomeModifierResolver.effective_energy_gain(basic_requested, run.biome_data, 1.0 + run.equipment_ember_gain_bonus) - (skills.current_energy - before_basic_energy))
		metrics["energy_wasted_at_cap"] += basic_waste
		metrics["energy_flow"]["CAP_WASTE"] += basic_waste
		var boss_controller: BossEncounterController = state["boss_controller"]
		if boss_controller != null and boss_controller.can_counter_basic(target):
			var multiplier: float = boss_controller.consume_counter_multiplier(target) * _effect_scale(&"warden_rebuke")
			var counter_attack: int = maxi(1, roundi(float(target.get_attack()) * boss_controller.get_attack_multiplier()))
			var counter_damage: int = CombatMath.calculate_damage(statuses.get_effective_attack(target, counter_attack), _effective_defense(state, player))
			counter_damage = maxi(1, roundi(float(counter_damage) * multiplier))
			counter_damage = boons.before_player_takes_damage(counter_damage)
			var guard: ActiveSkillController = skills.get_guard_controller()
			if guard != null:
				counter_damage = guard.apply_guard_to_damage(counter_damage)
				statuses.consume_hit_status(player, &"guard")
			var actual: int = player.apply_damage(counter_damage)
			state["damage_taken"] += actual
			metrics["warden_rebuke_counters"] += 1
			metrics["warden_basic_attacks_punished"] += 1
			metrics["warden_rebuke_damage"] += actual
			_add_damage_energy_measured(skills, actual, metrics)
	_check_phase(state)
	if not target.is_alive():
		var pending: EnemyIntent = state["intents"].get(target.actor_id) as EnemyIntent
		if pending != null and pending.is_valid:
			metrics["enemies_killed_before_intent"] += 1
		state["intents"].erase(target.actor_id)


func _run_companion_turn(state: Dictionary, metrics: Dictionary) -> void:
	var companion: CombatActor = state["companion"]
	if companion == null or not companion.is_alive():
		return
	var statuses: CombatStatusController = state["statuses"]
	_apply_turn_start(state, companion)
	if not companion.is_alive():
		return
	var selected: CombatActor = _alive_enemies(state)[0] if not _alive_enemies(state).is_empty() else null
	var plan: CompanionActionResolver.ActionPlan = CompanionActionResolver.build_plan(companion, state["companion_data"], state["companion_runtime"], selected, state["enemies"], statuses, _enemy_defense_bonus(state, selected))
	if plan.target == null:
		return
	_deal_damage(state, plan.target, plan.damage, "companion_damage")
	if plan.uses_ability and plan.target.is_alive() and not bool(_balance_overrides.get("disable_companion_burn", false)):
		var applied: StatusEffectInstance = statuses.apply_status(plan.target, state["companion_data"].ability_status_id, companion, state["companion_data"].ability_status_stacks)
		_record_burn_application(applied, state, metrics)
	state["companion_runtime"].record_action()
	statuses.process_turn_end(companion)
	_check_phase(state)
	if not plan.target.is_alive():
		var pending: EnemyIntent = state["intents"].get(plan.target.actor_id) as EnemyIntent
		if pending != null and pending.is_valid:
			metrics["enemies_killed_before_intent"] += 1
		state["intents"].erase(plan.target.actor_id)


func _run_enemy_round(state: Dictionary, metrics: Dictionary) -> void:
	var round_enemies: Array[CombatActor] = state["enemies"].duplicate()
	for enemy: CombatActor in round_enemies:
		if not enemy.is_alive() or not (state["player"] as CombatActor).is_alive():
			continue
		_run_enemy_action(state, enemy, metrics)


func _run_enemy_action(state: Dictionary, enemy: CombatActor, metrics: Dictionary) -> void:
	var statuses: CombatStatusController = state["statuses"]
	_apply_turn_start(state, enemy)
	if not enemy.is_alive():
		return
	var ai_state: EnemyAIRuntimeState = state["ai_states"][enemy.actor_id]
	ai_state.begin_turn()
	var intent: EnemyIntent = state["intents"].get(enemy.actor_id) as EnemyIntent
	if intent == null or not intent.can_execute():
		return
	var action: EnemyActionData = intent.action
	if action.action_type == EnemyAIEnums.ActionType.SUMMON:
		_summon_from_intent(state, enemy, action, ai_state, metrics)
		statuses.process_turn_end(enemy)
		return
	if action.action_type == EnemyAIEnums.ActionType.SELF_BUFF:
		var boss_controller: BossEncounterController = state["boss_controller"]
		if boss_controller != null and boss_controller.is_counter_action(action):
			boss_controller.arm_counter()
			metrics["warden_rebuke_armed"] += 1
		else:
			ai_state.activate_guard_stance(action.defense_bonus)
		ai_state.record_action(action)
		statuses.process_turn_end(enemy)
		return
	var target: CombatActor = intent.resolve_execution_target(_alive_players(state))
	if target == null:
		return
	var base_attack: int = enemy.get_attack()
	var boss_controller: BossEncounterController = state["boss_controller"]
	if boss_controller != null and boss_controller.owns_actor(enemy):
		base_attack = maxi(1, roundi(float(base_attack) * boss_controller.get_attack_multiplier()))
	var damage: int = CombatMath.calculate_damage(statuses.get_effective_attack(enemy, base_attack), _effective_defense(state, target))
	damage = maxi(1, roundi(float(damage) * action.power_multiplier))
	var damage_before_mitigation: int = damage
	var guard_reduction: int = 0
	if target == state["player"]:
		metrics["effective_defense_sum"] += _effective_defense(state, target)
		metrics["effective_defense_samples"] += 1
		damage = (state["boons"] as BoonController).before_player_takes_damage(damage)
		metrics["damage_mitigated_cinder"] += maxi(0, damage_before_mitigation - damage)
		if damage_before_mitigation > damage:
			_record_trigger(metrics, &"cinder_skin")
		var guard: ActiveSkillController = (state["skills"] as CombatSkillController).get_guard_controller()
		if guard != null:
			var before_guard: int = damage
			damage = guard.apply_guard_to_damage(damage)
			guard_reduction = before_guard - damage
			metrics["damage_mitigated_guard"] += guard_reduction
			statuses.consume_hit_status(target, &"guard")
	var actual: int = target.apply_damage(damage)
	if target == state["player"]:
		state["damage_taken"] += actual
		_add_damage_energy_measured(state["skills"], actual, metrics)
		if guard_reduction > 0 and _effect_enabled(&"iron_vigil") and SynergyResolver.is_active(&"iron_vigil", state["run"]):
			var runtime: SynergyRuntimeState = state["synergy_runtime"]
			if not runtime.iron_vigil_triggered_this_combat:
				runtime.iron_vigil_triggered_this_combat = true
				var vigil_heal: int = (state["run"] as RunState).heal(roundi(SynergyCatalog.IRON_VIGIL.effect_value * _effect_scale(&"iron_vigil")))
				state["healing"] += vigil_heal
				metrics["healing_iron_vigil"] += vigil_heal
				_record_trigger(metrics, &"iron_vigil")
		var retaliation: int = (state["boons"] as BoonController).after_player_takes_damage()
		if retaliation > 0:
			_deal_damage(state, enemy, retaliation, "retaliation_damage")
			_record_trigger(metrics, &"ashen_reprisal")
		var temp_defense: int = (state["boons"] as BoonController).get_temporary_defense_bonus()
		metrics["max_temporary_defense"] = maxi(int(metrics["max_temporary_defense"]), temp_defense)
		if temp_defense > 0:
			_record_trigger(metrics, &"ashen_bulwark")
	if action.action_type == EnemyAIEnums.ActionType.ATTACK_STATUS and target.is_alive():
		statuses.apply_status(target, action.status_id, enemy, action.status_stacks, action.status_duration)
	ai_state.record_action(action)
	metrics["enemy_intents_executed"] += 1
	statuses.process_turn_end(enemy)
	_check_phase(state)


func _summon_from_intent(state: Dictionary, enemy: CombatActor, action: EnemyActionData, ai_state: EnemyAIRuntimeState, metrics: Dictionary) -> void:
	var controller: BossEncounterController = state["boss_controller"]
	if controller == null or not controller.owns_actor(enemy):
		return
	var phase: BossPhaseData = controller.get_pending_summon_phase()
	if phase == null or phase.summon_data == null:
		controller.mark_summon_completed()
		return
	var count: int = mini(controller.get_pending_summon_count(), controller.data.max_active_enemies - _alive_enemies(state).size())
	for index: int in range(count):
		var actor: CombatActor = CombatActor.from_enemy(StringName("minion_%d" % state["next_minion"]), phase.summon_data, CombatActor.ActorType.MINION)
		state["next_minion"] += 1
		actor.formation_slot = 0 if index == 0 else 2
		state["enemies"].append(actor)
		state["ai_states"][actor.actor_id] = EnemyAIRuntimeState.new()
		metrics["summons"] += 1
	controller.mark_summon_completed()
	ai_state.record_action(action)


func _check_phase(state: Dictionary) -> void:
	var controller: BossEncounterController = state["boss_controller"]
	if controller == null:
		return
	var transition: BossEncounterController.TransitionResult = controller.check_phase_transition()
	if transition != null:
		state["phase_reached"] = controller.runtime.current_phase_index + 1
		var boss: CombatActor = state["boss"]
		state["intents"].erase(boss.actor_id)
		if boss.is_alive():
			_plan_one_intent(state, boss, state["metrics"])


func _apply_turn_start(state: Dictionary, actor: CombatActor) -> void:
	var active_burn: StatusEffectInstance = actor.get_status(&"burn") if actor != null else null
	if actor != state["player"] and active_burn != null and active_burn.active:
		state["metrics"]["burn_active_enemy_turns"] += 1
		state["metrics"]["burn_max_stacks"] = maxi(int(state["metrics"]["burn_max_stacks"]), active_burn.stacks)
		if actor == state["boss"]:
			state["metrics"]["boss_burn_active_turns"] += 1
	var results: Array[CombatStatusController.TickResult] = (state["statuses"] as CombatStatusController).process_turn_start(actor)
	for result: CombatStatusController.TickResult in results:
		if actor == state["player"]:
			state["damage_taken"] += result.damage
			state["healing"] += result.healing
		elif result.damage > 0 and result.status.data.status_id == &"burn":
			state["metrics"]["burn_ticks"] += 1
			state["damage_dealt"] += result.damage
			state["metrics"]["damage_dealt"] += result.damage
			state["metrics"]["burn_damage"] += result.damage
			if actor == state["boss"]:
				state["metrics"]["boss_damage_dealt"] += result.damage
				state["metrics"]["boss_burn_damage"] += result.damage
	_check_phase(state)


func _deal_damage(state: Dictionary, target: CombatActor, amount: int, category: String) -> int:
	if target == null or amount <= 0:
		return 0
	var burn: StatusEffectInstance = target.get_status(&"burn")
	var actual: int = target.apply_damage(amount)
	state["damage_dealt"] += actual
	var metrics: Dictionary = state["metrics"]
	metrics["damage_dealt"] += actual
	metrics[category] = int(metrics.get(category, 0)) + actual
	if target == state["boss"]:
		metrics["boss_damage_dealt"] += actual
	if not target.is_alive() and burn != null and burn.active:
		metrics["burn_waste_stacks"] += burn.stacks
		metrics["burn_ticks_lost_on_death"] += burn.stacks * maxi(0, burn.remaining_duration)
	return actual


func _record_burn_application(applied: StatusEffectInstance, state: Dictionary, metrics: Dictionary) -> void:
	if applied == null or applied.data.status_id != &"burn":
		return
	metrics["burn_applications"] += 1
	metrics["burn_stack_samples"] += 1
	metrics["burn_stack_sum"] += applied.stacks
	metrics["burn_max_stacks"] = maxi(int(metrics["burn_max_stacks"]), applied.stacks)
	if int(metrics["first_burn_tile"]) < 0:
		metrics["first_burn_tile"] = (state["run"] as RunState).board_position
		metrics["first_burn_combat_turn"] = state["turns"]


func _add_energy_measured(skills: CombatSkillController, requested: int, metrics: Dictionary, run: RunState) -> int:
	if requested <= 0:
		return 0
	var before: int = skills.current_energy
	var gained: int = skills.add_energy(requested)
	var effective_requested: int = BiomeModifierResolver.effective_energy_gain(requested, run.biome_data, 1.0 + run.equipment_ember_gain_bonus)
	metrics["energy_generated"] += gained
	metrics["energy_wasted_at_cap"] += maxi(0, effective_requested - (skills.current_energy - before))
	metrics["energy_flow"]["CAP_WASTE"] += maxi(0, effective_requested - (skills.current_energy - before))
	return gained


func _add_damage_energy_measured(skills: CombatSkillController, damage: int, metrics: Dictionary) -> int:
	if damage <= 0:
		return 0
	var before: int = skills.current_energy
	var gained: int = skills.on_damage_received(damage)
	metrics["energy_generated"] += gained
	metrics["energy_wasted_at_cap"] += maxi(0, CombatSkillController.DAMAGE_RECEIVED_ENERGY - (skills.current_energy - before))
	metrics["energy_flow"]["CAP_WASTE"] += maxi(0, CombatSkillController.DAMAGE_RECEIVED_ENERGY - (skills.current_energy - before))
	return gained


func _effect_scale(effect_id: StringName) -> float:
	return maxf(0.0, float((_balance_overrides.get("effect_scales", {}) as Dictionary).get(String(effect_id), 1.0)))


func _effect_enabled(effect_id: StringName) -> bool:
	return _effect_scale(effect_id) > 0.0


func _record_trigger(metrics: Dictionary, effect_id: StringName) -> void:
	var key: String = String(effect_id)
	metrics["effect_triggers"][key] = int(metrics["effect_triggers"].get(key, 0)) + 1


func _effective_defense(state: Dictionary, actor: CombatActor) -> int:
	if actor == null:
		return 0
	var defense: int = actor.get_defense()
	if actor == state["player"]:
		defense = (state["boons"] as BoonController).get_effective_defense() + (state["skills"] as CombatSkillController).get_temporary_defense_bonus()
	elif actor.team == CombatActor.Team.ENEMY:
		defense += _enemy_defense_bonus(state, actor)
		var enemy_data: EnemyData = actor.source_data as EnemyData
		if enemy_data != null and enemy_data.id == &"ashen_warden":
			defense += int(_balance_overrides.get("warden_defense_delta", 0))
		defense = maxi(0, defense)
	return (state["statuses"] as CombatStatusController).get_effective_defense(actor, defense)


func _enemy_defense_bonus(state: Dictionary, actor: CombatActor) -> int:
	if actor == null:
		return 0
	var ai_state: EnemyAIRuntimeState = state["ai_states"].get(actor.actor_id) as EnemyAIRuntimeState
	var result: int = ai_state.get_defense_bonus() if ai_state != null else 0
	var controller: BossEncounterController = state["boss_controller"]
	if controller != null and controller.owns_actor(actor):
		result += controller.get_defense_bonus()
	return result


func _enemy_profile(state: Dictionary, actor: CombatActor) -> EnemyAIData:
	var data: EnemyData = actor.source_data as EnemyData
	var fallback: EnemyAIData = data.ai_profile
	var controller: BossEncounterController = state["boss_controller"]
	return controller.get_active_ai_profile(fallback) if controller != null and controller.owns_actor(actor) else fallback


func _alive_enemies(state: Dictionary) -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	for actor: CombatActor in state["enemies"]:
		if actor.is_alive():
			result.append(actor)
	return result


func _alive_players(state: Dictionary) -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	var player: CombatActor = state["player"]
	var companion: CombatActor = state["companion"]
	if player.is_targetable():
		result.append(player)
	if companion != null and companion.is_targetable():
		result.append(companion)
	return result


func _threat_summary(state: Dictionary) -> Dictionary:
	var total: int = 0
	var high_count: int = 0
	var lethal_count: int = 0
	for intent: EnemyIntent in state["intents"].values():
		if intent == null or intent.target_actor != state["player"]:
			continue
		total += maxi(0, intent.estimated_damage)
		if intent.intensity >= EnemyIntent.Intensity.HIGH:
			high_count += 1
		if intent.intensity == EnemyIntent.Intensity.LETHAL:
			lethal_count += 1
	return {"total": total, "high_count": high_count, "lethal_count": lethal_count}


func _resolve_level_ups(run: RunState, policy: StringName, metrics: Dictionary) -> void:
	while run.pending_level_ups > 0:
		var options: Array[UpgradeData]
		if _reward_rules == &"baseline":
			options = _baseline_level_options(run)
		else:
			options = BuildRewardResolver.generate_level_options(run, run.next_reward_offer_seed(&"sim_level"))
		run.level_up_choices_generated += 1
		if options.is_empty():
			run.pending_level_ups = 0
			break
		_record_offers(options, run, metrics)
		var chosen: UpgradeData = _choose_upgrade(options, policy, run)
		var active_before: Array[StringName] = run.activated_synergy_ids.duplicate()
		_apply_simulation_upgrade(chosen, run)
		run.record_run_level_upgrade(chosen)
		_record_new_synergies(run, active_before, metrics)
		_record_archetype(chosen.affinity, metrics)
		metrics["level_up_tiles"].append(run.board_position)
		metrics["upgrade_picks"][String(chosen.id)] = int(metrics["upgrade_picks"].get(String(chosen.id), 0)) + 1


func _resolve_post_combat_reward(run: RunState, policy: StringName, rng: RandomNumberGenerator, is_elite: bool, metrics: Dictionary) -> void:
	var augments: Array[SkillAugmentData] = SkillAugmentCatalog.get_eligible_for_run(run)
	var chance: float = RunRewardResolver.ELITE_AUGMENT_CHANCE if is_elite else RunRewardResolver.NORMAL_AUGMENT_CHANCE
	if not augments.is_empty() and rng.randf() < chance:
		var offered_augments: Array[SkillAugmentData] = augments if _reward_rules == &"baseline" else BuildRewardResolver.generate_augment_options(run, run.next_reward_offer_seed(&"sim_augment"))
		var augment: SkillAugmentData = _choose_augment(offered_augments, policy, run, rng)
		var active_before: Array[StringName] = run.activated_synergy_ids.duplicate()
		run.add_skill_augment(augment.id)
		_record_new_synergies(run, active_before, metrics)
		_record_archetype(_augment_affinity(augment), metrics)
		metrics["augment_picks"][String(augment.id)] = int(metrics["augment_picks"].get(String(augment.id), 0)) + 1
		return
	var rarity_audit: Dictionary = {"enabled": true}
	var options: Array[UpgradeData] = _generate_boon_options(is_elite, rng) if _reward_rules == &"baseline" else BuildRewardResolver.generate_boon_options(run, is_elite, run.next_reward_offer_seed(&"sim_boon"), "", rarity_audit, _rarity_mode)
	for rarity_key: String in rarity_audit.get("rarity_rolls", {}):
		metrics["rarity_rolls"][rarity_key] = int(metrics["rarity_rolls"].get(rarity_key, 0)) + int(rarity_audit["rarity_rolls"][rarity_key])
	metrics["rarity_fallbacks"] += int(rarity_audit.get("fallbacks", 0))
	_record_offers(options, run, metrics)
	var chosen: UpgradeData = _choose_upgrade(options, policy, run)
	var active_before: Array[StringName] = run.activated_synergy_ids.duplicate()
	if _reward_rules == &"baseline":
		run.active_boons[chosen.id] = run.get_boon_count(chosen.id) + 1
		run.recalculate_synergies()
	else:
		_apply_simulation_upgrade(chosen, run)
	_record_new_synergies(run, active_before, metrics)
	_record_archetype(chosen.affinity, metrics)
	run.upgrades_obtained += 1
	metrics["upgrade_picks"][String(chosen.id)] = int(metrics["upgrade_picks"].get(String(chosen.id), 0)) + 1


func _generate_boon_options(is_elite: bool, rng: RandomNumberGenerator) -> Array[UpgradeData]:
	var pool: Array[UpgradeData] = UpgradeCatalog.get_boons()
	var result: Array[UpgradeData] = []
	while result.size() < 3:
		var roll: float = rng.randf()
		var rarity: int
		if is_elite:
			rarity = UpgradeData.UpgradeRarity.COMMON if roll < 0.30 else (UpgradeData.UpgradeRarity.RARE if roll < 0.80 else UpgradeData.UpgradeRarity.EPIC)
		else:
			rarity = UpgradeData.UpgradeRarity.COMMON if roll < 0.65 else (UpgradeData.UpgradeRarity.RARE if roll < 0.95 else UpgradeData.UpgradeRarity.EPIC)
		var candidates: Array[UpgradeData] = []
		for upgrade: UpgradeData in pool:
			if upgrade.rarity == rarity and upgrade not in result:
				candidates.append(upgrade)
		if candidates.is_empty():
			for upgrade: UpgradeData in pool:
				if upgrade not in result:
					candidates.append(upgrade)
		result.append(candidates[rng.randi_range(0, candidates.size() - 1)])
	return result


func _choose_upgrade(options: Array[UpgradeData], policy: StringName, run: RunState) -> UpgradeData:
	if policy == &"random":
		return options[abs(run.board_seed + run.upgrades_obtained) % options.size()]
	var best: UpgradeData = options[0]
	var best_score: float = -1e9
	for upgrade: UpgradeData in options:
		var score: float = float(upgrade.rarity) * 1.5
		if upgrade.category == UpgradeData.Category.STAT:
			match policy:
				&"aggressive":
					score += 30.0 if upgrade.effect_type == UpgradeData.EffectType.ATTACK_AND_HEALTH_COST else (25.0 if upgrade.effect_type == UpgradeData.EffectType.ATTACK else 4.0)
				&"defensive":
					if upgrade.effect_type == UpgradeData.EffectType.DEFENSE:
						score += 28.0
					elif upgrade.effect_type in [UpgradeData.EffectType.MAX_HEALTH_AND_HEAL, UpgradeData.EffectType.HEAL]:
						score += 24.0
					elif upgrade.effect_type == UpgradeData.EffectType.ATTACK_AND_HEALTH_COST:
						score -= 20.0
				_:
					var low_hp: bool = run.current_health * 100 <= run.max_health * 55
					if low_hp and upgrade.effect_type in [UpgradeData.EffectType.MAX_HEALTH_AND_HEAL, UpgradeData.EffectType.HEAL]:
						score += 30.0
					elif upgrade.effect_type == UpgradeData.EffectType.DEFENSE:
						score += 18.0
					elif upgrade.effect_type == UpgradeData.EffectType.ATTACK:
						score += 16.0
					elif upgrade.effect_type == UpgradeData.EffectType.ATTACK_AND_HEALTH_COST:
						score += -15.0 if low_hp else 12.0
		else:
			if policy == &"aggressive":
				score += 20.0 if upgrade.affinity == UpgradeData.Affinity.OFFENSE else 0.0
			elif policy == &"defensive":
				score += 20.0 if upgrade.affinity in [UpgradeData.Affinity.DEFENSE, UpgradeData.Affinity.SUSTAIN] else 0.0
			else:
				score += 30.0 * SynergyResolver.get_activated_by_boon(run, upgrade.id).size()
				score += 12.0 if upgrade.affinity == UpgradeData.Affinity.SUSTAIN and run.current_health * 2 < run.max_health else 0.0
				score += 7.0 if upgrade.affinity == UpgradeData.Affinity.OFFENSE else 5.0
		if score > best_score:
			best_score = score
			best = upgrade
	return best


func _choose_augment(options: Array[SkillAugmentData], policy: StringName, run: RunState, rng: RandomNumberGenerator) -> SkillAugmentData:
	if policy == &"random":
		return options[rng.randi_range(0, options.size() - 1)]
	var preferred: StringName = &"ember_slash" if policy == &"aggressive" else (&"ashen_guard" if policy == &"defensive" else &"second_wind")
	for augment: SkillAugmentData in options:
		if augment.skill_id == preferred:
			return augment
	return options[0]


func _resolve_event(run: RunState, biome: BiomeData, policy: StringName, rng: RandomNumberGenerator, metrics: Dictionary) -> void:
	var event: EventData
	if _event_treasure_agency:
		event = EventResolver.select_for_run(biome.event_pool, run)
	else:
		var legacy_pool: Array[EventData] = []
		for candidate: EventData in biome.event_pool:
			if candidate.id != &"wanderer_return":
				legacy_pool.append(candidate)
		event = legacy_pool[rng.randi_range(0, legacy_pool.size() - 1)]
	if event == null:
		metrics["events"] += 1
		return
	metrics["events_seen_ids"][String(event.id)] = int(metrics["events_seen_ids"].get(String(event.id), 0)) + 1
	metrics["event_options_shown"] += 2
	metrics["event_meaningful_choices"] += 1
	var resolved_policy: StringName = _resolved_event_policy(policy)
	var valid_options: Array[bool] = [EventResolver.can_choose(event, true, run), EventResolver.can_choose(event, false, run)]
	var choose_a: bool
	if resolved_policy == &"event_random":
		choose_a = rng.randi_range(0, 1) == 0
	else:
		choose_a = _event_agency_score(event, true, run, resolved_policy, policy) >= _event_agency_score(event, false, run, resolved_policy, policy)
	if not valid_options[0]: choose_a = false
	if not valid_options[1]: choose_a = true
	var before: int = run.current_health
	var ash_before: int = run.run_ash
	var flags_before: int = run.event_flag_ids.size()
	var resolution: Dictionary = EventApplier.apply_detailed(event, choose_a, run)
	metrics["healing"] += maxi(0, run.current_health - before)
	metrics["event_hp_cost"] += maxi(0, before - run.current_health)
	metrics["event_ash_cost"] += maxi(0, ash_before - run.run_ash)
	metrics["event_flags_set"] += maxi(0, run.event_flag_ids.size() - flags_before)
	var reward_type: String = String(resolution.get("reward_type", "none"))
	metrics["event_rewards_received"][reward_type] = int(metrics["event_rewards_received"].get(reward_type, 0)) + 1
	if run.has_event_flag(&"wanderer_chain_completed"):
		metrics["event_chain_completions"] = 1
	metrics["events"] += 1
	run.events_resolved += 1
	if event.id not in run.seen_event_ids:
		run.seen_event_ids.append(event.id)
	var key: String = "%s:%s" % [event.id, "a" if choose_a else "b"]
	metrics["event_choices"][key] = int(metrics["event_choices"].get(key, 0)) + 1


func _resolved_event_policy(combat_policy: StringName) -> StringName:
	if _event_policy != &"matched": return _event_policy
	match combat_policy:
		&"random": return &"event_random"
		&"aggressive": return &"event_risky"
		&"defensive": return &"event_safe"
		_: return &"event_build"


func _event_agency_score(event: EventData, option_a: bool, run: RunState, event_policy: StringName, combat_policy: StringName) -> float:
	if not EventResolver.can_choose(event, option_a, run): return -100000.0
	var hp: int = event.option_a_health_delta if option_a else event.option_b_health_delta
	var max_hp: int = event.option_a_max_health_delta if option_a else event.option_b_max_health_delta
	var attack: int = event.option_a_attack_delta if option_a else event.option_b_attack_delta
	var defense: int = event.option_a_defense_delta if option_a else event.option_b_defense_delta
	var ash: int = event.option_a_run_ash_delta if option_a else event.option_b_run_ash_delta
	var reward: EventData.OptionReward = event.option_a_reward if option_a else event.option_b_reward
	var set_flags: Array[StringName] = event.option_a_set_flag_ids if option_a else event.option_b_set_flag_ids
	if event_policy == &"event_safe":
		return hp * 3.0 + max_hp * 1.5 + defense * 4.0 + ash * 0.2 - (20.0 if hp < 0 else 0.0)
	if event_policy == &"event_risky":
		return attack * 6.0 + defense * 3.0 + max_hp * 2.0 + ash * 0.3 + (30.0 if reward != EventData.OptionReward.NONE else 0.0) + hp * 0.35
	var build_bonus: float = 35.0 if reward != EventData.OptionReward.NONE else 0.0
	if &"helped_lost_wanderer" in set_flags:
		build_bonus += 20.0
	if combat_policy == &"aggressive": build_bonus += attack * 6.0
	elif combat_policy == &"defensive": build_bonus += defense * 6.0 + hp
	else: build_bonus += attack * 3.0 + defense * 3.0 + max_hp
	return build_bonus + ash * 0.15 + hp * 0.5


func _event_score(event: EventData, option_a: bool, run: RunState, policy: StringName) -> float:
	var hp: int = event.option_a_health_delta if option_a else event.option_b_health_delta
	var max_hp: int = event.option_a_max_health_delta if option_a else event.option_b_max_health_delta
	var attack: int = event.option_a_attack_delta if option_a else event.option_b_attack_delta
	var defense: int = event.option_a_defense_delta if option_a else event.option_b_defense_delta
	var ash: int = event.option_a_run_ash_delta if option_a else event.option_b_run_ash_delta
	if policy == &"aggressive":
		return attack * 5.0 + max_hp + hp * 0.5 + ash * 0.1
	if policy == &"defensive":
		return hp * 2.0 + max_hp * 1.5 + defense * 5.0 + ash * 0.05
	return hp + max_hp + attack * 3.0 + defense * 3.0 + ash * 0.2 - (1000.0 if run.current_health + hp <= 0 else 0.0)


func _resolve_treasure(run: RunState, rng: RandomNumberGenerator, metrics: Dictionary) -> void:
	if _event_treasure_agency:
		var offers: Array[Dictionary] = TreasureChoiceResolver.generate_offers(run)
		metrics["treasure_options_shown"] += offers.size()
		metrics["treasure_meaningful_choices"] += 1 if offers.size() >= 2 else 0
		var offer: Dictionary = _choose_treasure_offer(offers, _resolved_treasure_policy(metrics["policy"]), rng)
		var before_hp: int = run.current_health
		var resolution: Dictionary = TreasureChoiceResolver.apply_offer(run, offer)
		metrics["healing"] += maxi(0, run.current_health - before_hp)
		var offer_id: String = String(offer.get("id", "invalid"))
		var kind: String = String(resolution.get("kind", "none"))
		metrics["treasure_choices"][offer_id] = int(metrics["treasure_choices"].get(offer_id, 0)) + 1
		metrics["treasure_reward_types"][kind] = int(metrics["treasure_reward_types"].get(kind, 0)) + 1
		metrics["treasures"] += 1
		return
	var reward: TreasureReward.Reward = rng.randi_range(0, TreasureReward.Reward.size() - 1)
	var before_hp: int = run.current_health
	var missing_before: int = run.max_health - before_hp
	TreasureReward.apply(reward, run)
	var healed: int = maxi(0, run.current_health - before_hp)
	metrics["healing"] += healed
	if reward == TreasureReward.Reward.HEAL:
		metrics["overheal"] += maxi(0, 25 - missing_before)
	metrics["treasures"] += 1
	run.treasures_found += 1
	metrics["treasure_rewards"][str(reward)] = int(metrics["treasure_rewards"].get(str(reward), 0)) + 1


func _resolved_treasure_policy(combat_policy: StringName) -> StringName:
	if _treasure_policy != &"matched": return _treasure_policy
	match combat_policy:
		&"random": return &"treasure_random"
		&"aggressive": return &"treasure_power"
		&"defensive": return &"treasure_ash"
		_: return &"treasure_build"


func _choose_treasure_offer(offers: Array[Dictionary], treasure_policy: StringName, rng: RandomNumberGenerator) -> Dictionary:
	if offers.is_empty(): return {}
	if treasure_policy == &"treasure_random": return offers[rng.randi_range(0, offers.size() - 1)]
	var preferred: Array[String]
	match treasure_policy:
		&"treasure_ash": preferred = [TreasureChoiceResolver.KIND_ASH, TreasureChoiceResolver.KIND_RECOVERY, TreasureChoiceResolver.KIND_BOON, TreasureChoiceResolver.KIND_AUGMENT]
		&"treasure_power": preferred = [TreasureChoiceResolver.KIND_BOON, TreasureChoiceResolver.KIND_AUGMENT, TreasureChoiceResolver.KIND_RECOVERY, TreasureChoiceResolver.KIND_ASH]
		_: preferred = [TreasureChoiceResolver.KIND_BOON, TreasureChoiceResolver.KIND_AUGMENT, TreasureChoiceResolver.KIND_ASH, TreasureChoiceResolver.KIND_RECOVERY]
	for kind: String in preferred:
		for offer: Dictionary in offers:
			if String(offer.get("kind", "")) == kind: return offer
	return offers[0]


func _apply_heal(run: RunState, amount: int, metrics: Dictionary) -> void:
	var missing: int = run.max_health - run.current_health
	var healed: int = run.heal(amount)
	metrics["healing"] += healed
	metrics["overheal"] += maxi(0, amount - missing)


func _apply_simulation_upgrade(upgrade: UpgradeData, run: RunState) -> void:
	if upgrade == null:
		return
	if upgrade.category == UpgradeData.Category.PASSIVE:
		run.add_boon(upgrade.id)
		return
	var scale: float = _effect_scale(upgrade.id)
	var stack_caps: Dictionary = _balance_overrides.get("max_effect_stacks", {})
	if run.get_run_level_upgrade_count(upgrade.id) >= int(stack_caps.get(String(upgrade.id), 999)):
		scale = 0.0
	var primary: int = maxi(0, roundi(float(upgrade.primary_value) * scale))
	var secondary: int = maxi(0, roundi(float(upgrade.secondary_value) * scale))
	match upgrade.effect_type:
		UpgradeData.EffectType.MAX_HEALTH_AND_HEAL:
			run.max_health += primary
			run.heal_structural(secondary)
		UpgradeData.EffectType.ATTACK:
			run.attack += primary
		UpgradeData.EffectType.DEFENSE:
			run.defense += primary
		UpgradeData.EffectType.HEAL:
			run.heal(primary)
		UpgradeData.EffectType.ATTACK_AND_HEALTH_COST:
			run.attack += primary
			run.current_health = maxi(1, run.current_health - secondary)


func _finalize_rewards(run: RunState, policy: StringName, rng: RandomNumberGenerator, metrics: Dictionary) -> void:
	if run.run_completed:
		var rewards: Array[BossRewardData] = BossRewardCatalog.get_all() if _reward_rules == &"baseline" else BuildRewardResolver.generate_boss_options(run, run.next_reward_offer_seed(&"sim_boss"), 3)
		var reward: BossRewardData
		var preferred_id: StringName = &"ashen_bounty" if policy == &"aggressive" else (&"spoils_of_the_warden" if policy == &"defensive" else (&"pyres_favor" if policy == &"tactical" else &""))
		for option: BossRewardData in rewards:
			if option.id == preferred_id:
				reward = option
				break
		if reward == null:
			reward = rewards[rng.randi_range(0, rewards.size() - 1)]
		BossRewardCatalog.apply(reward, run)
	EquipmentCatalog._rng.seed = absi(run.board_seed ^ String(policy).hash() ^ 0x1007)
	run.prepare_loot(run.run_completed)
	metrics["deposit_simulated"] = true
	metrics["deposit_written"] = false


func _record_offers(options: Array[UpgradeData], run: RunState, metrics: Dictionary) -> void:
	var useful: int = 0
	for upgrade: UpgradeData in options:
		metrics["upgrade_offers"][String(upgrade.id)] = int(metrics["upgrade_offers"].get(String(upgrade.id), 0)) + 1
		var quality: int = BuildRewardResolver.classify_boon(run, upgrade) if upgrade.category == UpgradeData.Category.PASSIVE else _classify_stat_offer(run, upgrade)
		var quality_key: String = ["off_build", "neutral", "on_build", "synergy_completing"][quality]
		metrics["offer_quality"][quality_key] = int(metrics["offer_quality"][quality_key]) + 1
		# OFF_BUILD es la única categoría no relevante. Una opción NEUTRAL
		# sigue siendo una elección funcional y no debe contarse como inútil.
		if quality != BuildRewardResolver.OfferQuality.OFF_BUILD:
			useful += 1
	var set_key: String = "no_useful" if useful == 0 else ("one_useful" if useful == 1 else "multiple_useful")
	metrics["offer_sets"][set_key] = int(metrics["offer_sets"][set_key]) + 1


func _record_curve_point(run: RunState, metrics: Dictionary) -> void:
	metrics["curve"].append({
		"tile": run.board_position,
		"hp": run.current_health,
		"max_hp": run.max_health,
		"attack": run.attack,
		"defense": run.defense,
		"level": run.run_level,
		"upgrades": run.upgrades_obtained,
		"ash": run.run_ash,
	})


func _baseline_level_options(run: RunState) -> Array[UpgradeData]:
	var pool: Array[UpgradeData] = RunLevelConfig.get_level_up_pool(run)
	var result: Array[UpgradeData] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = run.board_seed ^ (run.level_up_choices_generated * 104729) ^ (run.run_level * 8191)
	while not pool.is_empty() and result.size() < RunLevelConfig.OPTION_COUNT:
		var index: int = rng.randi_range(0, pool.size() - 1)
		result.append(pool[index])
		pool.remove_at(index)
	return result


func _record_new_synergies(run: RunState, before: Array[StringName], metrics: Dictionary) -> void:
	for synergy_id: StringName in run.activated_synergy_ids:
		if synergy_id not in before and not metrics["synergy_activation_tiles"].has(String(synergy_id)):
			metrics["synergy_activation_tiles"][String(synergy_id)] = run.board_position


func _record_archetype(affinity: int, metrics: Dictionary) -> void:
	var key: String = _affinity_key(affinity)
	if not key.is_empty():
		metrics["reward_archetype_counts"][key] = int(metrics["reward_archetype_counts"].get(key, 0)) + 1


func _augment_affinity(augment: SkillAugmentData) -> int:
	var offense: int = 0
	var defense: int = 0
	var sustain: int = 0
	for tag: StringName in augment.tags:
		if tag in [&"attack", &"burn", &"ember", &"crit"]:
			offense += 1
		elif tag in [&"guard", &"defense"]:
			defense += 1
		elif tag in [&"heal", &"regen"]:
			sustain += 1
	if offense >= defense and offense >= sustain and offense > 0:
		return UpgradeData.Affinity.OFFENSE
	if defense >= sustain and defense > 0:
		return UpgradeData.Affinity.DEFENSE
	return UpgradeData.Affinity.SUSTAIN if sustain > 0 else UpgradeData.Affinity.NONE


func _classify_stat_offer(run: RunState, upgrade: UpgradeData) -> int:
	if upgrade.affinity == UpgradeData.Affinity.NONE:
		return BuildRewardResolver.OfferQuality.NEUTRAL
	var current: int = int(metrics_dummy_affinity_count(run, upgrade.affinity))
	if current > 0:
		return BuildRewardResolver.OfferQuality.ON_BUILD
	var dominant: int = _dominant_run_affinity(run)
	return BuildRewardResolver.OfferQuality.OFF_BUILD if dominant != UpgradeData.Affinity.NONE and dominant != upgrade.affinity else BuildRewardResolver.OfferQuality.NEUTRAL


func metrics_dummy_affinity_count(run: RunState, affinity: int) -> int:
	var total: int = run.get_affinity_count(affinity)
	for upgrade_id: StringName in run.run_level_upgrade_stacks:
		var upgrade: UpgradeData = UpgradeCatalog.get_by_id(upgrade_id)
		if upgrade != null and upgrade.affinity == affinity:
			total += run.get_run_level_upgrade_count(upgrade_id)
	return total


func _dominant_run_affinity(run: RunState) -> int:
	var best: int = UpgradeData.Affinity.NONE
	var best_count: int = 0
	for affinity: int in [UpgradeData.Affinity.OFFENSE, UpgradeData.Affinity.DEFENSE, UpgradeData.Affinity.SUSTAIN]:
		var count: int = metrics_dummy_affinity_count(run, affinity)
		if count > best_count:
			best = affinity
			best_count = count
	return best


func _affinity_key(affinity: int) -> String:
	match affinity:
		UpgradeData.Affinity.OFFENSE: return "offense"
		UpgradeData.Affinity.DEFENSE: return "defense"
		UpgradeData.Affinity.SUSTAIN: return "sustain"
	return ""


func _primary_build(counts: Dictionary) -> String:
	var best: String = "mixed"
	var best_count: int = 0
	var tied: bool = false
	for key: String in ["offense", "defense", "sustain"]:
		var count: int = int(counts.get(key, 0))
		if count > best_count:
			best = key
			best_count = count
			tied = false
		elif count == best_count and count > 0:
			tied = true
	return "mixed" if tied or best_count == 0 else best


func _run_tests() -> int:
	SynergyResolver.use_stage62_baseline_rules = _reward_rules == &"baseline"
	var failures: Array[String] = []
	var resource_iron_skin_value: int = UpgradeCatalog.IRON_SKIN.primary_value
	var first: Dictionary = _simulate_run(&"ashen_wastes", &"tactical", 620001)
	var second: Dictionary = _simulate_run(&"ashen_wastes", &"tactical", 620001)
	if first["result_hash"] != second["result_hash"]:
		failures.append("same_seed_same_policy_not_deterministic")
	if first["board_hash"] != second["board_hash"]:
		failures.append("board_not_deterministic")
	if not BoardGenerator.validate(_board_for_seed(&"ashen_wastes", 620001), BiomeCatalog.get_or_default(&"ashen_wastes")):
		failures.append("board_invariant_failed")
	if int(first["xp"]) < 0 or int(first["ash"]) < 0:
		failures.append("negative_progression")
	if bool(first.get("deposit_written", true)):
		failures.append("save_pollution_contract")
	var saved_overrides: Dictionary = _balance_overrides.duplicate(true)
	_balance_overrides["effect_scales"]["iron_skin"] = 0.0
	var override_first: Dictionary = _simulate_run(&"ashen_wastes", &"tactical", 620001)
	var override_second: Dictionary = _simulate_run(&"ashen_wastes", &"tactical", 620001)
	if override_first["result_hash"] != override_second["result_hash"]:
		failures.append("override_not_deterministic")
	_balance_overrides = saved_overrides
	var after_override: Dictionary = _simulate_run(&"ashen_wastes", &"tactical", 620001)
	if first["result_hash"] != after_override["result_hash"]:
		failures.append("override_leaked_between_runs")
	if UpgradeCatalog.IRON_SKIN.primary_value != resource_iron_skin_value:
		failures.append("override_mutated_resource")
	var carry_run: RunState = RunState.new()
	carry_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	var carry_controller: CombatSkillController = CombatSkillController.new(carry_run.equipped_skill_ids, carry_run)
	carry_controller.current_energy = 99
	if carry_controller.store_combat_carryover() != 19 or carry_run.combat_energy_carryover != 19:
		failures.append("energy_carryover_not_twenty_percent")
	var restored_controller: CombatSkillController = CombatSkillController.new(carry_run.equipped_skill_ids, carry_run)
	if restored_controller.current_energy != 19 or carry_run.combat_energy_carryover != 0:
		failures.append("energy_carryover_restore_or_reset_failed")
	if restored_controller.current_energy > CombatSkillController.MAX_ENERGY:
		failures.append("energy_carryover_exceeded_cap")
	var second_wind: ActiveSkillController = restored_controller.get_by_id(&"second_wind")
	if second_wind != null and restored_controller.can_use(second_wind):
		failures.append("carryover_granted_immediate_second_wind")
	restored_controller.current_energy = 100
	restored_controller.store_combat_carryover(false)
	if carry_run.combat_energy_carryover != 0:
		failures.append("defeat_did_not_clear_carryover")
	for numeric_key: String in ["damage_dealt", "damage_taken", "energy_generated", "energy_spent", "energy_wasted_at_cap", "burn_damage"]:
		if int(first.get(numeric_key, -1)) < 0:
			failures.append("negative_metric_%s" % numeric_key)
	for combat: Dictionary in first["combat_log"]:
		if int(combat["turns"]) > MAX_COMBAT_TURNS:
			failures.append("combat_exceeded_turn_cap")
	var defeat_found: bool = false
	var boss_reached: bool = false
	var victory_found: bool = false
	for index: int in range(200):
		var probe: Dictionary = _simulate_run(&"ember_marsh", &"random", 621000 + index * 104729)
		defeat_found = defeat_found or probe["outcome"] == "defeat"
		victory_found = victory_found or probe["outcome"] == "victory"
		boss_reached = boss_reached or probe["boss_outcome"] != "not_reached"
		if defeat_found and victory_found and boss_reached:
			break
	if not defeat_found:
		failures.append("defeat_path_not_observed_200_seeds")
	if not victory_found:
		failures.append("victory_path_not_observed_200_seeds")
	if not boss_reached:
		failures.append("boss_not_reached_200_seeds")
	var report: Dictionary = {
		"schema": SCHEMA_VERSION,
		"failures": failures,
		"deterministic_hash": first["result_hash"],
		"board_hash": first["board_hash"],
		"save_or_profile_written": false,
		"victory_path_observed": victory_found,
		"defeat_path_observed": defeat_found,
		"boss_reached": boss_reached,
	}
	_write_json(_output_path.get_base_dir().path_join("simulation_tests.json"), report)
	print(JSON.stringify(report))
	return 0 if failures.is_empty() else 1


func _board_for_seed(biome_id: StringName, seed: int) -> Array[int]:
	var run: RunState = RunState.new()
	var biome: BiomeData = BiomeCatalog.get_or_default(biome_id)
	BoardGenerator.generate_for_run(run, biome, seed)
	return run.board_tile_sequence


func _write_json(path: String, value: Variant) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value, "  "))
		file.close()


func _counter_to_plain(counter: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in counter:
		result[String(key)] = int(counter[key])
	return result


func _names_to_strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result


func _enemy_ids(values: Array[EnemyData]) -> Array[String]:
	var result: Array[String] = []
	for value: EnemyData in values:
		result.append(String(value.id))
	return result


func _profile_is_disruptive(profile: EnemyAIData) -> bool:
	if profile == null:
		return false
	for action: EnemyActionData in profile.actions:
		if action != null and action.action_type == EnemyAIEnums.ActionType.ATTACK_STATUS:
			return true
	return false


func _build_tag_counts(report: BuildTagReport) -> Dictionary:
	var result: Dictionary = {}
	for tag: StringName in BuildTagResolver.ALL_TAGS:
		var count: int = report.get_count(tag)
		if count > 0:
			result[String(tag)] = count
	return result

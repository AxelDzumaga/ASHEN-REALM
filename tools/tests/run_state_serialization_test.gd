extends Node

## RunState.to_dictionary()/from_dictionary() round-trip, per §44: a
## deliberately non-default fixture across every persisted field, so no
## comparison can accidentally pass because both sides used the same
## default. Also covers a couple of malformed-input hardening cases.

const RouteBranchDataSource = preload("res://scripts/board/route_branch_data.gd")

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	_test_full_round_trip()
	_test_dropped_legacy_fields_do_not_survive()
	_test_missing_route_branch_dropped_not_crashed()
	_test_biome_data_rederived_from_id()
	_test_large_realistic_board_seed_survives_round_trip()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _build_fixture() -> RunState:
	var run := RunState.new()
	run.run_id = "char_000000_abcdef_run_1234567890_fedcba"
	run.started_at_unix = 1700000000
	run.biome_id = BiomeCatalog.EMBER_MARSH.id
	run.biome_data = BiomeCatalog.EMBER_MARSH
	run.board_seed = 987654321
	run.board_tile_sequence = [0, 3, 4, 1, 5, 2, 6, 0, 3, 2]
	var route_a: Array[int] = [BoardTileData.TileType.COMBAT, BoardTileData.TileType.EVENT, BoardTileData.TileType.HEAL, BoardTileData.TileType.EMPTY, BoardTileData.TileType.TREASURE, BoardTileData.TileType.COMBAT]
	var route_b: Array[int] = [BoardTileData.TileType.HEAL, BoardTileData.TileType.HEAL, BoardTileData.TileType.EVENT, BoardTileData.TileType.TREASURE, BoardTileData.TileType.EMPTY, BoardTileData.TileType.COMBAT]
	run.route_branches = {3: RouteBranchDataSource.new(3, route_a, route_b, &"combat", &"recovery")}
	run.last_normal_encounter_signature = &"template_alpha:brute+wretch"
	run.biome_intro_shown = true
	run.player_name = "Fixture Wanderer"
	run.active_skill_id = &"ashen_guard"
	run.equipped_skill_ids = [&"ember_slash", &"ashen_guard", &"second_wind"]
	run.equipped_companion_id = &"ember_hound"
	run.equipped_weapon_id = &"ashen_blade"
	run.equipped_armor_id = &"wardens_plate"
	run.owned_equipment_ids_at_start = ["ashen_blade", "wardens_plate", "old_cloak"]
	run.max_health = 173
	run.current_health = 121
	run.attack = 47
	run.defense = 22
	run.board_position = 12
	run.board_locked = true
	run.active_branch = RouteBranchDataSource.ROUTE_B
	run.active_fork_index = 3
	run.combats_won = 5
	run.elites_won = 2
	run.events_resolved = 3
	run.treasures_found = 4
	run.event_flag_ids = [&"shrine_blessed", &"wanderer_met"]
	run.seen_event_ids = [&"shrine_encounter", &"wanderer_return"]
	run.resolved_event_positions = [2, 7]
	run.resolved_treasure_positions = [5]
	run.pending_treasure_position = 9
	run.pending_treasure_offers = [
		{"id": "boon:ember_focus", "kind": "boon", "reward_id": "ember_focus", "label": "BRASA", "description": "test"},
		{"id": "ash", "kind": "ash", "reward_id": "", "label": "CENIZA", "description": "test"},
	]
	run.upgrades_obtained = 6
	run.run_completed = false
	run.run_ash = 340
	run.biome_material_earned = 12
	run.rewards_deposited = false
	run.player_xp_earned = 88
	run.player_level_before = 3
	run.player_level_after = 4
	run.player_xp_before = 40
	run.player_xp_after = 8
	run.player_levels_gained = 1
	run.completed_milestone_ids_this_run = [&"first_expedition"]
	run.milestone_ash_awarded = 25
	run.newly_unlocked_biome_ids = [&"ember_marsh"]
	run.loot_rolled = true
	run.pending_loot_id = "wardens_edge"
	run.duplicate_converted_id = &"old_cloak"
	run.duplicate_ash_awarded = 15
	run.boss_reward_id = &"ashen_bounty"
	run.boss_reward_applied = true
	run.boss_chest_id = &"ashen_warden_chest"
	run.boss_chest_awarded = true
	run.guardian_sigils_awarded = 3
	run.loot_minimum_rarity = EquipmentData.Rarity.RARE
	run.loot_rarity_upgrades = 1
	run.active_boons = {&"burning_strike": 2, &"relentless_flame": 1}
	run.skill_augments = {&"ember_slash_burn": 1}
	run.active_synergy_ids = [&"inferno_rhythm"]
	run.activated_synergy_ids = [&"inferno_rhythm"]
	run.pending_synergy_announcement_ids = [&"inferno_rhythm"]
	run.upgrade_rerolls = 1
	run.reward_offers_generated = 4
	run.phoenix_blood_empowered = true
	run.combat_energy_carryover = 30
	run.run_level = 6
	run.current_xp = 15
	run.total_xp_gained = 210
	run.pending_level_ups = 1
	run.level_up_choices_generated = 2
	run.pending_level_up_option_ids = [&"iron_vigil_node", &"ember_focus_node"]
	run.pending_reward_is_elite = true
	run.run_level_upgrade_stacks = {&"iron_vigil_node": 2}
	run.equipment_passive_ids = [&"ashen_blade_passive"]
	run.equipment_crit_chance = 0.15
	run.equipment_crit_damage_bonus = 0.5
	run.equipment_ember_gain_bonus = 0.1
	run.equipment_healing_power_bonus = 0.2
	run.equipment_skill_damage_bonus = 0.25
	run.equipment_resistance_bonuses = {&"frost": 0.3}
	run.telemetry_started = true
	run.telemetry_finished = false
	run.telemetry_started_unix = 1700000005
	run.telemetry_skill_uses = {"ember_slash": 4, "ashen_guard": 2}
	run.telemetry_synergy_ids = [&"inferno_rhythm"]
	run.telemetry_last_boss_id = &"ashen_warden"
	run.telemetry_boss_phase_reached = 2
	run.starting_option_id = &"ember_focus"
	return run


func _test_full_round_trip() -> void:
	var original: RunState = _build_fixture()
	var json_text: String = JSON.stringify(original.to_dictionary())
	var parsed: Variant = JSON.parse_string(json_text)
	_check("parses_back_as_dictionary", typeof(parsed) == TYPE_DICTIONARY)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var restored: RunState = RunState.from_dictionary(parsed)

	_check("run_id", restored.run_id == original.run_id)
	_check("started_at_unix", restored.started_at_unix == original.started_at_unix)
	_check("biome_id", restored.biome_id == original.biome_id)
	_check("biome_data_rederived", restored.biome_data == BiomeCatalog.EMBER_MARSH)
	_check("board_seed", restored.board_seed == original.board_seed)
	_check("board_tile_sequence", restored.board_tile_sequence == original.board_tile_sequence)
	_check("route_branches_count", restored.route_branches.size() == 1)
	var restored_branch: RouteBranchData = restored.route_branches.get(3)
	_check("route_branch_present", restored_branch != null)
	if restored_branch != null:
		_check("route_branch_route_a", restored_branch.route_a == original.route_branches[3].route_a)
		_check("route_branch_archetype_a", restored_branch.archetype_a == original.route_branches[3].archetype_a)
	_check("last_normal_encounter_signature", restored.last_normal_encounter_signature == original.last_normal_encounter_signature)
	_check("biome_intro_shown", restored.biome_intro_shown == original.biome_intro_shown)
	_check("player_name", restored.player_name == original.player_name)
	_check("active_skill_id", restored.active_skill_id == original.active_skill_id)
	_check("equipped_skill_ids", restored.equipped_skill_ids == original.equipped_skill_ids)
	_check("equipped_companion_id", restored.equipped_companion_id == original.equipped_companion_id)
	_check("equipped_weapon_id", restored.equipped_weapon_id == original.equipped_weapon_id)
	_check("equipped_armor_id", restored.equipped_armor_id == original.equipped_armor_id)
	_check("owned_equipment_ids_at_start", restored.owned_equipment_ids_at_start == original.owned_equipment_ids_at_start)
	_check("max_health", restored.max_health == original.max_health)
	_check("current_health", restored.current_health == original.current_health)
	_check("attack", restored.attack == original.attack)
	_check("defense", restored.defense == original.defense)
	_check("board_position", restored.board_position == original.board_position)
	_check("board_locked", restored.board_locked == original.board_locked)
	_check("active_branch", restored.active_branch == original.active_branch)
	_check("active_fork_index", restored.active_fork_index == original.active_fork_index)
	_check("combats_won", restored.combats_won == original.combats_won)
	_check("elites_won", restored.elites_won == original.elites_won)
	_check("events_resolved", restored.events_resolved == original.events_resolved)
	_check("treasures_found", restored.treasures_found == original.treasures_found)
	_check("event_flag_ids", restored.event_flag_ids == original.event_flag_ids)
	_check("seen_event_ids", restored.seen_event_ids == original.seen_event_ids)
	_check("resolved_event_positions", restored.resolved_event_positions == original.resolved_event_positions)
	_check("resolved_treasure_positions", restored.resolved_treasure_positions == original.resolved_treasure_positions)
	_check("pending_treasure_position", restored.pending_treasure_position == original.pending_treasure_position)
	_check("pending_treasure_offers_count", restored.pending_treasure_offers.size() == original.pending_treasure_offers.size())
	_check("pending_treasure_offers_content", restored.pending_treasure_offers[0].get("id") == original.pending_treasure_offers[0].get("id"))
	_check("upgrades_obtained", restored.upgrades_obtained == original.upgrades_obtained)
	_check("run_completed", restored.run_completed == original.run_completed)
	_check("run_ash", restored.run_ash == original.run_ash)
	_check("biome_material_earned", restored.biome_material_earned == original.biome_material_earned)
	_check("rewards_deposited", restored.rewards_deposited == original.rewards_deposited)
	_check("player_xp_earned", restored.player_xp_earned == original.player_xp_earned)
	_check("player_level_before", restored.player_level_before == original.player_level_before)
	_check("player_level_after", restored.player_level_after == original.player_level_after)
	_check("player_xp_before", restored.player_xp_before == original.player_xp_before)
	_check("player_xp_after", restored.player_xp_after == original.player_xp_after)
	_check("player_levels_gained", restored.player_levels_gained == original.player_levels_gained)
	_check("completed_milestone_ids_this_run", restored.completed_milestone_ids_this_run == original.completed_milestone_ids_this_run)
	_check("milestone_ash_awarded", restored.milestone_ash_awarded == original.milestone_ash_awarded)
	_check("newly_unlocked_biome_ids", restored.newly_unlocked_biome_ids == original.newly_unlocked_biome_ids)
	_check("loot_rolled", restored.loot_rolled == original.loot_rolled)
	_check("pending_loot_id", restored.pending_loot_id == original.pending_loot_id)
	_check("duplicate_converted_id", restored.duplicate_converted_id == original.duplicate_converted_id)
	_check("duplicate_ash_awarded", restored.duplicate_ash_awarded == original.duplicate_ash_awarded)
	_check("boss_reward_id", restored.boss_reward_id == original.boss_reward_id)
	_check("boss_reward_applied", restored.boss_reward_applied == original.boss_reward_applied)
	_check("boss_chest_id", restored.boss_chest_id == original.boss_chest_id)
	_check("boss_chest_awarded", restored.boss_chest_awarded == original.boss_chest_awarded)
	_check("guardian_sigils_awarded", restored.guardian_sigils_awarded == original.guardian_sigils_awarded)
	_check("loot_minimum_rarity", restored.loot_minimum_rarity == original.loot_minimum_rarity)
	_check("loot_rarity_upgrades", restored.loot_rarity_upgrades == original.loot_rarity_upgrades)
	_check("active_boons", restored.active_boons == original.active_boons)
	_check("skill_augments", restored.skill_augments == original.skill_augments)
	_check("active_synergy_ids", restored.active_synergy_ids == original.active_synergy_ids)
	_check("activated_synergy_ids", restored.activated_synergy_ids == original.activated_synergy_ids)
	_check("pending_synergy_announcement_ids", restored.pending_synergy_announcement_ids == original.pending_synergy_announcement_ids)
	_check("upgrade_rerolls", restored.upgrade_rerolls == original.upgrade_rerolls)
	_check("reward_offers_generated", restored.reward_offers_generated == original.reward_offers_generated)
	_check("phoenix_blood_empowered", restored.phoenix_blood_empowered == original.phoenix_blood_empowered)
	_check("combat_energy_carryover", restored.combat_energy_carryover == original.combat_energy_carryover)
	_check("run_level", restored.run_level == original.run_level)
	_check("current_xp", restored.current_xp == original.current_xp)
	_check("total_xp_gained", restored.total_xp_gained == original.total_xp_gained)
	_check("pending_level_ups", restored.pending_level_ups == original.pending_level_ups)
	_check("level_up_choices_generated", restored.level_up_choices_generated == original.level_up_choices_generated)
	_check("pending_level_up_option_ids", restored.pending_level_up_option_ids == original.pending_level_up_option_ids)
	_check("pending_reward_is_elite", restored.pending_reward_is_elite == original.pending_reward_is_elite)
	_check("run_level_upgrade_stacks", restored.run_level_upgrade_stacks == original.run_level_upgrade_stacks)
	_check("equipment_passive_ids", restored.equipment_passive_ids == original.equipment_passive_ids)
	_check("equipment_crit_chance", is_equal_approx(restored.equipment_crit_chance, original.equipment_crit_chance))
	_check("equipment_crit_damage_bonus", is_equal_approx(restored.equipment_crit_damage_bonus, original.equipment_crit_damage_bonus))
	_check("equipment_ember_gain_bonus", is_equal_approx(restored.equipment_ember_gain_bonus, original.equipment_ember_gain_bonus))
	_check("equipment_healing_power_bonus", is_equal_approx(restored.equipment_healing_power_bonus, original.equipment_healing_power_bonus))
	_check("equipment_skill_damage_bonus", is_equal_approx(restored.equipment_skill_damage_bonus, original.equipment_skill_damage_bonus))
	_check("equipment_resistance_bonuses", restored.equipment_resistance_bonuses == original.equipment_resistance_bonuses)
	_check("telemetry_started", restored.telemetry_started == original.telemetry_started)
	_check("telemetry_finished", restored.telemetry_finished == original.telemetry_finished)
	_check("telemetry_started_unix", restored.telemetry_started_unix == original.telemetry_started_unix)
	_check("telemetry_skill_uses", restored.telemetry_skill_uses == original.telemetry_skill_uses)
	_check("telemetry_synergy_ids", restored.telemetry_synergy_ids == original.telemetry_synergy_ids)
	_check("telemetry_last_boss_id", restored.telemetry_last_boss_id == original.telemetry_last_boss_id)
	_check("telemetry_boss_phase_reached", restored.telemetry_boss_phase_reached == original.telemetry_boss_phase_reached)
	_check("starting_option_id", restored.starting_option_id == original.starting_option_id)


func _test_dropped_legacy_fields_do_not_survive() -> void:
	var original := RunState.new()
	original.route_choice_count = 3
	original.route_option_a = 5
	original.route_option_b = 8
	original.chosen_destination = 8
	original.chosen_tile_type = BoardTileData.TileType.COMBAT
	original.route_choice_cooldown = true
	var dict: Dictionary = original.to_dictionary()
	_check("legacy_fields_not_serialized", not dict.has("route_choice_count") and not dict.has("route_option_a") and not dict.has("chosen_destination"))
	var restored: RunState = RunState.from_dictionary(dict)
	_check("legacy_fields_reset_to_class_defaults", restored.route_choice_count == 0 and restored.route_option_a == -1 and not restored.route_choice_cooldown)


func _test_missing_route_branch_dropped_not_crashed() -> void:
	var original := RunState.new()
	original.route_branches = {3: RouteBranchDataSource.new(3, [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], &"balanced", &"balanced")}
	var dict: Dictionary = original.to_dictionary()
	# Corrupt the persisted branch: wrong-length route_a.
	dict["route_branches"]["3"]["route_a"] = [0, 0]
	var restored: RunState = RunState.from_dictionary(dict)
	_check("corrupt_branch_dropped_not_crashed", restored != null and restored.route_branches.is_empty())


func _test_biome_data_rederived_from_id() -> void:
	var dict: Dictionary = {"biome_id": "nonexistent_biome_xyz"}
	var restored: RunState = RunState.from_dictionary(dict)
	_check("unknown_biome_id_yields_null_biome_data", restored.biome_data == null)
	_check("unknown_biome_id_preserved_verbatim", restored.biome_id == &"nonexistent_biome_xyz")


## Regression lock for a real bug caught during the Active Run Persistence
## merge-gate hardening pass: BoardGenerator's unseeded fallback
## (generate_for_run() with no explicit seed) multiplies a unix timestamp
## by 1_000_000 before XOR-ing it, routinely landing in the trillions — a
## +-2 billion clamp silently corrupted every real (non-debug, non-forced)
## board_seed on load, breaking every seed-derived RNG (encounter, crit,
## reward) it fed. Caught by a live end-to-end reward-resume test, not by
## this file's own original fixture (which used a small board_seed and
## never exercised the clamp boundary).
func _test_large_realistic_board_seed_survives_round_trip() -> void:
	var run := RunState.new()
	run.board_seed = 1789073244582738  # representative of Time.get_unix_time_from_system() * 1_000_000 magnitude
	var restored: RunState = RunState.from_dictionary(run.to_dictionary())
	_check("large_realistic_board_seed_not_clamped", restored.board_seed == 1789073244582738)

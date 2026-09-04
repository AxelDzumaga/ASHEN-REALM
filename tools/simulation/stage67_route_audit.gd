extends Node

const BOARDS_PER_BIOME := 5000
const BIOMES: Array[StringName] = [&"ashen_wastes", &"ember_marsh"]
const FREQUENCIES: Array[int] = [30, 45, 60]
const ROUTING_POLICIES: Array[StringName] = [&"route_random", &"route_safe", &"route_reward", &"route_tactical"]


func _ready() -> void:
	var output_path := "res://build/stage67/route_audit.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.get_slice("=", 1)
	var report: Dictionary = _run_audit()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path.get_base_dir()))
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if (report["failures"] as Array).is_empty() else 1)


func _run_audit() -> Dictionary:
	var failures: Array[String] = []
	var contract_tests: Dictionary = _run_contract_tests(failures)
	var frequency_results: Dictionary = {}
	var total_boards: int = 0
	for frequency: int in FREQUENCIES:
		var aggregate := {"boards": 0, "rolls": 0, "choices": 0, "meaningful": 0, "boss_reached": 0}
		for biome_id: StringName in BIOMES:
			var biome: BiomeData = BiomeCatalog.get_or_default(biome_id)
			for sample: int in BOARDS_PER_BIOME:
				var seed: int = absi(670067 + BIOMES.find(biome_id) * 10000019 + sample * 104729)
				var run := RunState.new()
				BoardGenerator.generate_for_run(run, biome, seed)
				if not BoardGenerator.validate(run.board_tile_sequence, biome):
					failures.append("board_invariant:%s:%d" % [biome_id, seed])
					continue
				var policy: StringName = ROUTING_POLICIES[sample % ROUTING_POLICIES.size()]
				var result: Dictionary = _walk_board(run.board_tile_sequence, seed, policy, frequency, failures)
				aggregate["boards"] += 1
				aggregate["rolls"] += result["rolls"]
				aggregate["choices"] += result["choices"]
				aggregate["meaningful"] += result["meaningful"]
				aggregate["boss_reached"] += 1 if result["boss_reached"] else 0
				if frequency == RouteChoiceResolver.DEFAULT_BRANCH_PERCENT:
					total_boards += 1
		var boards: float = float(maxi(1, aggregate["boards"]))
		var rolls: float = float(maxi(1, aggregate["rolls"]))
		aggregate["choices_per_run"] = snappedf(float(aggregate["choices"]) / boards, 0.001)
		aggregate["choice_frequency"] = snappedf(float(aggregate["choices"]) / rolls, 0.0001)
		aggregate["meaningful_choice_rate"] = snappedf(float(aggregate["meaningful"]) / float(maxi(1, aggregate["choices"])), 0.0001)
		frequency_results[str(frequency)] = aggregate
	# Determinismo explícito con la frecuencia elegida y ambas regiones.
	for biome_id: StringName in BIOMES:
		var biome: BiomeData = BiomeCatalog.get_or_default(biome_id)
		var run := RunState.new()
		BoardGenerator.generate_for_run(run, biome, 671337)
		var first: Dictionary = _walk_board(run.board_tile_sequence, 671337, &"route_tactical", 45, failures, true)
		var second: Dictionary = _walk_board(run.board_tile_sequence, 671337, &"route_tactical", 45, failures, true)
		if first["path"] != second["path"]:
			failures.append("same_seed_policy_not_deterministic:%s" % biome_id)
	return {
		"schema": 1,
		"boards_validated_selected_frequency": total_boards,
		"boards_evaluated_frequency_sweep": BOARDS_PER_BIOME * BIOMES.size() * FREQUENCIES.size(),
		"biomes": BIOMES,
		"routing_policies": ROUTING_POLICIES,
		"frequency_results": frequency_results,
		"selected_frequency_percent": RouteChoiceResolver.DEFAULT_BRANCH_PERCENT,
		"selection_reason": "45% equilibra varias decisiones por run y ritmo; cooldown impide bifurcaciones consecutivas",
		"contract_tests": contract_tests,
		"failures": failures,
	}


func _run_contract_tests(failures: Array[String]) -> Dictionary:
	var sequence: Array[int] = [
		BoardTileData.TileType.EMPTY, BoardTileData.TileType.COMBAT,
		BoardTileData.TileType.HEAL, BoardTileData.TileType.BOSS,
	]
	var two: Array[int] = RouteChoiceResolver.get_destinations(sequence, 0, 1, 67, 0, false, 100)
	var single: Array[int] = RouteChoiceResolver.get_destinations(sequence, 0, 1, 67, 0, true, 100)
	var boss: Array[int] = RouteChoiceResolver.get_destinations(sequence, 1, 4, 67, 0, false, 100)
	var tests: Dictionary = {
		"single_option_auto_move_contract": single == [1],
		"two_options_wait_input_contract": two == [1, 2],
		"destination_a_valid": two.size() == 2 and RouteChoiceResolver.is_valid_destination(0, sequence.size(), two[0]),
		"destination_b_valid": two.size() == 2 and RouteChoiceResolver.is_valid_destination(0, sequence.size(), two[1]),
		"invalid_backward_rejected": not RouteChoiceResolver.is_valid_destination(2, sequence.size(), 1),
		"invalid_out_of_bounds_rejected": not RouteChoiceResolver.is_valid_destination(0, sequence.size(), 4),
		"boss_mandatory": boss == [3],
		"no_overshoot": boss.size() == 1 and boss[0] == sequence.size() - 1,
		"meaningful_types_differ": RouteChoiceResolver.is_meaningful(sequence, two),
		"maximum_two_destinations": two.size() <= 2,
		"cooldown_suppresses_consecutive_choice": single.size() == 1,
	}
	for test_name: String in tests:
		if not bool(tests[test_name]):
			failures.append("contract:%s" % test_name)
	return tests


func _walk_board(sequence: Array[int], seed: int, policy: StringName, frequency: int, failures: Array[String], retain_path: bool = false) -> Dictionary:
	var position := 0
	var choice_ordinal := 0
	var cooldown := false
	var rolls := 0
	var choices := 0
	var meaningful := 0
	var path: Array[int] = [0]
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(seed ^ String(policy).hash() ^ 0x67D4)
	while position < sequence.size() - 1 and rolls < sequence.size() * 2:
		var roll := rng.randi_range(DiceRoller.MIN_RESULT, DiceRoller.MAX_RESULT)
		var options := RouteChoiceResolver.get_destinations(sequence, position, roll, seed, choice_ordinal, cooldown, frequency)
		if options.is_empty():
			failures.append("dead_end:%d:%d" % [seed, position])
			break
		if options.size() > 2 or (options.size() == 2 and options[0] == options[1]):
			failures.append("invalid_option_count:%d:%d" % [seed, position])
		for destination: int in options:
			if not RouteChoiceResolver.is_valid_destination(position, sequence.size(), destination):
				failures.append("invalid_destination:%d:%d:%d" % [seed, position, destination])
		var next: int = options[0]
		if options.size() == 2:
			choices += 1
			meaningful += 1 if RouteChoiceResolver.is_meaningful(sequence, options) else 0
			next = _choose_for_policy(sequence, options, policy, seed, position, choice_ordinal)
			choice_ordinal += 1
		cooldown = options.size() == 2
		position = next
		path.append(position)
		rolls += 1
	if position != sequence.size() - 1:
		failures.append("boss_unreachable:%d:%d" % [seed, position])
	return {"rolls": rolls, "choices": choices, "meaningful": meaningful, "boss_reached": position == sequence.size() - 1, "path": path if retain_path else []}


func _choose_for_policy(sequence: Array[int], options: Array[int], policy: StringName, seed: int, position: int, ordinal: int) -> int:
	if policy == &"route_random":
		return options[absi(seed ^ position * 4099 ^ ordinal * 65537) % options.size()]
	var weights: Dictionary = {
		BoardTileData.TileType.HEAL: 8 if policy in [&"route_safe", &"route_tactical"] else 1,
		BoardTileData.TileType.EMPTY: 7 if policy == &"route_safe" else 0,
		BoardTileData.TileType.EVENT: 5,
		BoardTileData.TileType.TREASURE: 9 if policy in [&"route_reward", &"route_tactical"] else 4,
		BoardTileData.TileType.COMBAT: 7 if policy == &"route_reward" else 3,
		BoardTileData.TileType.ELITE: 10 if policy == &"route_reward" else (6 if policy == &"route_tactical" else -5),
		BoardTileData.TileType.BOSS: 100,
	}
	return options[1] if int(weights.get(sequence[options[1]], 0)) > int(weights.get(sequence[options[0]], 0)) else options[0]

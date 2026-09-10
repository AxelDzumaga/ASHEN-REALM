extends Node

## Cobertura de generación para MAP3D-HUMAN-004: determinismo del fork/rutas,
## ventana reservada fuera de los cupos del bioma, sin ELITE/BOSS en rama, sin
## fork cerca del boss, reconvergencia correcta.

const RouteBranchDataSource = preload("res://scripts/board/route_branch_data.gd")

var _failures: Array[String] = []


func _ready() -> void:
	_test_determinism()
	_test_reserved_window_excluded_from_quotas()
	_test_branch_content_constraints()
	_test_fork_spacing_from_boss()
	_test_no_fork_case_still_valid()
	print(JSON.stringify({"failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_determinism() -> void:
	var biome: BiomeData = BiomeCatalog.ASHEN_WASTES
	var run_1 := RunState.new()
	var run_2 := RunState.new()
	BoardGenerator.generate_for_run(run_1, biome, 424242)
	BoardGenerator.generate_for_run(run_2, biome, 424242)
	_check("same_seed_same_board", run_1.board_tile_sequence == run_2.board_tile_sequence)
	_check("same_seed_same_fork_keys", run_1.route_branches.keys() == run_2.route_branches.keys())
	for fork_index: int in run_1.route_branches:
		var branch_1: RefCounted = run_1.route_branches[fork_index]
		var branch_2: RefCounted = run_2.route_branches[fork_index]
		_check("same_seed_same_route_a_%d" % fork_index, branch_1.route_a == branch_2.route_a)
		_check("same_seed_same_route_b_%d" % fork_index, branch_1.route_b == branch_2.route_b)
		_check("same_seed_same_archetypes_%d" % fork_index, branch_1.archetype_a == branch_2.archetype_a and branch_1.archetype_b == branch_2.archetype_b)

	var run_3 := RunState.new()
	BoardGenerator.generate_for_run(run_3, biome, 777777)
	_check("different_seed_can_differ", run_1.board_tile_sequence != run_3.board_tile_sequence or run_1.route_branches.keys() != run_3.route_branches.keys())


func _test_reserved_window_excluded_from_quotas() -> void:
	var biome: BiomeData = BiomeCatalog.ASHEN_WASTES
	var run := RunState.new()
	BoardGenerator.generate_for_run(run, biome, 5150)
	_check("fork_present_for_this_biome_length", not run.route_branches.is_empty())
	if run.route_branches.is_empty():
		return
	var fork_index: int = run.route_branches.keys()[0]
	var combat_count := 0
	for index: int in run.board_tile_sequence.size():
		if index > fork_index and index <= fork_index + RouteBranchDataSource.BRANCH_LENGTH:
			_check("reserved_slot_%d_is_empty_placeholder" % index, run.board_tile_sequence[index] == BoardTileData.TileType.EMPTY)
			continue
		if run.board_tile_sequence[index] == BoardTileData.TileType.COMBAT:
			combat_count += 1
	_check("combat_quota_within_biome_range_excluding_reserved", combat_count >= biome.combat_min and combat_count <= biome.combat_max)
	_check("fork_tile_itself_is_fork_type", run.board_tile_sequence[fork_index] == BoardTileData.TileType.FORK)


func _test_branch_content_constraints() -> void:
	var biome: BiomeData = BiomeCatalog.ASHEN_WASTES
	var all_clean := true
	for seed_value: int in range(1, 60):
		var run := RunState.new()
		BoardGenerator.generate_for_run(run, biome, seed_value * 1009)
		for fork_index: int in run.route_branches:
			var branch: RefCounted = run.route_branches[fork_index]
			for tile: int in branch.route_a + branch.route_b:
				if tile == BoardTileData.TileType.ELITE or tile == BoardTileData.TileType.BOSS:
					all_clean = false
			_check("branch_length_a_%d_%d" % [seed_value, fork_index], branch.route_a.size() == RouteBranchDataSource.BRANCH_LENGTH)
			_check("branch_length_b_%d_%d" % [seed_value, fork_index], branch.route_b.size() == RouteBranchDataSource.BRANCH_LENGTH)
	_check("no_elite_or_boss_in_any_branch", all_clean)


func _test_fork_spacing_from_boss() -> void:
	var biome: BiomeData = BiomeCatalog.ASHEN_WASTES
	var boss_index: int = biome.board_length - 1
	var all_safe := true
	for seed_value: int in range(1, 80):
		var run := RunState.new()
		BoardGenerator.generate_for_run(run, biome, seed_value * 733)
		for fork_index: int in run.route_branches:
			var merge_index: int = fork_index + RouteBranchDataSource.BRANCH_LENGTH + 1
			if merge_index >= boss_index - 1:
				all_safe = false
	_check("no_fork_can_reach_or_skip_boss", all_safe)


## Un bioma más corto que el mínimo requerido para alojar un fork debe seguir
## generando un board válido sin fork (no debe romper la generación).
func _test_no_fork_case_still_valid() -> void:
	var short_biome: BiomeData = BiomeData.new()
	short_biome.id = &"test_short"
	short_biome.board_length = 6
	short_biome.empty_min = 1
	short_biome.empty_max = 4
	short_biome.combat_min = 1
	short_biome.combat_max = 2
	short_biome.event_min = 0
	short_biome.event_max = 1
	short_biome.treasure_min = 0
	short_biome.treasure_max = 1
	short_biome.heal_min = 0
	short_biome.heal_max = 1
	short_biome.elite_min = 0
	short_biome.elite_max = 0
	var run := RunState.new()
	BoardGenerator.generate_for_run(run, short_biome, 99)
	_check("short_biome_generates_valid_length", run.board_tile_sequence.size() == 6)
	_check("short_biome_ends_in_boss", run.board_tile_sequence[-1] == BoardTileData.TileType.BOSS)
	_check("short_biome_no_fork_when_too_short", run.route_branches.is_empty())


func _check(key: String, condition: bool) -> void:
	if not condition:
		_failures.append(key)

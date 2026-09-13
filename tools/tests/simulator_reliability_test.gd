extends Node

## Simulator Reliability — regression fixtures for the two audited tooling
## defects: the board self-test's false-positive board_invariant_failed
## (missing fork_index) and _route_tile_key()'s silent FORK->"empty"
## aliasing. No UI, no Combat2D. full_run_simulation.gd is instantiated
## standalone via reflection, same pattern as combat_* and
## simulator_domain_parity_test.gd. Does not touch combat.gd, M1-M6,
## Simulator Alignment B, Combat3D, or gameplay/balance formulas — tooling
## only, per the reliability audit's explicit scope.

const SIM_SCRIPT := preload("res://tools/simulation/full_run_simulation.gd")

var _failures: Array[String] = []


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"simulator_reliability")
	_test_generated_boards_validate_with_real_fork_index()
	_test_known_seed_board_shape()
	_test_route_tile_key_covers_every_known_tile_type()
	_test_route_tile_key_unknown_value_reports_explicitly()
	print("[SIMULATOR_RELIABILITY_TEST] failures=%s" % JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(label: String, condition: bool) -> void:
	print("[SIMULATOR_RELIABILITY_TEST] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


func _sim() -> Node:
	return SIM_SCRIPT.new()


## §4/§17 of the reliability audit — every generated board actually has a
## fork (FORK_COUNT is unconditional) and validates once fork_index is
## supplied correctly, across a fixed multi-seed sample (not just the one
## known seed, so this doesn't quietly re-hardcode a single board's shape).
func _test_generated_boards_validate_with_real_fork_index() -> void:
	var sim: Node = _sim()
	var biome: BiomeData = BiomeCatalog.get_or_default(&"ashen_wastes")
	for seed_value: int in [620001, 1, 2, 3, 4, 5, 100, 999, 620062, 700010]:
		var tiles: Array[int] = sim.call("_board_for_seed", &"ashen_wastes", seed_value)
		var fork_index: int = tiles.find(BoardTileData.TileType.FORK)
		_check("seed_%d_has_a_fork" % seed_value, fork_index >= 0)
		_check("seed_%d_validates_with_real_fork_index" % seed_value, BoardGenerator.validate(tiles, biome, fork_index))
		_check("seed_%d_still_false_without_fork_index_documenting_why_it_was_needed" % seed_value, not BoardGenerator.validate(tiles, biome))


## §5 of the reliability audit — the exact known reproduction, locked.
func _test_known_seed_board_shape() -> void:
	var sim: Node = _sim()
	var tiles: Array[int] = sim.call("_board_for_seed", &"ashen_wastes", 620001)
	_check("known_seed_board_length_is_30", tiles.size() == 30)
	_check("known_seed_fork_index_is_6", tiles.find(BoardTileData.TileType.FORK) == 6)


## §11/§16 — _route_tile_key() must not fall back to "empty" for any
## currently-known TileType, including FORK. Iterates the enum's own
## .values() rather than a hardcoded list, so a future new TileType value
## fails this test loudly instead of silently reproducing the audited bug.
func _test_route_tile_key_covers_every_known_tile_type() -> void:
	var sim: Node = _sim()
	var names: PackedStringArray = BoardTileData.TileType.keys()
	var values: Array = BoardTileData.TileType.values()
	for index: int in values.size():
		var tile_type: int = values[index]
		var key: String = sim.call("_route_tile_key", tile_type)
		var expected_not_empty: bool = tile_type != BoardTileData.TileType.EMPTY
		_check("route_tile_key_%s_not_unknown" % names[index], not key.begins_with("unknown_"))
		if expected_not_empty:
			_check("route_tile_key_%s_not_aliased_to_empty" % names[index], key != "empty")
	_check("route_tile_key_fork_is_explicit", sim.call("_route_tile_key", BoardTileData.TileType.FORK) == "fork")


## §10/§17 — a genuinely unrecognized future TileType value must be
## reported explicitly (never silently merged into "empty" or any other
## real category) and must not crash.
func _test_route_tile_key_unknown_value_reports_explicitly() -> void:
	var sim: Node = _sim()
	var key: String = sim.call("_route_tile_key", 999)
	_check("unknown_tile_type_is_explicit_label", key == "unknown_999")
	_check("unknown_tile_type_not_silently_empty", key != "empty")

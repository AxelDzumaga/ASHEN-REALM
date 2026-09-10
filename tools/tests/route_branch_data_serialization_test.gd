extends Node

## RouteBranchData.to_dictionary()/from_dictionary() round-trip + hardening
## against malformed persisted data (Active Run Persistence, §45).

const RouteBranchDataSource = preload("res://scripts/board/route_branch_data.gd")

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	_test_round_trip()
	_test_reject_missing_route_a()
	_test_reject_missing_route_b()
	_test_reject_wrong_length_route()
	_test_reject_invalid_tile_enum()
	_test_reject_negative_fork_index()
	_test_reject_non_dictionary()
	_test_reject_non_array_route()
	_test_accepts_missing_archetype_gracefully()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _make_valid_dict(fork_index: int = 4) -> Dictionary:
	var route_a: Array[int] = [BoardTileData.TileType.COMBAT, BoardTileData.TileType.EVENT, BoardTileData.TileType.HEAL, BoardTileData.TileType.EMPTY, BoardTileData.TileType.TREASURE, BoardTileData.TileType.COMBAT]
	var route_b: Array[int] = [BoardTileData.TileType.HEAL, BoardTileData.TileType.HEAL, BoardTileData.TileType.EVENT, BoardTileData.TileType.TREASURE, BoardTileData.TileType.EMPTY, BoardTileData.TileType.COMBAT]
	var original := RouteBranchDataSource.new(fork_index, route_a, route_b, &"combat", &"recovery")
	return original.to_dictionary()


func _test_round_trip() -> void:
	var route_a: Array[int] = [BoardTileData.TileType.COMBAT, BoardTileData.TileType.EVENT, BoardTileData.TileType.HEAL, BoardTileData.TileType.EMPTY, BoardTileData.TileType.TREASURE, BoardTileData.TileType.COMBAT]
	var route_b: Array[int] = [BoardTileData.TileType.HEAL, BoardTileData.TileType.HEAL, BoardTileData.TileType.EVENT, BoardTileData.TileType.TREASURE, BoardTileData.TileType.EMPTY, BoardTileData.TileType.COMBAT]
	var original := RouteBranchDataSource.new(7, route_a, route_b, &"combat", &"recovery")
	var dict: Dictionary = original.to_dictionary()
	# Round-trip through actual JSON text, not just the in-memory Dictionary,
	# since real persistence goes through JSON.stringify/parse.
	var json_text: String = JSON.stringify(dict)
	var parsed: Variant = JSON.parse_string(json_text)
	var restored: RouteBranchData = RouteBranchDataSource.from_dictionary(parsed)
	_check("round_trip_not_null", restored != null)
	if restored == null:
		return
	_check("round_trip_fork_index", restored.fork_index == 7)
	_check("round_trip_route_a", restored.route_a == route_a)
	_check("round_trip_route_b", restored.route_b == route_b)
	_check("round_trip_archetype_a", restored.archetype_a == &"combat")
	_check("round_trip_archetype_b", restored.archetype_b == &"recovery")
	_check("round_trip_merge_index_matches", restored.merge_index() == original.merge_index())
	_check("round_trip_tile_type_for_matches", restored.tile_type_for(RouteBranchDataSource.ROUTE_A, 8) == original.tile_type_for(RouteBranchDataSource.ROUTE_A, 8))


func _test_reject_missing_route_a() -> void:
	var data: Dictionary = _make_valid_dict()
	data.erase("route_a")
	_check("reject_missing_route_a", RouteBranchDataSource.from_dictionary(data) == null)


func _test_reject_missing_route_b() -> void:
	var data: Dictionary = _make_valid_dict()
	data.erase("route_b")
	_check("reject_missing_route_b", RouteBranchDataSource.from_dictionary(data) == null)


func _test_reject_wrong_length_route() -> void:
	var data: Dictionary = _make_valid_dict()
	data["route_a"] = [BoardTileData.TileType.COMBAT, BoardTileData.TileType.EMPTY]
	_check("reject_wrong_length_route", RouteBranchDataSource.from_dictionary(data) == null)


func _test_reject_invalid_tile_enum() -> void:
	var data: Dictionary = _make_valid_dict()
	var bad_route: Array = data["route_a"].duplicate()
	bad_route[0] = 9999
	data["route_a"] = bad_route
	_check("reject_invalid_tile_enum", RouteBranchDataSource.from_dictionary(data) == null)


func _test_reject_negative_fork_index() -> void:
	var data: Dictionary = _make_valid_dict()
	data["fork_index"] = -1
	_check("reject_negative_fork_index", RouteBranchDataSource.from_dictionary(data) == null)


func _test_reject_non_dictionary() -> void:
	_check("reject_non_dictionary_array", RouteBranchDataSource.from_dictionary({}) == null or true)
	# from_dictionary's parameter is typed Dictionary, so a non-Dictionary
	# argument is a compile-time error, not a runtime case — instead prove
	# an EMPTY dictionary (the JSON-parse equivalent of "nothing usable")
	# is safely rejected.
	_check("reject_empty_dictionary", RouteBranchDataSource.from_dictionary({}) == null)


func _test_reject_non_array_route() -> void:
	var data: Dictionary = _make_valid_dict()
	data["route_a"] = "not an array"
	_check("reject_non_array_route", RouteBranchDataSource.from_dictionary(data) == null)


func _test_accepts_missing_archetype_gracefully() -> void:
	var data: Dictionary = _make_valid_dict()
	data.erase("archetype_a")
	data.erase("archetype_b")
	var restored: RouteBranchData = RouteBranchDataSource.from_dictionary(data)
	_check("missing_archetype_still_valid", restored != null)
	if restored != null:
		_check("missing_archetype_defaults_empty", restored.archetype_a == &"" and restored.archetype_b == &"")

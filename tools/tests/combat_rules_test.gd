extends Node

## Combat Domain M5 — sección 39/44 del handoff: CombatRules.MAX_TEAM_SIZE
## y el asignador genérico de formation_slot, sin Combat2D. Mismo patrón que
## combat_team_utils_test.gd (M2)/combat_target_resolver_test.gd (M3).

var _failures: Array[String] = []


func _ready() -> void:
	_test_max_team_size_is_five()
	_test_allocator_empty_occupied()
	_test_allocator_single_occupied()
	_test_allocator_near_full()
	_test_allocator_full()
	_test_allocator_never_duplicates_or_exceeds_range()
	_test_allocator_zero_count_requested()
	_test_allocator_more_requested_than_available()
	print("[COMBAT_RULES_TEST] failures=%s" % JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(label: String, condition: bool) -> void:
	print("[COMBAT_RULES_TEST] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


func _test_max_team_size_is_five() -> void:
	_check("max_team_size_is_five", CombatRules.MAX_TEAM_SIZE == 5)


## §44 — occupied []: primer disponible determinista.
func _test_allocator_empty_occupied() -> void:
	var result: Array[int] = CombatRules.find_available_formation_slots([], 3)
	_check("empty_occupied_returns_ascending", result == [0, 1, 2])


## §44 — occupied [1]: devuelve de {0,2,3,4} en orden ascendente.
func _test_allocator_single_occupied() -> void:
	var result: Array[int] = CombatRules.find_available_formation_slots([1], 4)
	_check("single_occupied_skips_one", result == [0, 2, 3, 4])


## §44 — occupied [0,1,2,3]: devuelve 4.
func _test_allocator_near_full() -> void:
	var result: Array[int] = CombatRules.find_available_formation_slots([0, 1, 2, 3], 1)
	_check("near_full_returns_last_slot", result == [4])


## §44 — occupied [0,1,2,3,4]: no devuelve nada.
func _test_allocator_full() -> void:
	var result: Array[int] = CombatRules.find_available_formation_slots([0, 1, 2, 3, 4], 1)
	_check("full_returns_none", result.is_empty())


func _test_allocator_never_duplicates_or_exceeds_range() -> void:
	var result: Array[int] = CombatRules.find_available_formation_slots([2], 10)
	var no_duplicates: bool = true
	var seen: Array[int] = []
	for slot: int in result:
		if slot in seen or slot < 0 or slot >= CombatRules.MAX_TEAM_SIZE:
			no_duplicates = false
		seen.append(slot)
	_check("allocator_never_duplicates_or_exceeds_range", no_duplicates)
	_check("allocator_never_returns_more_than_capacity", result.size() <= CombatRules.MAX_TEAM_SIZE - 1)


func _test_allocator_zero_count_requested() -> void:
	var result: Array[int] = CombatRules.find_available_formation_slots([], 0)
	_check("zero_count_returns_empty", result.is_empty())


func _test_allocator_more_requested_than_available() -> void:
	# Con [1] ocupado hay 4 libres — pedir 10 debe devolver como mucho esas 4,
	# nunca inventar un quinto slot fuera de rango.
	var result: Array[int] = CombatRules.find_available_formation_slots([1], 10)
	_check("more_requested_than_available_caps_at_free_count", result.size() == 4)

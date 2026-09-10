extends Node

## §5 of the merge-gate hardening pass: a cheap deterministic stress test
## of RunManager's actual production run_id generator — no cryptographic
## requirements, just "no duplicates, non-empty, filesystem-safe" at a
## scale that runs quickly.

const COUNT: int = 10_000
const SAFE_PATTERN := "^[a-z0-9_]+$"

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	_test_generator_uniqueness_and_safety()
	_test_round_trip_never_regenerates()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures, "count": COUNT}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _test_generator_uniqueness_and_safety() -> void:
	var regex := RegEx.new()
	regex.compile(SAFE_PATTERN)
	var seen: Dictionary = {}
	var all_non_empty: bool = true
	var all_safe: bool = true
	var duplicate_count: int = 0
	for _i: int in COUNT:
		var id: String = RunManager.call("_generate_run_id")
		if id.is_empty():
			all_non_empty = false
		if regex.search(id) == null:
			all_safe = false
		if seen.has(id):
			duplicate_count += 1
		else:
			seen[id] = true
	_check("all_ids_non_empty", all_non_empty)
	_check("all_ids_filesystem_safe", all_safe)
	_check("no_duplicates_across_%d_ids" % COUNT, duplicate_count == 0)
	_check("generated_full_expected_count", seen.size() == COUNT)


func _test_round_trip_never_regenerates() -> void:
	var run := RunState.new()
	run.run_id = "run_fixed_id_for_round_trip_check"
	var restored: RunState = RunState.from_dictionary(run.to_dictionary())
	_check("round_trip_preserves_run_id_verbatim", restored.run_id == "run_fixed_id_for_round_trip_check")

	# Deserializing a payload that happens to omit run_id entirely must
	# not silently invent one either — it defaults to empty, which
	# deposit_run()'s idempotency guard already treats as "never matches",
	# not a value to paper over.
	var restored_missing: RunState = RunState.from_dictionary({})
	_check("missing_run_id_defaults_empty_not_generated", restored_missing.run_id == "")

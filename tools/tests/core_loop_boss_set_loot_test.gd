extends Node

## Core Loop / Final Reward §31 — deterministic, RNG-seeded coverage of
## ChestResolver's existing boss-set soft-bias (35% chance to bias toward
## ashen_warden_set, preferring whichever piece isn't yet owned). Locks
## current behavior, does not rebalance it (§18/§38: no hard pity yet).
##
## Calls ChestResolver._roll_item() directly with an explicitly seeded
## RandomNumberGenerator (the same object resolve() itself would use) — a
## fixed, hardcoded seed range is scanned, so the result is 100%
## reproducible across runs, never flaky, without needing to hand-derive
## which seed lands where.

const SEED_RANGE := 2000
const WARDENS_EDGE_ID: StringName = &"wardens_edge"
const WARDEN_PLATE_ID: StringName = &"warden_plate"

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	_test_set_bias_can_select_a_set_piece_when_none_owned()
	_test_set_bias_prefers_the_missing_piece()
	_test_resolver_never_touches_profile_inventory_directly()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _warden_chest() -> ChestData:
	return ChestCatalog.get_by_id(ChestCatalog.WARDEN_RELIQUARY)


func _test_set_bias_can_select_a_set_piece_when_none_owned() -> void:
	var chest: ChestData = _warden_chest()
	_check("fixture_chest_has_boss_set_id", chest.boss_set_id == &"ashen_warden_set")
	var profile := ProfileData.new()
	var found_edge := false
	var found_plate := false
	var all_valid := true
	for seed_value: int in SEED_RANGE:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var item: EquipmentData = ChestResolver._roll_item(chest, EquipmentData.Rarity.EPIC, profile, rng)
		if item == null or EquipmentCatalog.get_by_id(String(item.id)) == null:
			all_valid = false
		elif item.id == WARDENS_EDGE_ID:
			found_edge = true
		elif item.id == WARDEN_PLATE_ID:
			found_plate = true
	_check("all_rolled_items_resolve_to_valid_catalog_entries", all_valid)
	_check("owning_neither_can_still_roll_wardens_edge", found_edge)
	_check("owning_neither_can_still_roll_warden_plate", found_plate)


## The 35% set-bias is only ONE of two paths that can land on a set piece
## — the other 65% of the time _roll_item() draws from the full unbiased
## EPIC pool, where an already-owned wardens_edge is still a perfectly
## legitimate (and expected) outcome, later handled as a normal duplicate
## conversion elsewhere. So "prefers the missing piece" can only be
## asserted for seeds where the bias branch actually fired — replicate
## _roll_item()'s own first RNG draw (rng.randf() < 0.35, the bias check)
## with an identically-seeded generator to know which seeds those are,
## rather than asserting it holds unconditionally.
func _test_set_bias_prefers_the_missing_piece() -> void:
	var chest: ChestData = _warden_chest()
	var profile := ProfileData.new()
	profile.owned_equipment[String(WARDENS_EDGE_ID)] = 1
	var biased_seed_count := 0
	var wrong_piece_hits := 0
	for seed_value: int in SEED_RANGE:
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		var bias_would_fire: bool = probe.randf() < 0.35
		if not bias_would_fire:
			continue
		biased_seed_count += 1
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var item: EquipmentData = ChestResolver._roll_item(chest, EquipmentData.Rarity.EPIC, profile, rng)
		if item.id != WARDEN_PLATE_ID:
			wrong_piece_hits += 1
	_check("bias_branch_fires_for_some_seeds", biased_seed_count > 0)
	_check("every_biased_hit_prefers_the_missing_piece", wrong_piece_hits == 0)


func _test_resolver_never_touches_profile_inventory_directly() -> void:
	var chest: ChestData = _warden_chest()
	var profile := ProfileData.new()
	var owned_snapshot: String = JSON.stringify(profile.owned_equipment)
	for seed_value: int in 50:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		ChestResolver._roll_item(chest, EquipmentData.Rarity.EPIC, profile, rng)
	# Item selection alone must never mutate ownership — granting is
	# exclusively SaveManager's job (_grant_or_salvage_equipment), not a
	# parallel inventory-writing path inside the resolver.
	_check("roll_item_does_not_mutate_owned_equipment", JSON.stringify(profile.owned_equipment) == owned_snapshot)

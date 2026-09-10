extends Node

## §56: precise proof that "pre-encounter checkpoint" really means
## pre-encounter — mutating RunState in memory (simulating mid-combat HP
## loss) after the IN_ENCOUNTER checkpoint was written must NOT be
## reflected in what a later load returns, because nothing re-checkpoints
## until the encounter actually resolves. This is the central invariant
## Encounter Checkpoint Resume depends on.

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	CharacterProfileRepository.use_isolated_test_root("encounter_snapshot")
	ActiveRunRepository.use_isolated_test_root("encounter_snapshot")
	_test_mid_combat_mutation_not_persisted_until_next_checkpoint()
	_test_post_combat_checkpoint_does_reflect_new_state()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _test_mid_combat_mutation_not_persisted_until_next_checkpoint() -> void:
	var result: Dictionary = CharacterProfileRepository.create_character("Snapshot Hero")
	var character_id: String = String(result.get("character_id", ""))

	var run := RunState.new()
	run.run_id = "run_snapshot"
	run.biome_id = BiomeCatalog.ASHEN_WASTES.id
	run.biome_data = BiomeCatalog.ASHEN_WASTES
	run.board_tile_sequence = [BoardTileData.TileType.EMPTY, BoardTileData.TileType.COMBAT, BoardTileData.TileType.BOSS]
	run.board_position = 1
	run.max_health = 140
	run.current_health = 121

	# Exactly what game.gd's show_combat() does: checkpoint IN_ENCOUNTER
	# BEFORE the combat screen (and therefore any HP mutation) exists.
	ActiveRunRepository.checkpoint(character_id, run, ActiveRunRepository.PHASE_IN_ENCOUNTER, "entering_combat")

	# Simulate mid-combat damage on the SAME in-memory object — this is
	# exactly what combat.gd does to RunManager.current_run during a
	# fight. No checkpoint call happens for any of this.
	run.current_health = 40
	run.attack -= 2  # a hypothetical debuff-style mutation, same idea

	var loaded: Dictionary = ActiveRunRepository.load_active_run(character_id)
	var loaded_run: RunState = loaded.get("run")
	_check("loaded_recoverable", bool(loaded.get("recoverable", false)))
	_check("loaded_phase_still_in_encounter", String(loaded.get("phase", "")) == ActiveRunRepository.PHASE_IN_ENCOUNTER)
	_check("loaded_hp_is_pre_combat_value_not_mid_combat", loaded_run != null and loaded_run.current_health == 121)
	_check("loaded_hp_is_not_the_mutated_value", loaded_run != null and loaded_run.current_health != 40)


func _test_post_combat_checkpoint_does_reflect_new_state() -> void:
	var result: Dictionary = CharacterProfileRepository.create_character("Snapshot Hero Two")
	var character_id: String = String(result.get("character_id", ""))

	var run := RunState.new()
	run.run_id = "run_snapshot_two"
	run.biome_id = BiomeCatalog.ASHEN_WASTES.id
	run.biome_data = BiomeCatalog.ASHEN_WASTES
	run.board_tile_sequence = [BoardTileData.TileType.EMPTY, BoardTileData.TileType.COMBAT, BoardTileData.TileType.BOSS]
	run.board_position = 1
	run.max_health = 140
	run.current_health = 121
	ActiveRunRepository.checkpoint(character_id, run, ActiveRunRepository.PHASE_IN_ENCOUNTER, "entering_combat")

	# Combat resolves: real HP change now committed, THEN a real
	# checkpoint fires (matching _on_combat_won's REWARD_PENDING
	# checkpoint) — this one SHOULD be reflected.
	run.current_health = 95
	run.combats_won = 1
	ActiveRunRepository.checkpoint(character_id, run, ActiveRunRepository.PHASE_REWARD_PENDING, "combat_won")

	var loaded: Dictionary = ActiveRunRepository.load_active_run(character_id)
	var loaded_run: RunState = loaded.get("run")
	_check("post_combat_checkpoint_reflects_resolved_hp", loaded_run != null and loaded_run.current_health == 95)
	_check("post_combat_checkpoint_phase_reward_pending", String(loaded.get("phase", "")) == ActiveRunRepository.PHASE_REWARD_PENDING)

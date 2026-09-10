extends Node

## Domain/repository layer for one character's in-progress expedition
## (Active Run Persistence). Mirrors CharacterProfileRepository's shape and
## philosophy but stays fully decoupled from it — every method here takes
## character_id explicitly rather than caching a "currently selected"
## character, so a stale reference can never make a write land on the
## wrong character's file (see invariant tests). Never touches permanent
## ProfileData; RunState read/write goes through AtomicJsonStore directly,
## the same low-level primitive SaveManager itself now uses — not a
## second hand-rolled filesystem-safety implementation.
##
## Checkpoint policy: SAFE CHECKPOINTS ONLY (approved design). This class
## never fires on its own — callers (BoardTurnController via an injected
## Callable, RunManager, game.gd, run_result.gd) decide when a boundary is
## safe to persist. Mid-combat/mid-animation state is never represented
## here at all; IN_ENCOUNTER always stores the pre-encounter RunState.

signal active_run_changed(character_id: String)

const ACTIVE_RUN_VERSION: int = 1
const DEFAULT_PROFILES_ROOT: String = "user://profiles"
const ACTIVE_RUN_FILE_NAME: String = "active_run.json"

const PHASE_ON_BOARD: String = "ON_BOARD"
const PHASE_ROUTE_DECISION_PENDING: String = "ROUTE_DECISION_PENDING"
const PHASE_ENCOUNTER_PENDING: String = "ENCOUNTER_PENDING"
const PHASE_IN_ENCOUNTER: String = "IN_ENCOUNTER"
const PHASE_REWARD_PENDING: String = "REWARD_PENDING"
const PHASE_RUN_COMPLETE_PENDING_DEPOSIT: String = "RUN_COMPLETE_PENDING_DEPOSIT"
const VALID_PHASES: Array[String] = [
	PHASE_ON_BOARD, PHASE_ROUTE_DECISION_PENDING, PHASE_ENCOUNTER_PENDING,
	PHASE_IN_ENCOUNTER, PHASE_REWARD_PENDING, PHASE_RUN_COMPLETE_PENDING_DEPOSIT,
]

const AtomicJsonStoreSource = preload("res://scripts/save/atomic_json_store.gd")

var profiles_root: String = DEFAULT_PROFILES_ROOT


func use_isolated_test_root(test_name: String = "runtime_test") -> void:
	if not OS.is_debug_build():
		push_warning("ActiveRunRepository.use_isolated_test_root() ignorado fuera de un build de debug.")
		return
	profiles_root = "user://test_profiles_root/%s/profiles" % test_name
	_delete_directory_recursive(ProjectSettings.globalize_path(profiles_root))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(profiles_root))


func character_run_path(character_id: String) -> String:
	return "%s/%s/%s" % [profiles_root, character_id, ACTIVE_RUN_FILE_NAME]


func has_active_run(character_id: String) -> bool:
	if character_id.is_empty():
		return false
	return FileAccess.file_exists(character_run_path(character_id))


## Invariant #7: never silently overwrite an existing, still-in-progress
## active run for this character. A genuinely new expedition (start_new_run)
## must go through this, not the generic checkpoint() used for every
## subsequent boundary of the SAME run.
func create_run_checkpoint(character_id: String, run: RunState) -> bool:
	if character_id.is_empty() or run == null:
		return false
	if has_active_run(character_id):
		push_warning("ActiveRunRepository.create_run_checkpoint() refused: character %s already has an active run. Delete or resolve it first." % character_id)
		return false
	return checkpoint(character_id, run, PHASE_ON_BOARD, "run_created")


## Writes a safe checkpoint. `terminal_is_victory` only matters when
## `phase == PHASE_RUN_COMPLETE_PENDING_DEPOSIT` — RunState itself has no
## field distinguishing "terminal by defeat" (only record_boss_victory()
## sets run_completed=true; a defeat never touches RunState), so that
## outcome is envelope metadata owned here, not a RunState field.
func checkpoint(character_id: String, run: RunState, phase: String, reason: String, terminal_is_victory: bool = false) -> bool:
	if character_id.is_empty() or run == null:
		return false
	if phase not in VALID_PHASES:
		push_warning("ActiveRunRepository.checkpoint() rejected unknown phase '%s'." % phase)
		return false
	var payload: Dictionary = {
		"run_id": run.run_id,
		"character_id": character_id,
		"phase": phase,
		"terminal_is_victory": terminal_is_victory,
		"checkpoint_reason": reason,
		"checkpointed_at_unix": int(Time.get_unix_time_from_system()),
		"run_state": run.to_dictionary(),
	}
	var path: String = character_run_path(character_id)
	var success: bool = AtomicJsonStoreSource.write_safely(path, payload, "active_run_version", ACTIVE_RUN_VERSION)
	if success:
		active_run_changed.emit(character_id)
	return success


## Returns {"exists": bool, "recoverable": bool, "run": RunState,
## "phase": String, "terminal_is_victory": bool, "run_id": String,
## "checkpoint_reason": String}. "exists" is true whenever a file was
## found at all (even if unrecoverable, for diagnostics); "recoverable"
## is the actual usability signal callers should branch on — content
## drift (missing biome/essential references) and version mismatches
## both come back as exists=true, recoverable=false, matching §26's
## "unrecoverable, but don't lose the file, don't touch the profile"
## contract, distinct from "exists=false" (no active run at all, the
## normal CONTINUAR-without-expedition case).
func load_active_run(character_id: String) -> Dictionary:
	if character_id.is_empty():
		return _empty_result()
	var path: String = character_run_path(character_id)
	var result: Dictionary = AtomicJsonStoreSource.load_best_candidate(path, "active_run_version", ACTIVE_RUN_VERSION)
	var source: String = String(result.get("source", "none"))
	if source == "none":
		# main_was_corrupt distinguishes "a file existed but nothing in it
		# (MAIN/TEMP/BACKUP) was usable" (exists=true, unrecoverable) from
		# "there was never any active run for this character at all"
		# (exists=false — the normal CONTINUAR-without-expedition case).
		return _unrecoverable_result() if bool(result.get("main_was_corrupt", false)) else _empty_result()
	if source == "future_temporary" or source == "future_backup":
		# ACTIVE_RUN_VERSION incompatibility: fails safely, no migration
		# attempted for v1 (per approved design — do not improvise).
		return _unrecoverable_result()
	# Any found candidate whose version doesn't match exactly is a version
	# mismatch too — unlike ProfileData, active runs never load a future
	# version read-only, they simply fail safely (§33). This also covers
	# a future-versioned MAIN, which AtomicJsonStore's source labels don't
	# distinguish from an in-range one (that distinction only exists for
	# ProfileData's read-only-future-save behavior, which active runs
	# deliberately do not replicate).
	if int(result.get("version", 0)) != ACTIVE_RUN_VERSION:
		return _unrecoverable_result()
	# "main"/"temporary"/"backup"/"temporary_unpromotable"/"backup_unrestored"
	# all found usable data (the suffix variants only mean the on-disk
	# promotion itself didn't fully land — the content is still valid and
	# safe to use in memory).
	var data: Variant = result.get("data", {})
	if typeof(data) != TYPE_DICTIONARY:
		return _unrecoverable_result()
	var envelope: Dictionary = data
	var phase: String = String(envelope.get("phase", ""))
	if phase not in VALID_PHASES:
		return _unrecoverable_result()
	var run_state_data: Variant = envelope.get("run_state", null)
	if typeof(run_state_data) != TYPE_DICTIONARY:
		return _unrecoverable_result()
	var run: RunState = RunState.from_dictionary(run_state_data)
	if not _is_essential_state_intact(run):
		return _unrecoverable_result()
	return {
		"exists": true,
		"recoverable": true,
		"run": run,
		"phase": phase,
		"terminal_is_victory": bool(envelope.get("terminal_is_victory", false)),
		"run_id": String(envelope.get("run_id", "")),
		"checkpoint_reason": String(envelope.get("checkpoint_reason", "")),
	}


## §21/§24/§26 essential-field gate: content this run cannot function
## without (a resolvable biome, a non-empty run_id, a non-empty board).
## Optional/cosmetic fields (telemetry counters, biome_intro_shown, etc.)
## are never checked here — losing them cannot alter gameplay correctness.
func _is_essential_state_intact(run: RunState) -> bool:
	return (
		run != null
		and not run.run_id.is_empty()
		and run.biome_data != null
		and not run.board_tile_sequence.is_empty()
	)


func delete_active_run(character_id: String) -> bool:
	if character_id.is_empty():
		return false
	var path: String = character_run_path(character_id)
	var deleted: bool = true
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			deleted = _remove_file(path + suffix) and deleted
	active_run_changed.emit(character_id)
	return deleted


func _empty_result() -> Dictionary:
	return {"exists": false, "recoverable": false, "run": null, "phase": "", "terminal_is_victory": false, "run_id": "", "checkpoint_reason": ""}


func _unrecoverable_result() -> Dictionary:
	return {"exists": true, "recoverable": false, "run": null, "phase": "", "terminal_is_victory": false, "run_id": "", "checkpoint_reason": ""}


func _remove_file(path: String) -> bool:
	var error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return error == OK


func _delete_directory_recursive(absolute_path: String) -> void:
	var dir: DirAccess = DirAccess.open(absolute_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		if entry_name != "." and entry_name != "..":
			var full_path: String = absolute_path.path_join(entry_name)
			if dir.current_is_dir():
				_delete_directory_recursive(full_path)
			else:
				DirAccess.remove_absolute(full_path)
		entry_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)

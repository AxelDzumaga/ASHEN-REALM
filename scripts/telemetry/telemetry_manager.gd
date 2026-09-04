extends Node

const SCHEMA_PATH := "res://data/telemetry/event_schema.json"
const TELEMETRY_DIR := "user://telemetry"
const LOG_DIR := "user://logs"
const SESSION_MARKER_PATH := "user://telemetry/session_open.marker"
const MAX_STRING_LENGTH := 64
const MAX_ARRAY_LENGTH := 8
const BUFFER_EVENT_LIMIT := 12
const MAX_EVENT_FILE_BYTES := 512 * 1024
const MAX_TOTAL_EVENT_BYTES := 2 * 1024 * 1024
const MAX_EVENT_FILES := 3
const MAX_FATAL_LOG_BYTES := 64 * 1024
const MAX_FATAL_LOG_FILES := 3
const PRODUCTION_ENVIRONMENT := "production"
const DEVELOPMENT_ENVIRONMENT := "development"
const LOCAL_DEVELOPMENT_TELEMETRY_ENABLED := true

var analytics_enabled: bool = false
var external_delivery_enabled: bool = false
var session_id: String = ""
var _environment: String = PRODUCTION_ENVIRONMENT
var _schema: Dictionary = {}
var _buffer: Array[String] = []
var _current_event_path: String = ""
var _session_ended: bool = false
var _write_failures: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_schema()
	_environment = DEVELOPMENT_ENVIRONMENT if OS.has_feature("editor") else PRODUCTION_ENVIRONMENT
	analytics_enabled = bool(SettingsManager.analytics_enabled) or (
		_environment == DEVELOPMENT_ENVIRONMENT and LOCAL_DEVELOPMENT_TELEMETRY_ENABLED
	)
	external_delivery_enabled = false
	if not analytics_enabled or _schema.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TELEMETRY_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIR))
	var previous_unclean: bool = FileAccess.file_exists(SESSION_MARKER_PATH)
	session_id = _new_session_id()
	_write_session_marker()
	track(TelemetryEventNames.APP_STARTED, {"environment": _environment})
	track(TelemetryEventNames.SESSION_STARTED, {"previous_session_unclean": previous_unclean})
	if previous_unclean:
		track(TelemetryEventNames.UNCLEAN_EXIT_DETECTED)


func _exit_tree() -> void:
	end_session(&"clean_shutdown")


func track(event_name: StringName, properties: Dictionary = {}) -> bool:
	if not analytics_enabled or _session_ended or _schema.is_empty():
		return false
	var validation_result: Variant = _validate_event(event_name, properties)
	if validation_result == null:
		if _environment == "development":
			push_warning("Telemetry rejected event: %s" % event_name)
		return false
	var validated: Dictionary = validation_result
	var envelope: Dictionary = {
		"schema_version": int(_schema.get("schema_version", 1)),
		"event_name": String(event_name),
		"timestamp_utc": Time.get_datetime_string_from_system(true, false) + "Z",
		"session_id": session_id,
		"properties": validated,
	}
	_buffer.append(JSON.stringify(envelope))
	if _buffer.size() >= BUFFER_EVENT_LIMIT:
		flush()
	return true


func flush() -> bool:
	if _buffer.is_empty() or not analytics_enabled:
		return true
	var payload: String = "\n".join(_buffer) + "\n"
	if not _prepare_event_file(payload.to_utf8_buffer().size()):
		_write_failures += 1
		_buffer.clear()
		return false
	var file: FileAccess = FileAccess.open(_current_event_path, FileAccess.READ_WRITE)
	if file == null:
		_write_failures += 1
		_buffer.clear()
		return false
	file.seek_end()
	file.store_string(payload)
	var ok: bool = file.get_error() == OK
	file.close()
	_buffer.clear()
	if not ok:
		_write_failures += 1
	return ok


func end_session(reason: StringName = &"clean_shutdown") -> void:
	if _session_ended or not analytics_enabled:
		return
	track(TelemetryEventNames.SESSION_ENDED, {"reason": String(reason)})
	flush()
	_session_ended = true
	if FileAccess.file_exists(SESSION_MARKER_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_MARKER_PATH))


func track_run_started(run: RunState) -> void:
	if run == null or run.telemetry_started:
		return
	run.telemetry_started = true
	run.telemetry_started_unix = int(Time.get_unix_time_from_system())
	track(TelemetryEventNames.RUN_STARTED, {
		"biome_id": String(run.biome_id),
		"equipped_weapon_id": String(run.equipped_weapon_id),
		"equipped_armor_id": String(run.equipped_armor_id),
		"companion_id": String(run.equipped_companion_id),
		"skill_loadout_ids": _string_names_to_strings(run.equipped_skill_ids),
	})
	for synergy_id: StringName in run.activated_synergy_ids:
		track_synergy_activated(run, synergy_id)


func track_run_finished(run: RunState, result: StringName, reason: StringName = &"") -> void:
	if run == null or run.telemetry_finished:
		return
	run.telemetry_finished = true
	var loot_rarity: String = "none"
	var loot: EquipmentData = EquipmentCatalog.get_by_id(run.pending_loot_id)
	if loot != null:
		loot_rarity = ["common", "rare", "epic"][loot.rarity]
	var properties: Dictionary = {
		"result": String(result), "biome_id": String(run.biome_id),
		"run_level": run.run_level, "combats_won": run.combats_won,
		"board_progress_bucket": board_progress_bucket(run),
		"active_synergy_count": run.activated_synergy_ids.size(),
		"active_synergy_ids": _string_names_to_strings(run.activated_synergy_ids),
		"loot_rarity": loot_rarity, "duration_bucket": _duration_bucket(run),
		"ash_earned_bucket": _ash_bucket(run.run_ash),
		"ember_slash_uses": int(run.telemetry_skill_uses.get("ember_slash", 0)),
		"ashen_guard_uses": int(run.telemetry_skill_uses.get("ashen_guard", 0)),
		"second_wind_uses": int(run.telemetry_skill_uses.get("second_wind", 0)),
	}
	if not run.telemetry_last_boss_id.is_empty():
		properties["boss_id"] = String(run.telemetry_last_boss_id)
	if not reason.is_empty():
		properties["reason"] = String(reason)
	track(TelemetryEventNames.RUN_FINISHED, properties)
	flush()


func track_run_abandoned(run: RunState) -> void:
	if run == null or run.telemetry_finished:
		return
	run.telemetry_finished = true
	track(TelemetryEventNames.RUN_ABANDONED, {
		"biome_id": String(run.biome_id), "board_position": run.board_position,
		"run_level": run.run_level, "combats_won": run.combats_won,
		"board_progress_bucket": board_progress_bucket(run),
	})
	flush()


func track_route_choice_shown(run: RunState, option_a_type: String, option_b_type: String, option_a_distance: int, option_b_distance: int) -> void:
	if run == null:
		return
	track(TelemetryEventNames.ROUTE_CHOICE_SHOWN, {
		"biome_id": String(run.biome_id), "option_a_type": option_a_type,
		"option_b_type": option_b_type, "option_a_distance": option_a_distance,
		"option_b_distance": option_b_distance,
		"player_hp_bucket": _health_bucket(run.current_health, run.max_health),
	})


func track_route_choice_selected(run: RunState, chosen_type: String, chosen_distance: int) -> void:
	if run == null:
		return
	track(TelemetryEventNames.ROUTE_CHOICE_SELECTED, {
		"biome_id": String(run.biome_id), "chosen_type": chosen_type,
		"chosen_distance": chosen_distance,
		"player_hp_bucket": _health_bucket(run.current_health, run.max_health),
	})


func track_event_choice_shown(run: RunState, event_id: StringName, option_a_id: StringName, option_b_id: StringName) -> void:
	track(TelemetryEventNames.EVENT_CHOICE_SHOWN, {
		"biome_id": String(run.biome_id), "event_id": String(event_id),
		"option_ids": [String(option_a_id), String(option_b_id)],
		"player_hp_bucket": _health_bucket(run.current_health, run.max_health),
	})


func track_event_choice_selected(run: RunState, event_id: StringName, option_id: StringName, reward_type: String) -> void:
	track(TelemetryEventNames.EVENT_CHOICE_SELECTED, {
		"biome_id": String(run.biome_id), "event_id": String(event_id),
		"option_id": String(option_id), "reward_type": reward_type,
		"player_hp_bucket": _health_bucket(run.current_health, run.max_health),
	})


func track_treasure_choice_shown(run: RunState, offers: Array[Dictionary]) -> void:
	var types: Array[String] = []
	for offer: Dictionary in offers:
		types.append(String(offer.get("kind", "none")))
	track(TelemetryEventNames.TREASURE_CHOICE_SHOWN, {
		"biome_id": String(run.biome_id), "offer_types": types,
		"player_hp_bucket": _health_bucket(run.current_health, run.max_health),
	})


func track_treasure_choice_selected(run: RunState, offer_id: String, reward_type: String) -> void:
	track(TelemetryEventNames.TREASURE_CHOICE_SELECTED, {
		"biome_id": String(run.biome_id), "offer_id": offer_id,
		"reward_type": reward_type,
		"player_hp_bucket": _health_bucket(run.current_health, run.max_health),
	})


func track_combat_started(run: RunState, encounter_type: StringName, enemy_ids: Array[StringName], template_id: StringName = &"") -> void:
	var properties: Dictionary = {
		"encounter_type": String(encounter_type), "enemy_count": enemy_ids.size(),
		"enemy_ids": _string_names_to_strings(enemy_ids),
		"biome_id": String(run.biome_id), "board_progress_bucket": board_progress_bucket(run),
	}
	if not template_id.is_empty():
		properties["template_id"] = String(template_id)
	track(TelemetryEventNames.COMBAT_STARTED, properties)


func track_combat_finished(result: StringName, turn_count: int, hp: int, max_hp: int, companion_alive: bool, enemy_count: int, encounter_type: StringName) -> void:
	track(TelemetryEventNames.COMBAT_FINISHED, {
		"result": String(result), "turn_count": maxi(0, turn_count),
		"player_hp_bucket": _health_bucket(hp, max_hp), "companion_alive": companion_alive,
		"enemy_count": enemy_count, "encounter_type": String(encounter_type),
	})


func track_enemy_intent_shown(category: StringName, intensity: String, target_known: bool, is_boss: bool) -> void:
	track(TelemetryEventNames.ENEMY_INTENT_SHOWN, {
		"category": String(category), "intensity": intensity,
		"target_known": target_known, "is_boss": is_boss,
	})


func track_player_target_changed_after_intent(selected_category: StringName) -> void:
	track(TelemetryEventNames.PLAYER_TARGET_CHANGED_AFTER_INTENT, {
		"selected_category": String(selected_category),
	})


func track_guard_used_against_attack_intent(incoming_attack_count: int) -> void:
	if incoming_attack_count <= 0:
		return
	track(TelemetryEventNames.GUARD_USED_AGAINST_ATTACK_INTENT, {
		"incoming_attack_count": incoming_attack_count,
	})


func track_skill_used_against_high_threat(skill_id: StringName, intent_category: StringName) -> void:
	track(TelemetryEventNames.SKILL_USED_AGAINST_HIGH_THREAT, {
		"skill_id": String(skill_id), "intent_category": String(intent_category),
	})


func track_enemy_killed_before_intent_execution(intent_category: StringName) -> void:
	track(TelemetryEventNames.ENEMY_KILLED_BEFORE_INTENT_EXECUTION, {
		"intent_category": String(intent_category),
	})


func track_boss_started(run: RunState, boss_id: StringName) -> void:
	if run == null:
		return
	run.telemetry_last_boss_id = boss_id
	run.telemetry_boss_phase_reached = 1
	track(TelemetryEventNames.BOSS_STARTED, {"boss_id": String(boss_id), "biome_id": String(run.biome_id)})


func track_boss_phase(run: RunState, boss_id: StringName, phase: int) -> void:
	if run == null or phase <= run.telemetry_boss_phase_reached:
		return
	run.telemetry_boss_phase_reached = phase
	track(TelemetryEventNames.BOSS_PHASE_REACHED, {"boss_id": String(boss_id), "phase": phase})


func track_boss_finished(run: RunState, boss_id: StringName, result: StringName) -> void:
	if run == null:
		return
	track(TelemetryEventNames.BOSS_FINISHED, {
		"boss_id": String(boss_id), "result": String(result),
		"phase_reached": maxi(1, run.telemetry_boss_phase_reached),
	})


func track_synergy_activated(run: RunState, synergy_id: StringName) -> void:
	if run == null or not run.telemetry_started or synergy_id in run.telemetry_synergy_ids:
		return
	run.telemetry_synergy_ids.append(synergy_id)
	track(TelemetryEventNames.SYNERGY_ACTIVATED, {"synergy_id": String(synergy_id)})


func track_milestone_completed(milestone_id: StringName) -> void:
	track(TelemetryEventNames.MILESTONE_COMPLETED, {"milestone_id": String(milestone_id)})


func track_meta_unlock_purchased(unlock_id: StringName, ash_cost: int) -> void:
	track(TelemetryEventNames.META_UNLOCK_PURCHASED, {
		"unlock_id": String(unlock_id),
		"ash_cost": maxi(0, ash_cost),
	})


func track_meta_loadout_selected(option_id: StringName) -> void:
	track(TelemetryEventNames.META_LOADOUT_SELECTED, {"option_id": String(option_id)})


func track_duplicate_converted(equipment_id: StringName, duplicate_count: int, ash_awarded: int) -> void:
	track(TelemetryEventNames.DUPLICATE_CONVERTED, {
		"equipment_id": String(equipment_id),
		"duplicate_count": maxi(0, duplicate_count),
		"ash_awarded": maxi(0, ash_awarded),
	})


func report_error(error_code: StringName, system: StringName, context_code: StringName) -> void:
	track(TelemetryEventNames.ERROR_REPORTED, {
		"error_code": String(error_code), "system": String(system),
		"context_code": String(context_code), "fatal": false,
	})


func report_fatal_error(error_code: StringName, system: StringName, context_code: StringName) -> void:
	var properties: Dictionary = {
		"error_code": String(error_code), "system": String(system),
		"context_code": String(context_code), "fatal": true,
	}
	if not track(TelemetryEventNames.ERROR_REPORTED, properties):
		return
	flush()
	_write_fatal_log(properties)


func record_skill_use(run: RunState, skill_id: StringName) -> void:
	if run == null or skill_id not in [&"ember_slash", &"ashen_guard", &"second_wind"]:
		return
	var key: String = String(skill_id)
	run.telemetry_skill_uses[key] = int(run.telemetry_skill_uses.get(key, 0)) + 1


func board_progress_bucket(run: RunState) -> String:
	if run == null or run.board_tile_sequence.size() <= 1:
		return "unknown"
	var ratio: float = float(run.board_position) / float(run.board_tile_sequence.size() - 1)
	if ratio < 0.25:
		return "early"
	if ratio < 0.65:
		return "mid"
	if ratio < 1.0:
		return "late"
	return "boss"


func _load_schema() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA_PATH))
	if parsed is Dictionary and int(parsed.get("schema_version", 0)) == 1:
		_schema = parsed
	else:
		push_warning("Telemetry schema could not be loaded; telemetry remains disabled.")


func _validate_event(event_name: StringName, properties: Dictionary) -> Variant:
	var events: Dictionary = _schema.get("events", {})
	var event_key: String = String(event_name)
	if event_key not in events or event_name not in TelemetryEventNames.ALL:
		return null
	var contract: Dictionary = events[event_key]
	var allowed: Dictionary = contract.get("properties", {})
	for required: Variant in contract.get("required", []):
		if String(required) not in properties:
			return null
	var result: Dictionary = {}
	for key: Variant in properties:
		var property_name: String = String(key)
		if property_name not in allowed:
			return null
		var value: Variant = properties[key]
		if not _matches_type(value, String(allowed[property_name])) or not _is_safe_value(value):
			return null
		result[property_name] = value
	return result


func _matches_type(value: Variant, expected: String) -> bool:
	match expected:
		"bool": return value is bool
		"int": return value is int
		"float": return value is float or value is int
		"string": return value is String or value is StringName
		"string_array":
			if not value is Array or value.size() > MAX_ARRAY_LENGTH:
				return false
			for item: Variant in value:
				if not item is String and not item is StringName:
					return false
			return true
	return false


func _is_safe_value(value: Variant) -> bool:
	if value is String or value is StringName:
		return _is_safe_string(String(value))
	if value is Array:
		for item: Variant in value:
			if not _is_safe_string(String(item)):
				return false
	return true


func _is_safe_string(value: String) -> bool:
	if value.length() > MAX_STRING_LENGTH:
		return false
	var lowered: String = value.to_lower()
	for forbidden: String in ["\\", "/", "@", "user:", "res:", "appdata", "password", "token"]:
		if forbidden in lowered:
			return false
	return true


func _prepare_event_file(incoming_bytes: int) -> bool:
	if _current_event_path.is_empty() or not FileAccess.file_exists(_current_event_path) or FileAccess.get_file_as_bytes(_current_event_path).size() + incoming_bytes > MAX_EVENT_FILE_BYTES:
		_current_event_path = "%s/events_%s_%d.jsonl" % [TELEMETRY_DIR, Time.get_datetime_string_from_system(true, false).replace(":", ""), Time.get_ticks_msec()]
	_enforce_event_limits(incoming_bytes)
	return true


func _enforce_event_limits(incoming_bytes: int) -> void:
	var files: PackedStringArray = DirAccess.get_files_at(TELEMETRY_DIR)
	var event_files: Array[String] = []
	for filename: String in files:
		if filename.begins_with("events_") and filename.ends_with(".jsonl"):
			event_files.append(filename)
	event_files.sort()
	var total: int = incoming_bytes
	for filename: String in event_files:
		total += FileAccess.get_file_as_bytes(TELEMETRY_DIR + "/" + filename).size()
	while not event_files.is_empty() and (event_files.size() >= MAX_EVENT_FILES or total > MAX_TOTAL_EVENT_BYTES):
		var oldest: String = event_files.pop_front()
		var path: String = TELEMETRY_DIR + "/" + oldest
		total -= FileAccess.get_file_as_bytes(path).size()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_session_marker() -> void:
	var file: FileAccess = FileAccess.open(SESSION_MARKER_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"schema_version": 1, "session_id": session_id, "opened_utc": Time.get_datetime_string_from_system(true, false) + "Z"}))
		file.close()


func _write_fatal_log(properties: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIR))
	var files: Array[String] = []
	for filename: String in DirAccess.get_files_at(LOG_DIR):
		if filename.begins_with("fatal_") and filename.ends_with(".json"):
			files.append(filename)
	files.sort()
	while files.size() >= MAX_FATAL_LOG_FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_DIR + "/" + files.pop_front()))
	var payload: String = JSON.stringify({"schema_version": 1, "timestamp_utc": Time.get_datetime_string_from_system(true, false) + "Z", "session_id": session_id, "error": properties})
	if payload.to_utf8_buffer().size() > MAX_FATAL_LOG_BYTES:
		return
	var path: String = "%s/fatal_%s_%d.json" % [LOG_DIR, Time.get_datetime_string_from_system(true, false).replace(":", ""), Time.get_ticks_msec()]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(payload)
		file.close()


func _new_session_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


func _string_names_to_strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		if result.size() >= MAX_ARRAY_LENGTH:
			break
		result.append(String(value))
	return result


func _duration_bucket(run: RunState) -> String:
	var elapsed: int = maxi(0, int(Time.get_unix_time_from_system()) - run.telemetry_started_unix)
	if elapsed < 300: return "under_5m"
	if elapsed < 600: return "5_to_10m"
	if elapsed < 1200: return "10_to_20m"
	return "20m_plus"


func _ash_bucket(amount: int) -> String:
	if amount <= 0: return "zero"
	if amount < 25: return "1_to_24"
	if amount < 75: return "25_to_74"
	return "75_plus"


func _health_bucket(hp: int, max_hp: int) -> String:
	if hp <= 0 or max_hp <= 0: return "empty"
	var ratio: float = float(hp) / float(max_hp)
	if ratio < 0.25: return "low"
	if ratio < 0.60: return "mid"
	if ratio < 1.0: return "high"
	return "full"

class_name DiscoveryTracker
extends RefCounted


static func make_key(category: StringName, entry_id: StringName) -> String:
	return "%s:%s" % [String(category), String(entry_id)]


static func discover(category: StringName, entry_id: StringName, save_immediately: bool = true) -> bool:
	if SaveManager.is_future_save_loaded:
		return false
	if not CodexCatalog.has_entry(category, entry_id):
		return false
	var key: String = make_key(category, entry_id)
	if key in SaveManager.profile.discovered_codex_entries:
		return false
	SaveManager.profile.discovered_codex_entries.append(key)
	SaveManager.profile_changed.emit()
	if save_immediately:
		SaveManager.save_profile()
	var entry: CodexEntry = CodexCatalog.get_entry(category, entry_id)
	SaveManager.notify_codex_discovered(entry.display_name)
	AudioManager.play_sfx(AudioManager.Sfx.CODEX_DISCOVERED)
	return true


static func discover_many(category: StringName, entry_ids: Array[StringName]) -> int:
	var discovered_count: int = 0
	for entry_id: StringName in entry_ids:
		if discover(category, entry_id, false):
			discovered_count += 1
	if discovered_count > 0:
		var milestones: Array[StringName] = []
		if category == CodexCatalog.SYNERGIES:
			milestones = SaveManager.evaluate_milestones()
		if milestones.is_empty():
			SaveManager.save_profile()
	return discovered_count


static func is_discovered(category: StringName, entry_id: StringName) -> bool:
	return make_key(category, entry_id) in SaveManager.profile.discovered_codex_entries


static func is_seen(category: StringName, entry_id: StringName) -> bool:
	return make_key(category, entry_id) in SaveManager.profile.seen_codex_entries


static func mark_seen(category: StringName, entry_id: StringName) -> bool:
	if SaveManager.is_future_save_loaded:
		return false
	if not is_discovered(category, entry_id) or is_seen(category, entry_id):
		return false
	SaveManager.profile.seen_codex_entries.append(make_key(category, entry_id))
	SaveManager.profile_changed.emit()
	return SaveManager.save_profile()


static func get_discovered_count(category: StringName) -> int:
	return get_discovered_count_for_profile(SaveManager.profile, category)


static func get_discovered_count_for_profile(profile: ProfileData, category: StringName) -> int:
	var count: int = 0
	for entry: CodexEntry in CodexCatalog.get_entries(category):
		if make_key(category, entry.id) in profile.discovered_codex_entries:
			count += 1
	return count


static func get_total_discovered_count() -> int:
	return get_total_discovered_count_for_profile(SaveManager.profile)


static func get_total_discovered_count_for_profile(profile: ProfileData) -> int:
	var total: int = 0
	for category: StringName in CodexCatalog.get_categories():
		total += get_discovered_count_for_profile(profile, category)
	return total


static func category_has_unseen(category: StringName) -> bool:
	for entry: CodexEntry in CodexCatalog.get_entries(category):
		if is_discovered(category, entry.id) and not is_seen(category, entry.id):
			return true
	return false


static func has_unseen_entries() -> bool:
	for category: StringName in CodexCatalog.get_categories():
		if category_has_unseen(category):
			return true
	return false


static func discover_active_synergies(run: RunState) -> void:
	discover_many(CodexCatalog.SYNERGIES, BoonSynergyResolver.get_active_ids(run))


static func sanitize_profile(profile: ProfileData, infer_legacy_equipment: bool) -> void:
	var valid_keys: Dictionary[String, bool] = {}
	for category: StringName in CodexCatalog.get_categories():
		for entry: CodexEntry in CodexCatalog.get_entries(category):
			valid_keys[make_key(category, entry.id)] = true
	profile.discovered_codex_entries = _filtered_unique(profile.discovered_codex_entries, valid_keys)
	profile.seen_codex_entries = _filtered_unique(profile.seen_codex_entries, valid_keys)
	_apply_defaults(profile)
	if infer_legacy_equipment:
		_infer_owned_equipment(profile)
	var discovered_set: Dictionary[String, bool] = {}
	for key: String in profile.discovered_codex_entries:
		discovered_set[key] = true
	profile.seen_codex_entries = _filtered_unique(profile.seen_codex_entries, discovered_set)


static func discover_all_debug() -> bool:
	if SaveManager.is_future_save_loaded or not DebugConfig.DEBUG_TOOLS_ENABLED:
		return false
	var changed: bool = false
	for category: StringName in CodexCatalog.get_categories():
		for entry: CodexEntry in CodexCatalog.get_entries(category):
			var key: String = make_key(category, entry.id)
			if key not in SaveManager.profile.discovered_codex_entries:
				SaveManager.profile.discovered_codex_entries.append(key)
				changed = true
	if changed:
		SaveManager.profile_changed.emit()
		SaveManager.save_profile()
	return changed


static func _apply_defaults(profile: ProfileData) -> void:
	for biome: BiomeData in BiomeCatalog.get_all():
		_add_default_seen(profile, make_key(CodexCatalog.REGIONS, biome.id))
	for active_skill: ActiveSkillData in ActiveSkillCatalog.get_all():
		_add_default_seen(profile, make_key(CodexCatalog.ACTIVE_SKILLS, active_skill.id))
	for companion_id: StringName in profile.unlocked_companion_ids:
		if CompanionCatalog.get_by_id(companion_id) != null:
			_add_default_seen(profile, make_key(CodexCatalog.COMPANIONS, companion_id))


static func _infer_owned_equipment(profile: ProfileData) -> void:
	var equipment_ids: Array[String] = []
	for raw_id: Variant in profile.owned_equipment:
		equipment_ids.append(String(raw_id))
	if not profile.equipped_weapon_id.is_empty():
		equipment_ids.append(profile.equipped_weapon_id)
	if not profile.equipped_armor_id.is_empty():
		equipment_ids.append(profile.equipped_armor_id)
	for equipment_id: String in equipment_ids:
		var item: EquipmentData = EquipmentCatalog.get_by_id(equipment_id)
		if item != null:
			_add_unique(profile.discovered_codex_entries, make_key(CodexCatalog.EQUIPMENT, item.id))


static func _add_default_seen(profile: ProfileData, key: String) -> void:
	_add_unique(profile.discovered_codex_entries, key)
	_add_unique(profile.seen_codex_entries, key)


static func _add_unique(values: Array[String], value: String) -> void:
	if value not in values:
		values.append(value)


static func _filtered_unique(values: Array[String], valid_keys: Dictionary[String, bool]) -> Array[String]:
	var result: Array[String] = []
	for key: String in values:
		if valid_keys.has(key) and key not in result:
			result.append(key)
	return result

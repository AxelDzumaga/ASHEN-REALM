extends Node

const MilestoneCatalogSource = preload("res://scripts/meta/milestone_catalog.gd")
const MilestoneResolverSource = preload("res://scripts/meta/milestone_resolver.gd")

signal profile_changed
signal codex_discovered(display_name: String)

enum SaveResult {
	SUCCESS,
	FAILED,
	BLOCKED_FUTURE_VERSION,
}

const SAVE_VERSION: int = 14
const SAVE_PATH: String = "user://profile.json"

var profile: ProfileData = ProfileData.new()
var save_path: String = SAVE_PATH
var is_future_save_loaded: bool = false
var last_save_result: SaveResult = SaveResult.SUCCESS

var _save_in_progress: bool = false
var _save_pending: bool = false
var _transaction_depth: int = 0
var _transaction_dirty: bool = false
var _corrupt_main_pending_preservation: bool = false
var _economy_operation_in_progress: bool = false


func _ready() -> void:
	load_profile()


## Redirige el profile activo a un archivo aislado, para tests automatizados
## que ejecutan gameplay real (combate, deposit_run, codex, equipment, etc.)
## y por lo tanto pueden disparar save_profile(). Nunca debe alcanzar
## user://profile.json — el profile real del jugador/dev.
## _get_temp_path()/_get_backup_path() derivan de save_path, así que TEMP y
## BACKUP quedan aislados automáticamente, sin cambios adicionales.
## Generaliza el patrón ad-hoc "TEST_SAVE" que ya usaban algunos tests
## (stage72_systems_runtime_test.gd, stage78_economy_runtime_test.gd,
## combined_progression_runtime_test.gd, stage69_meta_test.gd) en un único
## punto reutilizable, en vez de que cada test reimplemente su propia ruta.
func use_isolated_test_profile(test_name: String = "runtime_test") -> bool:
	if not OS.is_debug_build():
		push_warning("use_isolated_test_profile() ignorado fuera de un build de debug — no se aísla el profile.")
		return false
	var isolated_path: String = "user://test_profiles/%s/profile.json" % test_name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(isolated_path.get_base_dir()))
	for suffix: String in ["", ".tmp", ".bak"]:
		_remove_file(isolated_path + suffix)
	save_path = isolated_path
	return load_profile()


func notify_codex_discovered(display_name: String) -> void:
	codex_discovered.emit(display_name)


## Profile System — clears the active character so nothing can accidentally
## save to a just-deselected character's path (e.g. mid-deletion). Callers
## must select a character (or use_isolated_test_profile) again before the
## next save_profile()/load_profile() call.
func clear_active_character() -> void:
	save_path = ""
	profile = ProfileData.new()
	is_future_save_loaded = false


func load_profile() -> bool:
	if save_path.is_empty():
		return false
	profile = ProfileData.new()
	is_future_save_loaded = false
	_corrupt_main_pending_preservation = false
	var temp_path: String = _get_temp_path()
	var backup_path: String = _get_backup_path()
	var main_exists: bool = FileAccess.file_exists(save_path)
	var main_candidate: Dictionary = _read_candidate(save_path, false) if main_exists else _invalid_candidate()

	if bool(main_candidate["valid"]):
		if int(main_candidate["version"]) <= SAVE_VERSION:
			_cleanup_residual_temp(temp_path)
		return _load_candidate(main_candidate, "main")

	if main_exists:
		_corrupt_main_pending_preservation = true
		push_warning("The main profile save is invalid. Recovery candidates will be checked without overwriting it.")

	var temp_candidate: Dictionary = _read_candidate(temp_path, true) if FileAccess.file_exists(temp_path) else _invalid_candidate()
	if bool(temp_candidate["valid"]) and int(temp_candidate["version"]) <= SAVE_VERSION:
		if _promote_recovery_temp(temp_path):
			_corrupt_main_pending_preservation = false
			print("Recovered profile from a complete temporary save.")
			return _load_candidate(temp_candidate, "temporary")
		push_warning("A valid temporary profile was found but could not be promoted. It will remain available for recovery.")
	if bool(temp_candidate["valid"]) and int(temp_candidate["version"]) > SAVE_VERSION:
		return _load_candidate(temp_candidate, "future temporary save")

	var backup_candidate: Dictionary = _read_candidate(backup_path, false) if FileAccess.file_exists(backup_path) else _invalid_candidate()
	if bool(backup_candidate["valid"]):
		if int(backup_candidate["version"]) > SAVE_VERSION:
			return _load_candidate(backup_candidate, "future backup")
		if _restore_backup(backup_path, temp_path):
			_corrupt_main_pending_preservation = false
			print("Recovered profile from backup.")
		else:
			push_warning("The backup profile is valid but MAIN could not be restored. The backup was loaded in memory and left intact.")
		return _load_candidate(backup_candidate, "backup")

	DiscoveryTracker.sanitize_profile(profile, false)
	if not main_exists:
		return save_profile()
	push_warning("No valid MAIN, TEMP, or BACKUP profile was available. Defaults are active; the corrupt MAIN will be preserved before a new save is created.")
	return false


func save_profile() -> bool:
	if save_path.is_empty():
		last_save_result = SaveResult.FAILED
		return false
	if is_future_save_loaded:
		last_save_result = SaveResult.BLOCKED_FUTURE_VERSION
		push_warning("Profile save blocked: the loaded data belongs to a newer save version.")
		return false
	if _transaction_depth > 0:
		_transaction_dirty = true
		return true
	if _save_in_progress:
		_save_pending = true
		return true

	_save_in_progress = true
	var success: bool = _write_profile_safely()
	if _save_pending:
		_save_pending = false
		if success:
			success = _write_profile_safely()
	_save_in_progress = false
	last_save_result = SaveResult.SUCCESS if success else SaveResult.FAILED
	return success


func begin_save_transaction() -> void:
	_transaction_depth += 1


func end_save_transaction() -> bool:
	if _transaction_depth <= 0:
		push_warning("Save transaction ended without a matching begin.")
		return false
	_transaction_depth -= 1
	if _transaction_depth > 0:
		return true
	if not _transaction_dirty:
		return true
	_transaction_dirty = false
	return save_profile()


func try_purchase_upgrade(type: PermanentUpgradeConfig.UpgradeType) -> bool:
	if is_future_save_loaded:
		return false
	var current_level := PermanentUpgradeConfig.get_level(profile, type)
	if current_level >= PermanentUpgradeConfig.MAX_LEVEL:
		return false
	var cost := PermanentUpgradeConfig.get_cost(type, current_level)
	if profile.total_ash < cost:
		return false

	profile.total_ash -= cost
	PermanentUpgradeConfig.set_level(profile, type, current_level + 1)
	profile_changed.emit()
	if not save_profile():
		return false
	evaluate_milestones()
	return true


func try_purchase_meta_unlock(unlock_id: StringName) -> bool:
	if is_future_save_loaded or MetaUnlockCatalog.is_owned(profile, unlock_id):
		return false
	var unlock: Dictionary = MetaUnlockCatalog.get_by_id(unlock_id)
	if unlock.is_empty() or not MetaUnlockCatalog.meets_condition(profile, unlock_id):
		return false
	var cost: int = int(unlock["cost"])
	if profile.total_ash < cost:
		return false
	profile.total_ash -= cost
	profile.owned_meta_unlock_ids.append(unlock_id)
	profile.owned_meta_unlock_ids = MetaUnlockCatalog.sanitize_owned_ids(profile.owned_meta_unlock_ids)
	profile.selected_starting_option_id = unlock_id
	profile_changed.emit()
	if not save_profile():
		return false
	TelemetryManager.track_meta_unlock_purchased(unlock_id, cost)
	return true


func select_starting_option(unlock_id: StringName) -> bool:
	if is_future_save_loaded:
		return false
	var safe_id: StringName = MetaUnlockCatalog.sanitize_selected_id(unlock_id, profile.owned_meta_unlock_ids)
	if safe_id != unlock_id:
		return false
	profile.selected_starting_option_id = safe_id
	profile_changed.emit()
	if not save_profile():
		return false
	TelemetryManager.track_meta_loadout_selected(safe_id)
	return true


func clear_starting_option() -> bool:
	if is_future_save_loaded:
		return false
	profile.selected_starting_option_id = &""
	profile_changed.emit()
	if not save_profile():
		return false
	TelemetryManager.track_meta_loadout_selected(&"none")
	return true


func deposit_run(run_state: RunState) -> bool:
	if is_future_save_loaded or run_state == null or run_state.rewards_deposited:
		return false

	var profile_before: Dictionary = profile.to_dictionary()
	begin_save_transaction()
	run_state.player_xp_earned = PlayerProgressionConfig.calculate_run_xp(run_state)
	run_state.player_level_before = profile.player_level
	run_state.player_xp_before = profile.player_xp
	run_state.player_levels_gained = profile.add_player_xp(run_state.player_xp_earned)
	run_state.player_level_after = profile.player_level
	run_state.player_xp_after = profile.player_xp
	profile.total_ash += maxi(0, run_state.run_ash)
	if run_state.biome_material_earned > 0 and run_state.biome_id != &"":
		var biome_key := String(run_state.biome_id)
		profile.biome_materials[biome_key] = int(profile.biome_materials.get(biome_key, 0)) + run_state.biome_material_earned
	profile.total_runs += 1
	profile.total_combats_won += run_state.combats_won + (1 if run_state.run_completed else 0)
	if run_state.equipped_companion_id != &"":
		profile.total_companion_runs += 1
	if run_state.run_completed:
		profile.total_victories += 1
		profile.total_bosses_defeated += 1
		if run_state.biome_data != null and run_state.biome_data.boss != null:
			var boss_id: String = String(run_state.biome_data.boss.id)
			profile.boss_defeat_counts[boss_id] = int(profile.boss_defeat_counts.get(boss_id, 0)) + 1
			var encounter: BossEncounterData = run_state.biome_data.boss.boss_encounter
			if encounter != null and ChestCatalog.get_by_id(encounter.boss_chest_id) != null:
				var chest_key := String(encounter.boss_chest_id)
				profile.unopened_chests[chest_key] = int(profile.unopened_chests.get(chest_key, 0)) + 1
				profile.guardian_sigils += maxi(0, encounter.guardian_sigils_reward)
				run_state.boss_chest_id = encounter.boss_chest_id
				run_state.boss_chest_awarded = true
				run_state.guardian_sigils_awarded = maxi(0, encounter.guardian_sigils_reward)
	else:
		profile.total_defeats += 1
	if not run_state.pending_loot_id.is_empty():
		_grant_or_salvage_equipment(run_state.pending_loot_id, run_state)
	var milestone_result: MilestoneResolverSource.CompletionResult = MilestoneResolverSource.evaluate(profile)
	profile_changed.emit()
	save_profile()
	var saved: bool = end_save_transaction()
	if not saved:
		profile = ProfileData.from_dictionary(profile_before)
		profile_changed.emit()
		return false
	run_state.rewards_deposited = true
	_record_run_milestones(run_state, milestone_result)
	_emit_milestone_telemetry(milestone_result)
	return true


func evaluate_milestones() -> Array[StringName]:
	if is_future_save_loaded:
		return []
	var profile_before: Dictionary = profile.to_dictionary()
	var result: MilestoneResolverSource.CompletionResult = MilestoneResolverSource.evaluate(profile)
	if result.completed_ids.is_empty():
		return []
	profile_changed.emit()
	if not save_profile():
		profile = ProfileData.from_dictionary(profile_before)
		profile_changed.emit()
		return []
	if RunManager.has_active_run():
		_record_run_milestones(RunManager.current_run, result)
	_emit_milestone_telemetry(result)
	return result.completed_ids


func _record_run_milestones(run_state: RunState, result: MilestoneResolverSource.CompletionResult) -> void:
	if run_state == null or result == null:
		return
	for milestone_id: StringName in result.completed_ids:
		if milestone_id not in run_state.completed_milestone_ids_this_run:
			run_state.completed_milestone_ids_this_run.append(milestone_id)
	run_state.milestone_ash_awarded += result.reward_ash


func _emit_milestone_telemetry(result: MilestoneResolverSource.CompletionResult) -> void:
	if result == null:
		return
	for milestone_id: StringName in result.completed_ids:
		TelemetryManager.track_milestone_completed(milestone_id)


func acknowledge_milestone_announcements(ids: Array[StringName]) -> bool:
	if is_future_save_loaded or ids.is_empty():
		return false
	var changed: bool = false
	for milestone_id: StringName in ids:
		var value: String = String(milestone_id)
		if value in profile.pending_milestone_ids:
			profile.pending_milestone_ids.erase(value)
			changed = true
	return save_profile() if changed else false


func get_pending_milestone_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for value: String in profile.pending_milestone_ids:
		if MilestoneCatalogSource.get_by_id(StringName(value)) != null:
			result.append(StringName(value))
	return result


func add_debug_ash(amount: int = 100) -> bool:
	if is_future_save_loaded or not DebugConfig.DEBUG_TOOLS_ENABLED or amount <= 0:
		return false
	profile.total_ash += amount
	profile_changed.emit()
	save_profile()
	return true


func equip_item(equipment_id: String) -> bool:
	if is_future_save_loaded:
		return false
	var item := EquipmentCatalog.get_by_id(equipment_id)
	if item == null or int(profile.owned_equipment.get(equipment_id, 0)) <= 0:
		return false
	if not can_equip_item(item):
		return false
	match item.slot:
		EquipmentData.Slot.WEAPON:
			profile.equipped_weapon_id = equipment_id
		EquipmentData.Slot.CHEST:
			profile.equipped_armor_id = equipment_id
		EquipmentData.Slot.HEAD, EquipmentData.Slot.CAPE, EquipmentData.Slot.RELIC:
			profile.equipped_slots[EquipmentData.get_slot_name(item.slot).to_lower()] = equipment_id
		_:
			return false
	profile_changed.emit()
	return save_profile()


## Equipment 2.0 Fase 1 — único punto que resuelve "qué está equipado en
## este slot", para no repetir la rama WEAPON/CHEST/resto en cada llamador.
func get_equipped_id_for_slot(slot: EquipmentData.Slot) -> String:
	return EquipmentCatalog.get_equipped_id_for_slot(profile, slot)


func can_equip_item(item: EquipmentData) -> bool:
	return item != null and profile.player_level >= item.required_level


## Bloqueo manual (jugador) + bloqueo automático implícito: cualquier pieza
## de un set (set_id no vacío — hoy solo sets de boss) que esté equipada
## ahora mismo, sin que el jugador tenga que marcarla a mano.
func is_equipment_locked(equipment_id: String) -> bool:
	if equipment_id in profile.locked_equipment_ids:
		return true
	var item: EquipmentData = EquipmentCatalog.get_by_id(equipment_id)
	if item == null or item.set_id.is_empty():
		return false
	return get_equipped_id_for_slot(item.slot) == equipment_id


func is_equipment_favorite(equipment_id: String) -> bool:
	return equipment_id in profile.favorite_equipment_ids


func toggle_equipment_favorite(equipment_id: String) -> bool:
	if int(profile.owned_equipment.get(equipment_id, 0)) <= 0:
		return false
	if equipment_id in profile.favorite_equipment_ids:
		profile.favorite_equipment_ids.erase(equipment_id)
	else:
		profile.favorite_equipment_ids.append(equipment_id)
	profile_changed.emit()
	return save_profile()


## Solo alterna el bloqueo manual — el automático (set de boss equipado) no
## se puede desactivar a mano, por diseño.
func toggle_equipment_lock(equipment_id: String) -> bool:
	if is_future_save_loaded or int(profile.owned_equipment.get(equipment_id, 0)) <= 0:
		return false
	if equipment_id in profile.locked_equipment_ids:
		profile.locked_equipment_ids.erase(equipment_id)
	else:
		profile.locked_equipment_ids.append(equipment_id)
	profile_changed.emit()
	return save_profile()


func is_equipment_new(equipment_id: String) -> bool:
	return int(profile.owned_equipment.get(equipment_id, 0)) > 0 and equipment_id not in profile.seen_equipment_ids


func mark_all_equipment_seen() -> bool:
	var changed := false
	for equipment_id: Variant in profile.owned_equipment.keys():
		var id_string: String = String(equipment_id)
		if id_string not in profile.seen_equipment_ids:
			profile.seen_equipment_ids.append(id_string)
			changed = true
	if not changed:
		return true
	profile_changed.emit()
	return save_profile()


func purchase_shop_offer(offer_id: StringName) -> bool:
	if is_future_save_loaded or _economy_operation_in_progress:
		return false
	var offer: ShopOfferData = ShopCatalog.get_by_id(offer_id, profile)
	if offer == null or offer.price <= 0:
		return false
	var purchase_key: String = ShopCatalog.purchase_key(offer, profile)
	if offer.stock_per_rotation > 0 and int(profile.shop_purchase_counts.get(purchase_key, 0)) >= offer.stock_per_rotation:
		return false
	if not _can_afford(offer.currency, offer.price):
		return false
	if offer.reward_type == ShopOfferData.RewardType.EQUIPMENT and int(profile.owned_equipment.get(String(offer.reward_id), 0)) > 0:
		return false
	_economy_operation_in_progress = true
	var snapshot: Dictionary = profile.to_dictionary()
	_deduct_currency(offer.currency, offer.price)
	var applied: bool = _apply_shop_reward(offer)
	if applied and offer.stock_per_rotation > 0:
		profile.shop_purchase_counts[purchase_key] = int(profile.shop_purchase_counts.get(purchase_key, 0)) + 1
	profile_changed.emit()
	var saved: bool = applied and save_profile()
	if not saved:
		profile = ProfileData.from_dictionary(snapshot)
		profile_changed.emit()
	_economy_operation_in_progress = false
	return saved


func open_chest(chest_id: StringName, seed_override: int = -1) -> Dictionary:
	if is_future_save_loaded or _economy_operation_in_progress:
		return {}
	var chest: ChestData = ChestCatalog.get_by_id(chest_id)
	var key := String(chest_id)
	if chest == null or int(profile.unopened_chests.get(key, 0)) <= 0:
		return {}
	var opened_before: int = int(profile.opened_chest_counts.get(key, 0))
	var seed_value: int = seed_override if seed_override >= 0 else hash("%s:%d:%d" % [key, opened_before, profile.total_runs])
	var reward: Dictionary = ChestResolver.resolve(chest, profile, seed_value)
	if reward.is_empty():
		return {}
	_economy_operation_in_progress = true
	var snapshot: Dictionary = profile.to_dictionary()
	profile.unopened_chests[key] = int(profile.unopened_chests[key]) - 1
	if int(profile.unopened_chests[key]) <= 0:
		profile.unopened_chests.erase(key)
	for equipment_id: String in reward.get("items", []):
		_grant_equipment_to_profile(equipment_id)
	profile.total_ash += maxi(0, int(reward.get("ash", 0)))
	profile.forge_shards += maxi(0, int(reward.get("forge_shards", 0)))
	var pity_key: String = String(reward.get("pity_key", ""))
	if not pity_key.is_empty():
		var pity_after: int = maxi(0, int(reward.get("pity_after", 0)))
		if pity_after == 0:
			profile.chest_pity.erase(pity_key)
		else:
			profile.chest_pity[pity_key] = pity_after
	profile.opened_chest_counts[key] = opened_before + 1
	profile_changed.emit()
	var saved: bool = save_profile()
	if not saved:
		profile = ProfileData.from_dictionary(snapshot)
		profile_changed.emit()
		reward = {}
	_economy_operation_in_progress = false
	return reward


func refine_equipment(equipment_id: String) -> bool:
	if is_future_save_loaded or _economy_operation_in_progress or int(profile.owned_equipment.get(equipment_id, 0)) <= 0:
		return false
	var item: EquipmentData = EquipmentCatalog.get_by_id(equipment_id)
	var current_level: int = int(profile.equipment_refinement.get(equipment_id, 0))
	var cost: Dictionary = RefinementConfig.get_cost(item, current_level)
	if cost.is_empty():
		return false
	var material_cost: int = int(cost.get("biome_material", 0))
	if profile.total_ash < int(cost["ash"]) or profile.forge_shards < int(cost["forge_shards"]) or profile.guardian_sigils < int(cost["guardian_sigils"]) or not RefinementConfig.has_enough_biome_material(profile, item, material_cost):
		return false
	_economy_operation_in_progress = true
	var snapshot: Dictionary = profile.to_dictionary()
	profile.total_ash -= int(cost["ash"])
	profile.forge_shards -= int(cost["forge_shards"])
	profile.guardian_sigils -= int(cost["guardian_sigils"])
	RefinementConfig.spend_biome_material(profile, item, material_cost)
	profile.equipment_refinement[equipment_id] = int(cost["target_level"])
	profile_changed.emit()
	var saved: bool = save_profile()
	if not saved:
		profile = ProfileData.from_dictionary(snapshot)
		profile_changed.emit()
	_economy_operation_in_progress = false
	return saved


func _can_afford(currency: EconomyConfig.Currency, price: int) -> bool:
	return profile.total_ash >= price if currency == EconomyConfig.Currency.ASH else profile.guardian_sigils >= price


func _deduct_currency(currency: EconomyConfig.Currency, amount: int) -> void:
	if currency == EconomyConfig.Currency.ASH:
		profile.total_ash -= amount
	else:
		profile.guardian_sigils -= amount


func _apply_shop_reward(offer: ShopOfferData) -> bool:
	match offer.reward_type:
		ShopOfferData.RewardType.CHEST:
			if ChestCatalog.get_by_id(offer.reward_id) == null:
				return false
			var key := String(offer.reward_id)
			profile.unopened_chests[key] = int(profile.unopened_chests.get(key, 0)) + offer.quantity
			return true
		ShopOfferData.RewardType.EQUIPMENT:
			return _grant_equipment_to_profile(String(offer.reward_id))
		ShopOfferData.RewardType.FORGE_SHARD:
			profile.forge_shards += offer.quantity
			return true
	return false


func salvage_equipment_duplicates(equipment_id: String) -> int:
	if is_future_save_loaded or is_equipment_locked(equipment_id):
		return 0
	var item: EquipmentData = EquipmentCatalog.get_by_id(equipment_id)
	var quantity: int = int(profile.owned_equipment.get(equipment_id, 0))
	if item == null or quantity <= 1:
		return 0
	var duplicate_count: int = quantity - 1
	var ash_value: int = duplicate_count * EquipmentCatalog.get_duplicate_salvage_ash(item)
	profile.owned_equipment[equipment_id] = 1
	profile.total_ash += ash_value
	profile_changed.emit()
	if not save_profile():
		return 0
	TelemetryManager.track_duplicate_converted(StringName(equipment_id), duplicate_count, ash_value)
	return ash_value


func grant_all_debug_equipment() -> bool:
	if is_future_save_loaded or not DebugConfig.DEBUG_TOOLS_ENABLED:
		return false
	begin_save_transaction()
	for item in EquipmentCatalog.get_all():
		_grant_equipment_to_profile(String(item.id))
	profile_changed.emit()
	save_profile()
	return end_save_transaction()


func select_biome(biome_id: StringName) -> bool:
	if is_future_save_loaded:
		return false
	var safe_id: StringName = BiomeCatalog.sanitize_id(biome_id)
	var biome: BiomeData = BiomeCatalog.get_by_id(safe_id)
	if safe_id != biome_id or not BiomeCatalog.is_unlocked(biome, profile.completed_milestone_ids):
		return false
	profile.selected_biome_id = safe_id
	profile_changed.emit()
	return save_profile()


func select_active_skill(skill_id: StringName) -> bool:
	return set_equipped_skill(0, skill_id)


func set_equipped_companion(companion_id: StringName) -> bool:
	if is_future_save_loaded:
		return false
	var safe_id: StringName = CompanionCatalog.sanitize_equipped_id(
		companion_id,
		profile.unlocked_companion_ids,
	)
	if safe_id != companion_id:
		return false
	profile.equipped_companion_id = safe_id
	profile_changed.emit()
	return save_profile()


func unlock_companion(companion_id: StringName) -> bool:
	if is_future_save_loaded or CompanionCatalog.get_by_id(companion_id) == null:
		return false
	if companion_id in profile.unlocked_companion_ids:
		return false
	profile.unlocked_companion_ids.append(companion_id)
	profile.unlocked_companion_ids = CompanionCatalog.sanitize_unlocked_ids(profile.unlocked_companion_ids)
	DiscoveryTracker.discover(CodexCatalog.COMPANIONS, companion_id, false)
	profile_changed.emit()
	return save_profile()


func set_equipped_skill(slot_index: int, skill_id: StringName) -> bool:
	if is_future_save_loaded or slot_index < 0 or slot_index >= ActiveSkillCatalog.MAX_EQUIPPED_SKILLS:
		return false
	var loadout: Array[StringName] = profile.equipped_skill_ids.duplicate()
	if skill_id.is_empty():
		if slot_index < loadout.size():
			loadout[slot_index] = &""
	else:
		if skill_id not in profile.unlocked_skill_ids or ActiveSkillCatalog.get_by_id(skill_id) == null:
			return false
		var previous_slot: int = loadout.find(skill_id)
		if previous_slot >= 0:
			loadout[previous_slot] = &""
		while loadout.size() < slot_index:
			loadout.append(&"")
		if slot_index < loadout.size():
			loadout[slot_index] = skill_id
		else:
			loadout.append(skill_id)
	profile.equipped_skill_ids = ActiveSkillCatalog.sanitize_loadout(loadout, profile.unlocked_skill_ids)
	profile.selected_active_skill_id = _first_equipped_skill_id(profile.equipped_skill_ids)
	profile_changed.emit()
	return save_profile()


func _first_equipped_skill_id(loadout: Array[StringName]) -> StringName:
	for skill_id: StringName in loadout:
		if not skill_id.is_empty():
			return skill_id
	return ActiveSkillCatalog.DEFAULT_SKILL_ID


func _grant_equipment_to_profile(equipment_id: String) -> bool:
	if EquipmentCatalog.get_by_id(equipment_id) == null:
		return false
	profile.owned_equipment[equipment_id] = int(profile.owned_equipment.get(equipment_id, 0)) + 1
	DiscoveryTracker.discover(CodexCatalog.EQUIPMENT, StringName(equipment_id), false)
	return true


func _grant_or_salvage_equipment(equipment_id: String, run_state: RunState) -> bool:
	var item: EquipmentData = EquipmentCatalog.get_by_id(equipment_id)
	if item == null:
		return false
	if int(profile.owned_equipment.get(equipment_id, 0)) <= 0:
		return _grant_equipment_to_profile(equipment_id)
	var ash_value: int = EquipmentCatalog.get_duplicate_salvage_ash(item)
	profile.total_ash += ash_value
	run_state.duplicate_converted_id = StringName(equipment_id)
	run_state.duplicate_ash_awarded = ash_value
	TelemetryManager.track_duplicate_converted(StringName(equipment_id), 1, ash_value)
	return true


func _write_profile_safely() -> bool:
	var temp_path: String = _get_temp_path()
	var backup_path: String = _get_backup_path()
	var data: Dictionary = profile.to_dictionary()
	data["save_version"] = SAVE_VERSION
	var json_text: String = JSON.stringify(data, "\t")

	if not _write_text_file(temp_path, json_text):
		push_warning("Profile save failed while writing TEMP.")
		return false
	var temp_candidate: Dictionary = _read_candidate(temp_path, true)
	if not bool(temp_candidate["valid"]) or int(temp_candidate["version"]) != SAVE_VERSION:
		push_warning("Profile TEMP validation failed. MAIN and BACKUP were not changed.")
		return false

	if _corrupt_main_pending_preservation and FileAccess.file_exists(save_path):
		if not _preserve_corrupt_main():
			push_warning("Profile save aborted because the corrupt MAIN could not be preserved.")
			return false
		_corrupt_main_pending_preservation = false

	if FileAccess.file_exists(save_path):
		var main_candidate: Dictionary = _read_candidate(save_path, false)
		if not bool(main_candidate["valid"]):
			if not _preserve_corrupt_main():
				push_warning("Profile save aborted because MAIN became invalid and could not be preserved.")
				return false
		elif not _replace_backup_with_main(backup_path):
			push_warning("Profile save aborted because the previous MAIN could not be preserved as BACKUP.")
			return false

	if not _rename_file(temp_path, save_path):
		push_warning("Profile save failed while promoting TEMP. The previous state remains in BACKUP and TEMP was retained.")
		return false
	if not FileAccess.file_exists(save_path):
		push_warning("Profile save promotion returned without creating MAIN.")
		return false
	print("Profile save succeeded.")
	return true


func _load_candidate(candidate: Dictionary, source: String) -> bool:
	var loaded_version: int = int(candidate["version"])
	var data: Dictionary = candidate["data"]
	if loaded_version > SAVE_VERSION:
		is_future_save_loaded = true
		last_save_result = SaveResult.BLOCKED_FUTURE_VERSION
		push_warning("A future profile version (%d) was loaded from %s in read-only mode. Persistent writes are blocked." % [loaded_version, source])
	profile = ProfileData.from_dictionary(data)
	_migrate_profile(loaded_version)
	DiscoveryTracker.sanitize_profile(profile, loaded_version < 5)
	TutorialManager.sanitize_profile(profile, loaded_version == 5)
	MilestoneResolverSource.sanitize_profile(profile)
	_sanitize_equipment()
	profile.selected_biome_id = BiomeCatalog.sanitize_id(profile.selected_biome_id)
	profile.selected_active_skill_id = ActiveSkillCatalog.sanitize_id(profile.selected_active_skill_id)
	profile.unlocked_skill_ids = ActiveSkillCatalog.sanitize_unlocked_ids(profile.unlocked_skill_ids)
	profile.equipped_skill_ids = ActiveSkillCatalog.sanitize_loadout(profile.equipped_skill_ids, profile.unlocked_skill_ids)
	profile.selected_active_skill_id = _first_equipped_skill_id(profile.equipped_skill_ids)
	profile.unlocked_companion_ids = CompanionCatalog.sanitize_unlocked_ids(profile.unlocked_companion_ids)
	profile.equipped_companion_id = CompanionCatalog.sanitize_equipped_id(
		profile.equipped_companion_id,
		profile.unlocked_companion_ids,
	)
	profile.owned_meta_unlock_ids = MetaUnlockCatalog.sanitize_owned_ids(profile.owned_meta_unlock_ids)
	profile.selected_starting_option_id = MetaUnlockCatalog.sanitize_selected_id(
		profile.selected_starting_option_id,
		profile.owned_meta_unlock_ids,
	)
	if loaded_version < 9:
		MilestoneResolverSource.evaluate(profile)
	profile_changed.emit()
	if loaded_version < SAVE_VERSION:
		return save_profile()
	return true


func _migrate_profile(loaded_version: int) -> void:
	# v10 no contenía progreso permanente y no existe una señal histórica fiable
	# para derivarlo sin inventar progreso.
	if loaded_version < 11:
		profile.player_level = PlayerProgressionConfig.START_LEVEL
		profile.player_xp = 0
	# v11 no contenía economía de cofres ni refinamiento. Los valores por
	# defecto de ProfileData preservan todo el inventario y migran cada pieza a +0.
	if loaded_version < 12:
		profile.guardian_sigils = 0
		profile.forge_shards = 0
		profile.equipment_refinement = {}
		profile.unopened_chests = {}
		profile.chest_pity = {}
		profile.opened_chest_counts = {}
		profile.shop_purchase_counts = {}
	# v12 no contenía moneda de bioma (refinamiento +11 a +20 y drops de Evento
	# todavía no existían).
	if loaded_version < 13:
		profile.biome_materials = {}
	# Equipment 2.0 Fase 1 (v14): ARMOR -> CHEST es un rename ordinal-preservado
	# en EquipmentData.Slot (ver comentario del enum) — ningún .tres ni ningún
	# owned_equipment/equipment_refinement/locked_equipment_ids existente
	# necesita transformarse, ya resuelven a CHEST solos. equipped_slots y
	# favorite_equipment_ids son campos nuevos que ya default a {}/[] vacíos
	# vía ProfileData.from_dictionary cuando el save no los tiene — no hay
	# nada que resetear acá a mano (hacerlo destruiría esos campos si algún
	# día llegan a existir en un save < v14, ej. datos recuperados a mano).
	# Este bloque queda como documentación del corte de versión.
	if loaded_version < 14:
		pass


func _read_candidate(path: String, require_save_version: bool) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _invalid_candidate()
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return _invalid_candidate()
	var data: Dictionary = json.data
	if require_save_version and not data.has("save_version"):
		return _invalid_candidate()
	var raw_version: Variant = data.get("save_version", 1)
	if typeof(raw_version) != TYPE_INT and typeof(raw_version) != TYPE_FLOAT:
		return _invalid_candidate()
	if typeof(raw_version) == TYPE_FLOAT and (is_nan(raw_version) or is_inf(raw_version)):
		return _invalid_candidate()
	var version: int = int(raw_version)
	if version < 1:
		return _invalid_candidate()
	return {"valid": true, "data": data, "version": version}


func _invalid_candidate() -> Dictionary:
	return {"valid": false, "data": {}, "version": 0}


func _write_text_file(path: String, text: String) -> bool:
	# Profile System: character paths are one level deeper than the legacy
	# user://profile.json (user://profiles/<character_id>/profile.json), so
	# the parent directory may not exist yet on a character's first save.
	# No-op (and harmless) for the legacy path, since user:// always exists.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	file.close()
	return FileAccess.file_exists(path)


func _replace_backup_with_main(backup_path: String) -> bool:
	if FileAccess.file_exists(backup_path):
		if not _remove_file(backup_path):
			return false
	return _rename_file(save_path, backup_path)


func _promote_recovery_temp(temp_path: String) -> bool:
	if FileAccess.file_exists(save_path) and not _preserve_corrupt_main():
		return false
	return _rename_file(temp_path, save_path)


func _restore_backup(backup_path: String, temp_path: String) -> bool:
	if FileAccess.file_exists(temp_path) and not _remove_file(temp_path):
		return false
	if not _copy_file(backup_path, temp_path):
		return false
	var copied_candidate: Dictionary = _read_candidate(temp_path, false)
	if not bool(copied_candidate["valid"]):
		return false
	if FileAccess.file_exists(save_path) and not _preserve_corrupt_main():
		return false
	return _rename_file(temp_path, save_path)


func _preserve_corrupt_main() -> bool:
	if not FileAccess.file_exists(save_path):
		return true
	var corrupt_path: String = "%s.corrupt.%d.json" % [save_path.trim_suffix(".json"), int(Time.get_unix_time_from_system())]
	var suffix: int = 1
	while FileAccess.file_exists(corrupt_path):
		corrupt_path = "%s.corrupt.%d.%d.json" % [save_path.trim_suffix(".json"), int(Time.get_unix_time_from_system()), suffix]
		suffix += 1
	if not _rename_file(save_path, corrupt_path):
		return false
	print("Corrupt profile preserved at %s." % corrupt_path)
	return true


func _cleanup_residual_temp(temp_path: String) -> void:
	if FileAccess.file_exists(temp_path) and not _remove_file(temp_path):
		push_warning("A residual profile TEMP could not be removed.")


func _rename_file(from_path: String, to_path: String) -> bool:
	var error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(from_path), ProjectSettings.globalize_path(to_path))
	return error == OK


func _copy_file(from_path: String, to_path: String) -> bool:
	var error: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(from_path), ProjectSettings.globalize_path(to_path))
	return error == OK


func _remove_file(path: String) -> bool:
	var error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return error == OK


func _get_temp_path() -> String:
	return "%s.tmp" % save_path


func _get_backup_path() -> String:
	return "%s.bak" % save_path


func _sanitize_equipment() -> void:
	var valid_inventory: Dictionary = {}
	var valid_refinement: Dictionary = {}
	for equipment_id: Variant in profile.owned_equipment:
		var id_string := String(equipment_id)
		if EquipmentCatalog.get_by_id(id_string) != null:
			valid_inventory[id_string] = profile.owned_equipment[equipment_id]
			var refinement_level: int = clampi(int(profile.equipment_refinement.get(id_string, 0)), 0, RefinementConfig.MAX_REFINEMENT)
			if refinement_level > 0:
				valid_refinement[id_string] = refinement_level
	profile.owned_equipment = valid_inventory
	profile.equipment_refinement = valid_refinement
	var valid_chests: Dictionary = {}
	for chest_id: Variant in profile.unopened_chests:
		var chest_key := String(chest_id)
		if ChestCatalog.get_by_id(StringName(chest_key)) != null:
			valid_chests[chest_key] = profile.unopened_chests[chest_id]
	profile.unopened_chests = valid_chests
	profile.equipped_weapon_id = _sanitize_equipped_id(profile.equipped_weapon_id, EquipmentData.Slot.WEAPON)
	profile.equipped_armor_id = _sanitize_equipped_id(profile.equipped_armor_id, EquipmentData.Slot.CHEST)
	_sanitize_equipped_slots()


## Equipment 2.0 Fase 1 — sanea profile.equipped_slots (HEAD/CAPE/RELIC):
## entradas con slot_name desconocido, ítem no poseído, o slot real
## desalineado con el nombre de la clave se descartan en silencio (nunca
## crashea, nunca corrompe el resto del save).
func _sanitize_equipped_slots() -> void:
	var sanitized: Dictionary[String, String] = {}
	for slot_name: String in profile.equipped_slots:
		var slot_value: int = EquipmentData.slot_from_name(slot_name)
		if slot_value < 0:
			continue
		var sanitized_id: String = _sanitize_equipped_id(profile.equipped_slots[slot_name], slot_value as EquipmentData.Slot)
		if not sanitized_id.is_empty():
			sanitized[slot_name] = sanitized_id
	profile.equipped_slots = sanitized


func _sanitize_equipped_id(equipment_id: String, expected_slot: EquipmentData.Slot) -> String:
	var item := EquipmentCatalog.get_by_id(equipment_id)
	if item == null or item.slot != expected_slot or int(profile.owned_equipment.get(equipment_id, 0)) <= 0:
		return ""
	return equipment_id

extends Node

const TEST_SAVE := "user://combined_progression_runtime/profile.json"

var _checks: Dictionary = {}
var _failures: Array[String] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_SAVE.get_base_dir()))
	SaveManager.save_path = TEST_SAVE
	_cleanup_test_files()
	SaveManager.profile = ProfileData.new()
	_test_region_data()
	await _test_region_runtime()
	_test_event_data()
	await _test_event_runtime()
	_test_boss_data()
	var report := {
		"schema": 1,
		"checks": _checks,
		"failures": _failures,
		"save_version": SaveManager.SAVE_VERSION,
		"debug_tools_enabled": DebugConfig.DEBUG_TOOLS_ENABLED,
		"real_profile_touched": false,
	}
	var output_path := "res://build/combined_ui_progression/progression_runtime.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path.get_base_dir()))
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	_cleanup_test_files()
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_region_data() -> void:
	var wastes: BiomeData = BiomeCatalog.ASHEN_WASTES
	var marsh: BiomeData = BiomeCatalog.EMBER_MARSH
	var ordered: Array[BiomeData] = BiomeCatalog.get_all()
	_check("regions_ordered", ordered.size() == 2 and ordered[0] == wastes and ordered[1] == marsh)
	_check("regions_difficulty_increases", marsh.progression_order > wastes.progression_order and marsh.difficulty_tier > wastes.difficulty_tier)
	_check("regions_route_pressure_increases", marsh.combat_min > wastes.combat_min and marsh.combat_weight > wastes.combat_weight and marsh.empty_weight < wastes.empty_weight and marsh.treasure_weight < wastes.treasure_weight)
	# Core Loop / Final Reward — Ember Marsh's gate is warden_defeated
	# (defeat the Ashen Wastes boss), not first_expedition (finishing any
	# expedition, win or lose — the previous, incorrect gate).
	_check("regions_unlock_requirement", wastes.required_milestone_id.is_empty() and marsh.required_milestone_id == &"warden_defeated")
	_check("regions_distinct_pools", wastes.normal_enemy_pool != marsh.normal_enemy_pool and wastes.elite_enemy_pool != marsh.elite_enemy_pool and wastes.boss != marsh.boss)


func _test_region_runtime() -> void:
	var marsh_id := BiomeCatalog.EMBER_MARSH.id
	_check("locked_region_rejected", not SaveManager.select_biome(marsh_id) and SaveManager.profile.selected_biome_id == BiomeCatalog.DEFAULT_BIOME_ID)
	SaveManager.profile.selected_biome_id = marsh_id
	var fallback_run: RunState = RunManager.start_new_run(710001)
	_check("locked_run_falls_back", fallback_run.biome_id == BiomeCatalog.DEFAULT_BIOME_ID)
	RunManager.end_run()
	SaveManager.profile.selected_biome_id = BiomeCatalog.DEFAULT_BIOME_ID
	var screen: Control = preload("res://scenes/lobby/region_selection.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	var marsh_button: Button = screen.get_node("%EmberMarshButton")
	# Locked text is derived dynamically from the gating milestone's own
	# display_name (region_selection.gd), so this follows the same fix —
	# warden_defeated's display_name is "Vigilia Rota".
	_check("locked_region_visible", marsh_button.disabled and "LOCK" in marsh_button.text and "VIGILIA ROTA" in marsh_button.text)
	SaveManager.profile.completed_milestone_ids.append("warden_defeated")
	SaveManager.profile_changed.emit()
	await get_tree().process_frame
	_check("milestone_unlocks_region", not marsh_button.disabled)
	_check("unlocked_region_persists", SaveManager.select_biome(marsh_id) and SaveManager.profile.selected_biome_id == marsh_id)
	var marsh_run: RunState = RunManager.start_new_run(710002)
	_check("unlocked_run_uses_region", marsh_run.biome_id == marsh_id)
	RunManager.end_run()
	screen.queue_free()
	await get_tree().process_frame


func _test_event_data() -> void:
	var all_events: Array[EventData] = []
	for biome: BiomeData in BiomeCatalog.get_all():
		for event: EventData in biome.event_pool:
			if event not in all_events:
				all_events.append(event)
	var tiers: Dictionary = {}
	var complete: bool = all_events.size() == 9
	var easy_safe: bool = true
	var hard_tradeoffs: bool = true
	for event: EventData in all_events:
		tiers[event.difficulty_tier] = true
		complete = complete and not event.risk_summary.is_empty() and not event.option_a_text.is_empty() and not event.option_b_text.is_empty()
		var has_cost: bool = _option_has_cost(event, true) or _option_has_cost(event, false)
		var has_reward: bool = _option_has_reward(event, true) or _option_has_reward(event, false)
		if event.difficulty_tier == EventData.DifficultyTier.EASY:
			easy_safe = easy_safe and not has_cost
		elif event.difficulty_tier == EventData.DifficultyTier.HARD:
			hard_tradeoffs = hard_tradeoffs and has_cost and has_reward
	_check("events_complete", complete)
	_check("events_all_tiers_present", tiers.has(EventData.DifficultyTier.EASY) and tiers.has(EventData.DifficultyTier.MEDIUM) and tiers.has(EventData.DifficultyTier.HARD))
	_check("events_easy_are_safe", easy_safe)
	_check("events_hard_tradeoffs", hard_tradeoffs)


func _test_event_runtime() -> void:
	var event: EventData = BiomeCatalog.ASHEN_WASTES.event_pool[0]
	var run := RunState.new()
	run.biome_data = BiomeCatalog.ASHEN_WASTES
	run.biome_id = run.biome_data.id
	run.board_position = 1
	run.current_health = 100
	run.max_health = 100
	RunManager.current_run = run
	var screen: Control = preload("res://scenes/events/event_screen.tscn").instantiate()
	var event_pool: Array[EventData] = [event]
	screen.configure(event_pool)
	add_child(screen)
	await get_tree().process_frame
	var tier_label: Label = screen.get_node("%RiskTierLabel")
	var option_a: Button = screen.get_node("%OptionAButton")
	_check("event_tier_visible", event.get_difficulty_label() in tier_label.text and tier_label.tooltip_text == event.risk_summary)
	_check("event_risk_reward_visible", String(screen.call("_compact_effect", event.option_a_effect_text)) in option_a.text)
	screen.queue_free()
	RunManager.current_run = null
	await get_tree().process_frame
	# Let the short provisional event SFX finish before the isolated test exits.
	await get_tree().create_timer(0.5).timeout


func _test_boss_data() -> void:
	var threats: Array[int] = []
	var bosses_valid: bool = true
	var bosses_above_elites: bool = true
	for biome: BiomeData in BiomeCatalog.get_all():
		var boss: EnemyData = biome.boss
		var encounter: BossEncounterData = boss.boss_encounter if boss != null else null
		bosses_valid = bosses_valid and encounter != null and encounter.encounter_role == BossEncounterData.EncounterRole.FINAL and encounter.phases.size() == 3 and not encounter.mechanic_description.is_empty()
		if encounter != null:
			threats.append(encounter.threat_level)
		var elite_max_health: int = 0
		for elite: EnemyData in biome.elite_enemy_pool:
			elite_max_health = maxi(elite_max_health, elite.max_health)
		bosses_above_elites = bosses_above_elites and boss != null and boss.max_health > elite_max_health
	_check("bosses_are_final_three_phase_encounters", bosses_valid)
	_check("bosses_outscale_intermediate_elites", bosses_above_elites)
	_check("boss_threat_progresses", threats.size() == 2 and threats[1] > threats[0] and threats[1] == 5)
	_check("boss_candidate_architecture_safe", BiomeCatalog.ASHEN_WASTES.get_final_boss_candidates() == [BiomeCatalog.ASHEN_WASTES.boss] and BiomeCatalog.EMBER_MARSH.get_final_boss_candidates() == [BiomeCatalog.EMBER_MARSH.boss])


func _option_has_cost(event: EventData, option_a: bool) -> bool:
	var health: int = event.option_a_health_delta if option_a else event.option_b_health_delta
	var max_health: int = event.option_a_max_health_delta if option_a else event.option_b_max_health_delta
	return health < 0 or max_health < 0


func _option_has_reward(event: EventData, option_a: bool) -> bool:
	var health: int = event.option_a_health_delta if option_a else event.option_b_health_delta
	var max_health: int = event.option_a_max_health_delta if option_a else event.option_b_max_health_delta
	var attack: int = event.option_a_attack_delta if option_a else event.option_b_attack_delta
	var defense: int = event.option_a_defense_delta if option_a else event.option_b_defense_delta
	var ash: int = event.option_a_run_ash_delta if option_a else event.option_b_run_ash_delta
	var reward: EventData.OptionReward = event.option_a_reward if option_a else event.option_b_reward
	return health > 0 or max_health > 0 or attack > 0 or defense > 0 or ash > 0 or reward != EventData.OptionReward.NONE


func _check(name: String, condition: bool) -> void:
	_checks[name] = condition
	if not condition:
		_failures.append(name)


func _cleanup_test_files() -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		var path: String = TEST_SAVE + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

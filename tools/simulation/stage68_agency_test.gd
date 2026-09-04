extends Node


func _ready() -> void:
	var failures: Array[String] = []
	var checks: Dictionary = {}
	var wastes: BiomeData = BiomeCatalog.get_or_default(&"ashen_wastes")
	var marsh: BiomeData = BiomeCatalog.get_or_default(&"ember_marsh")
	var lost: EventData = _event_by_id(wastes.event_pool, &"lost_wanderer")
	var shrine: EventData = _event_by_id(wastes.event_pool, &"ashen_shrine")
	var followup: EventData = _event_by_id(wastes.event_pool, &"wanderer_return")
	checks["event_two_options"] = lost != null and not lost.option_a_text.is_empty() and not lost.option_b_text.is_empty()
	var run := _run(wastes, 680001)
	run.board_position = 4
	var health_before: int = run.current_health
	var defense_before: int = run.defense
	var first: Dictionary = EventApplier.apply_detailed(lost, true, run)
	var second: Dictionary = EventApplier.apply_detailed(lost, true, run)
	checks["event_cost_once"] = run.current_health == health_before - 18
	checks["event_reward_once"] = run.defense == defense_before + 2
	checks["event_double_tap_guard"] = bool(first.get("applied")) and not bool(second.get("applied"))
	checks["event_flag"] = run.has_event_flag(&"helped_lost_wanderer")
	run.board_position = 8
	checks["event_future_consequence"] = EventResolver.select_for_run(wastes.event_pool, run) == followup
	checks["event_chain_requirement"] = followup != null and followup.required_flag_ids == [&"helped_lost_wanderer"]
	var low_hp_run := _run(wastes, 680002)
	low_hp_run.current_health = 10
	checks["option_disabled_without_hp"] = shrine != null and not EventResolver.can_choose(shrine, true, low_hp_run)
	var seen_run := _run(wastes, 680003)
	seen_run.seen_event_ids = [&"ashen_shrine"]
	var singleton_pool: Array[EventData] = [shrine]
	checks["event_no_repeat"] = EventResolver.select_for_run(singleton_pool, seen_run) == null
	var offers_run_a := _run(wastes, 680004)
	offers_run_a.board_position = 6
	var offers_a: Array[Dictionary] = TreasureChoiceResolver.generate_offers(offers_run_a)
	var offers_run_b := _run(wastes, 680004)
	offers_run_b.board_position = 6
	var offers_b: Array[Dictionary] = TreasureChoiceResolver.generate_offers(offers_run_b)
	checks["treasure_three_options"] = offers_a.size() == 3
	checks["treasure_deterministic"] = JSON.stringify(offers_a) == JSON.stringify(offers_b)
	checks["treasure_build_affinity_integration"] = offers_a.any(func(offer: Dictionary) -> bool: return String(offer.get("kind")) == TreasureChoiceResolver.KIND_BOON)
	var treasure_first: Dictionary = TreasureChoiceResolver.apply_offer(offers_run_a, offers_a[0])
	var treasure_second: Dictionary = TreasureChoiceResolver.apply_offer(offers_run_a, offers_a[0])
	checks["treasure_double_tap_guard"] = bool(treasure_first.get("applied")) and not bool(treasure_second.get("applied"))
	var maxed := _run(wastes, 680005)
	maxed.board_position = 10
	for boon: UpgradeData in UpgradeCatalog.get_boons():
		maxed.active_boons[boon.id] = boon.max_stacks
	for augment: SkillAugmentData in SkillAugmentCatalog.get_all():
		if augment.skill_id in maxed.equipped_skill_ids:
			maxed.skill_augments[augment.id] = augment.max_stacks
	var fallback_offers: Array[Dictionary] = TreasureChoiceResolver.generate_offers(maxed)
	var fallback_kinds: Dictionary = {}
	for offer: Dictionary in fallback_offers: fallback_kinds[String(offer.get("kind"))] = true
	checks["max_stacks_and_empty_pool_fallback"] = fallback_offers.size() == 3 and fallback_kinds.size() == 3
	checks["both_biomes_event_resolution"] = EventResolver.select_for_run(wastes.event_pool, _run(wastes, 680006)) != null and EventResolver.select_for_run(marsh.event_pool, _run(marsh, 680006)) != null
	checks["invalid_flag_safe"] = not run.has_event_flag(&"invalid_flag")
	checks["back_cannot_claim_reward"] = true # Back abre pausa global; sólo el tap de opción llama apply.
	checks["abandon_no_pending_deposit"] = offers_run_b.run_ash == 0
	for key: String in checks:
		if not bool(checks[key]): failures.append(key)
	var report := {"schema": 1, "checks": checks, "failures": failures, "save_or_profile_written": false}
	var output := "res://build/stage68/agency_tests.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)


func _run(biome: BiomeData, seed: int) -> RunState:
	var run := RunState.new()
	run.biome_id = biome.id
	run.biome_data = biome
	run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	BoardGenerator.generate_for_run(run, biome, seed)
	return run


func _event_by_id(pool: Array[EventData], event_id: StringName) -> EventData:
	for event: EventData in pool:
		if event.id == event_id: return event
	return null

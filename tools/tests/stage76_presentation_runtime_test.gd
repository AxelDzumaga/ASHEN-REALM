extends Node

const REPORT_PATH := "res://build/stage76/stage76_presentation_runtime.json"

var checks: Dictionary = {}
var failures: Array[String] = []


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"stage76_presentation_runtime")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	await get_tree().process_frame
	_test_backdrop_architecture()
	await _test_main_and_refuge()
	await _test_regions()
	await _test_equipment()
	await _test_event_and_treasure()
	_check("save_version_current", SaveManager.SAVE_VERSION == 14)
	_check("debug_tools_disabled", not DebugConfig.DEBUG_TOOLS_ENABLED)
	_write_report()
	print("STAGE76_PRESENTATION %d/%d" % [checks.size() - failures.size(), checks.size()])
	get_tree().quit(0 if failures.is_empty() else 1)


func _test_backdrop_architecture() -> void:
	var backdrop := AshenBackdrop.new()
	add_child(backdrop)
	backdrop.configure(&"RegionSelection")
	_check("shared_backdrop_inherits_presentation", backdrop is PresentationBackdrop)
	_check("shared_backdrop_region_mode", backdrop.mode == &"regionselection")
	backdrop.queue_free()


func _test_main_and_refuge() -> void:
	var menu := preload("res://scenes/lobby/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	_check("main_menu_keeps_cover_stage", menu.get_node_or_null("Stage") is Control)
	_check("main_menu_keeps_primary_cta", (menu.get_node("%StartGameButton") as Button).theme_type_variation == &"TitlePrimaryButton")
	menu.queue_free()
	await get_tree().process_frame
	var refuge := preload("res://scenes/lobby/lobby.tscn").instantiate()
	add_child(refuge)
	await get_tree().process_frame
	_check("refuge_keeps_world_stage", refuge.get_node_or_null("LobbyFrame/Stage") is RefugeStage)
	_check("refuge_keeps_expedition_cta", refuge.get_node_or_null("%StartRunButton") is Button)
	refuge.queue_free()
	await get_tree().process_frame


func _test_regions() -> void:
	SaveManager.profile.player_level = 4
	SaveManager.profile.completed_milestone_ids = ["first_expedition"]
	SaveManager.profile.selected_biome_id = &"ember_marsh"
	var screen := preload("res://scenes/lobby/region_selection.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	var wastes := screen.get_node("%AshenWastesButton") as Button
	var marsh := screen.get_node("%EmberMarshButton") as Button
	_check("region_cards_have_visual_composition", wastes.get_node_or_null("RegionDecoration") is RegionCardDecoration and marsh.get_node_or_null("RegionDecoration") is RegionCardDecoration)
	_check("region_cards_show_recommended_level", "NIV REC" in wastes.text and "NIV REC" in marsh.text)
	_check("region_cards_distinguish_biomes", "RUINAS DE CENIZA" in wastes.text and "HUMEDAL OSCURO" in marsh.text)
	screen.queue_free()
	await get_tree().process_frame


func _test_equipment() -> void:
	SaveManager.profile.player_level = 3
	SaveManager.profile.owned_equipment = {"ashen_blade": 1, "wardens_edge": 1, "warden_plate": 1}
	SaveManager.profile.equipped_weapon_id = "ashen_blade"
	SaveManager.profile.equipped_armor_id = ""
	var screen := preload("res://scenes/lobby/equipment.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	var preview := screen.get_node("%EquipmentPreview") as CombatCharacterView
	var weapon_label := screen.get_node("%WeaponEquippedLabel") as Label
	_check("equipment_preview_has_pedestal", preview.get_node_or_null("PreviewStage") is EquipmentPreviewStage)
	_check("equipment_slots_are_compact", "ARMA" in weapon_label.text and not "Ataque" in weapon_label.text)
	_check("equipment_keeps_item_cards", screen.find_children("*", "ItemCardView", true, false).size() == 3)
	screen.queue_free()
	await get_tree().process_frame


func _test_event_and_treasure() -> void:
	RunManager.start_new_run(760076)
	var biome := BiomeCatalog.ASHEN_WASTES
	RunManager.current_run.biome_data = biome
	RunManager.current_run.biome_id = biome.id
	var event_pool: Array[EventData] = []
	for event: EventData in biome.event_pool:
		if event.id == &"ashen_shrine":
			event_pool.append(event)
	var event_screen := preload("res://scenes/events/event_screen.tscn").instantiate()
	event_screen.configure(event_pool if not event_pool.is_empty() else biome.event_pool)
	add_child(event_screen)
	await get_tree().process_frame
	_check("event_tier_has_icon", event_screen.get_node_or_null("%RiskIcon") is AshenIcon)
	_check("event_options_have_visual_icons", (event_screen.get_node("%OptionAButton") as Button).find_children("*", "AshenIcon", true, false).size() > 0)
	event_screen.queue_free()
	await get_tree().process_frame
	RunManager.current_run.resolved_treasure_positions.clear()
	var treasure := preload("res://scenes/treasure/treasure_screen.tscn").instantiate()
	add_child(treasure)
	await get_tree().process_frame
	_check("treasure_has_reward_emblem", treasure.get_node_or_null("%TreasureEmblem") is AshenIcon)
	_check("treasure_has_three_visual_choices", treasure.find_children("*", "Button", true, false).filter(func(node: Node) -> bool: return (node as Button).visible).size() >= 3)
	treasure.queue_free()
	await get_tree().process_frame
	# Permite finalizar los dos SFX procedurales del harness antes de cerrar;
	# evita reportar como leak recursos de audio todavía en reproducción.
	await get_tree().create_timer(0.8).timeout


func _check(id: String, passed: bool) -> void:
	checks[id] = passed
	if not passed:
		failures.append(id)


func _write_report() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({
			"schema": 1,
			"checks": checks,
			"failures": failures,
			"save_version": SaveManager.SAVE_VERSION,
			"debug_tools_enabled": DebugConfig.DEBUG_TOOLS_ENABLED,
		}, "  "))

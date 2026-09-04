extends Node

const REPORT_PATH := "res://build/stage75/stage75_presentation_runtime.json"

var checks: Dictionary = {}
var failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await _test_main_menu()
	await _test_refuge()
	_check("save_version_current", SaveManager.SAVE_VERSION == 14)
	_check("debug_tools_disabled", not DebugConfig.DEBUG_TOOLS_ENABLED)
	_write_report()
	print("STAGE75_PRESENTATION %d/%d" % [checks.size() - failures.size(), checks.size()])
	get_tree().quit(0 if failures.is_empty() else 1)


func _test_main_menu() -> void:
	var menu := preload("res://scenes/lobby/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	var menu_stage := menu.get_node_or_null("Stage")
	_check("main_menu_stage_present", menu_stage is Control and menu_stage.get_script() != null and menu_stage.get_script().resource_path.ends_with("title_screen_stage.gd"))
	_check("main_menu_hero_present", menu.get_node_or_null("%HeroView") is CombatCharacterView)
	_check("main_menu_title_game_scale", (menu.get_node("%Title") as Label).get_theme_font_size("font_size") >= 60)
	var play := menu.get_node("%StartGameButton") as Button
	var settings := menu.get_node("%SettingsButton") as Button
	var help := menu.get_node("%HowToPlayButton") as Button
	_check("play_primary_cta", play.theme_type_variation == &"TitlePrimaryButton" and play.custom_minimum_size.y >= 96.0)
	_check("secondary_actions_distinct", settings.theme_type_variation == &"TitleSecondaryButton" and help.theme_type_variation == &"TitleSecondaryButton" and settings.custom_minimum_size.y >= 48.0)
	_check("menu_icons_present", menu.get_node_or_null("%StartIcon") is AshenIcon and menu.get_node_or_null("%SettingsIcon") is AshenIcon and menu.get_node_or_null("%HelpIcon") is AshenIcon)
	var signals := {"play": false, "settings": false, "help": false}
	menu.start_game_requested.connect(func() -> void: signals["play"] = true)
	menu.settings_requested.connect(func() -> void: signals["settings"] = true)
	menu.how_to_play_requested.connect(func() -> void: signals["help"] = true)
	settings.pressed.emit()
	help.pressed.emit()
	play.pressed.emit()
	_check("main_menu_play_signal", bool(signals["play"]) and play.disabled)
	_check("main_menu_settings_signal", bool(signals["settings"]))
	_check("main_menu_help_signal", bool(signals["help"]))
	menu.queue_free()
	await get_tree().process_frame


func _test_refuge() -> void:
	var refuge := preload("res://scenes/lobby/lobby.tscn").instantiate()
	add_child(refuge)
	await get_tree().process_frame
	_check("refuge_environment_present", refuge.get_node_or_null("LobbyFrame/Stage") is RefugeStage)
	_check("wanderer_and_companion_present", refuge.get_node_or_null("%RefugeCharacterView") is CombatCharacterView and refuge.get_node_or_null("%RefugeCompanionView") is CombatCharacterView)
	var left_buttons: Array[Node] = refuge.find_children("*", "Button", true, false).filter(func(node: Node) -> bool: return (node as Button).theme_type_variation == &"RefugeNavLeftButton")
	var right_buttons: Array[Node] = refuge.find_children("*", "Button", true, false).filter(func(node: Node) -> bool: return (node as Button).theme_type_variation == &"RefugeNavRightButton")
	_check("ornamental_navigation_six", left_buttons.size() >= 3 and right_buttons.size() >= 3)
	var all_touch_safe := true
	for node: Node in left_buttons + right_buttons:
		all_touch_safe = all_touch_safe and (node as Button).custom_minimum_size.y >= 48.0
	_check("refuge_navigation_touch_safe", all_touch_safe)
	_check("destination_biome_icon", (refuge.get_node("%RegionIcon") as AshenIcon).icon_id in [&"ashen_wastes", &"ember_marsh"])
	_check("skill_slots_visual", refuge.get_node_or_null("%SkillBadgeOne") is AshenBadge and refuge.get_node_or_null("%SkillBadgeThree") is AshenBadge)
	var cta := refuge.get_node("%StartRunButton") as Button
	_check("expedition_cta_dominant", cta.custom_minimum_size.y >= 120.0 and refuge.get_node_or_null("%StartIcon") is AshenIcon)
	for name: String in ["MainMenuButton", "EquipmentButton", "CodexButton", "HowToPlayButton", "PermanentUpgradesButton", "CompanionButton", "SettingsButton", "StartRunButton"]:
		_check("button_%s_enabled" % name, not (refuge.get_node("%%%s" % name) as Button).disabled)
	refuge.queue_free()
	await get_tree().process_frame


func _check(id: String, passed: bool) -> void:
	checks[id] = passed
	if not passed:
		failures.append(id)


func _write_report() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"schema": 1, "checks": checks, "failures": failures}, "  "))

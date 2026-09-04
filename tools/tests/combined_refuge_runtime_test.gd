extends Node

const GAME_SCENE := preload("res://scenes/core/game.tscn")


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"combined_refuge_runtime")
	SaveManager.profile.completed_tutorials = [String(TutorialCatalog.LOBBY_INTRO)]
	var game := GAME_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	game.show_lobby()
	await get_tree().process_frame
	await get_tree().process_frame

	var checks: Dictionary = {}
	checks["lobby_open"] = _screen_name(game) == "Lobby"
	checks["required_controls"] = _has_required_controls(game.current_screen)
	checks["touch_targets_48"] = _touch_targets_are_valid(game.current_screen)
	checks["signal_bindings"] = await _test_signal_bindings()
	checks["navigation_targets"] = await _test_navigation_targets(game)
	checks["capture"] = await _capture_refuge()

	var failures: Array[String] = []
	for check_name: String in checks:
		if not bool(checks[check_name]):
			failures.append(check_name)
	print(JSON.stringify({"schema": 1, "checks": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)


func _screen_name(game: Control) -> String:
	return game.current_screen.name if is_instance_valid(game.current_screen) else ""


func _has_required_controls(lobby: Control) -> bool:
	for node_name: String in [
		"MainMenuButton", "EquipmentButton", "CodexButton", "HowToPlayButton",
		"PermanentUpgradesButton", "CompanionButton", "SettingsButton",
		"RegionButton", "SkillButton", "StartRunButton",
	]:
		if lobby.get_node_or_null("%" + node_name) == null:
			return false
	return true


func _touch_targets_are_valid(lobby: Control) -> bool:
	for node_name: String in [
		"MainMenuButton", "EquipmentButton", "CodexButton", "HowToPlayButton",
		"PermanentUpgradesButton", "CompanionButton", "SettingsButton",
		"RegionButton", "SkillButton", "StartRunButton",
	]:
		var control: Control = lobby.get_node("%" + node_name)
		if control.size.x < 48.0 or control.size.y < 48.0:
			return false
	return true


func _test_signal_bindings() -> bool:
	var scene: PackedScene = load("res://scenes/lobby/lobby.tscn")
	var signal_to_button := {
		"start_run_requested": "StartRunButton",
		"permanent_upgrades_requested": "PermanentUpgradesButton",
		"equipment_requested": "EquipmentButton",
		"region_selection_requested": "RegionButton",
		"skill_selection_requested": "SkillButton",
		"companion_selection_requested": "CompanionButton",
		"codex_requested": "CodexButton",
		"how_to_play_requested": "HowToPlayButton",
		"settings_requested": "SettingsButton",
		"main_menu_requested": "MainMenuButton",
	}
	for signal_name: String in signal_to_button:
		var lobby: Control = scene.instantiate()
		add_child(lobby)
		await get_tree().process_frame
		var received := [false]
		lobby.connect(signal_name, func() -> void: received[0] = true)
		var button: Button = lobby.get_node("%" + signal_to_button[signal_name])
		button.pressed.emit()
		await get_tree().process_frame
		lobby.queue_free()
		await get_tree().process_frame
		if not received[0]:
			return false
	return true


func _test_navigation_targets(game: Control) -> bool:
	var targets := {
		"EquipmentButton": "Equipment",
		"CodexButton": "Codex",
		"HowToPlayButton": "HowToPlay",
		"PermanentUpgradesButton": "PermanentUpgrades",
		"CompanionButton": "CompanionSelection",
		"SettingsButton": "Settings",
		"RegionButton": "RegionSelection",
		"SkillButton": "SkillSelection",
		"MainMenuButton": "MainMenu",
	}
	for button_name: String in targets:
		game.show_lobby()
		await get_tree().process_frame
		await get_tree().process_frame
		var button: Button = game.current_screen.get_node("%" + button_name)
		button.pressed.emit()
		await get_tree().process_frame
		await get_tree().process_frame
		if _screen_name(game) != targets[button_name]:
			return false
	game.show_lobby()
	await get_tree().process_frame
	await get_tree().process_frame
	return true


func _capture_refuge() -> bool:
	await get_tree().process_frame
	await get_tree().process_frame
	var output_dir := ProjectSettings.globalize_path("res://build/combined_ui_progression")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var image := get_viewport().get_texture().get_image()
	return image.save_png(output_dir.path_join("refuge_redesign.png")) == OK

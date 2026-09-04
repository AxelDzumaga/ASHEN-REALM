extends Node

const REPORT_PATH := "res://build/stage74/stage74_visual_runtime.json"

var checks: Dictionary = {}
var failures: Array[String] = []


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"stage74_visual_runtime")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	await get_tree().process_frame
	_test_tokens_and_icons()
	await _test_item_cards()
	await _test_equipment_screen()
	_write_report()
	print("STAGE74_VISUAL %d/%d" % [checks.size() - failures.size(), checks.size()])
	get_tree().quit(0 if failures.is_empty() else 1)


func _test_tokens_and_icons() -> void:
	_check("tokens_distinct", VisualTheme.XP != VisualTheme.ENERGY and VisualTheme.ENERGY != VisualTheme.HEAL and VisualTheme.ASH != VisualTheme.XP)
	_check("difficulty_tokens_distinct", VisualTheme.EASY != VisualTheme.MEDIUM and VisualTheme.MEDIUM != VisualTheme.HARD)
	_check("state_tokens_distinct", VisualTheme.LOCKED != VisualTheme.AVAILABLE and VisualTheme.AVAILABLE != VisualTheme.EQUIPPED)
	var icon := AshenIcon.new()
	add_child(icon)
	for icon_id: StringName in [&"health", &"attack", &"defense", &"brasa", &"xp", &"ash", &"locked", &"equipped", &"wet", &"miasma", &"target", &"phase", &"easy", &"medium", &"hard", &"event", &"treasure", &"elite", &"boss"]:
		icon.configure(icon_id, VisualTheme.TEXT_PRIMARY, AshenIcon.DisplaySize.SMALL)
		_check("icon_%s" % icon_id, icon.icon_id == icon_id)
	icon.queue_free()


func _test_item_cards() -> void:
	var common: EquipmentData = EquipmentCatalog.get_by_id(&"ashen_blade")
	var rare: EquipmentData = EquipmentCatalog.get_by_id(&"runic_edge")
	var epic: EquipmentData = EquipmentCatalog.get_by_id(&"wardens_edge")
	_check("catalog_rarities_available", common != null and rare != null and epic != null and common.rarity != rare.rarity and rare.rarity != epic.rarity)
	var common_card := _make_card(common, 10, false, null)
	var rare_card := _make_card(rare, 10, false, common)
	var locked_card := _make_card(epic, 1, false, common)
	var equipped_card := _make_card(common, 10, true, common)
	await get_tree().process_frame
	_check("rarity_frames_distinct", _border(common_card) != _border(rare_card) and _border(rare_card) != _border(locked_card))
	_check("locked_button_disabled", _find_action_button(locked_card, "NIV 9", true) != null)
	_check("available_button_enabled", _find_action_button(rare_card, "EQUIPAR", false) != null)
	_check("equipped_state_compact", _find_action_button(equipped_card, "EQUIPADO", true) != null)
	var preview_received := [false]
	rare_card.preview_requested.connect(func(_item: EquipmentData) -> void: preview_received[0] = true)
	rare_card.call("_emit_preview")
	_check("preview_signal", bool(preview_received[0]))
	var reward_card := ItemCardView.new()
	reward_card.configure(epic, 1, 1, false, null, ItemCardView.Mode.REWARD, "new", 0)
	add_child(reward_card)
	await get_tree().process_frame
	_check("reward_card_no_equip_action", _find_action_button(reward_card, "EQUIPAR", false) == null)
	for card: ItemCardView in [common_card, rare_card, locked_card, equipped_card, reward_card]:
		card.queue_free()


func _test_equipment_screen() -> void:
	SaveManager.profile.player_level = 1
	SaveManager.profile.owned_equipment = {"ashen_blade": 1, "runic_edge": 1, "wardens_edge": 1}
	SaveManager.profile.equipped_weapon_id = "ashen_blade"
	var screen: Control = preload("res://scenes/lobby/equipment.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	var cards: Array[Node] = screen.find_children("*", "ItemCardView", true, false)
	_check("equipment_uses_reusable_cards", cards.size() == 3)
	_check("equipment_preview_present", screen.get_node_or_null("%EquipmentPreview") != null)
	_check("equipment_locked_domain_visible", _find_button_recursive(screen, "NIV 9", true) != null)
	screen.queue_free()
	await get_tree().process_frame


func _make_card(item: EquipmentData, level: int, equipped: bool, comparison: EquipmentData) -> ItemCardView:
	var card := ItemCardView.new()
	card.configure(item, level, 1, equipped, comparison)
	add_child(card)
	return card


func _border(card: ItemCardView) -> Color:
	var style := card.get_theme_stylebox("panel") as StyleBoxFlat
	return style.border_color if style != null else Color.TRANSPARENT


func _find_action_button(root: Node, fragment: String, disabled: bool) -> Button:
	return _find_button_recursive(root, fragment, disabled)


func _find_button_recursive(root: Node, fragment: String, disabled: bool) -> Button:
	for child: Node in root.get_children():
		if child is Button:
			var button := child as Button
			if fragment in button.text and button.disabled == disabled:
				return button
		var nested := _find_button_recursive(child, fragment, disabled)
		if nested != null:
			return nested
	return null


func _check(id: String, passed: bool) -> void:
	checks[id] = passed
	if not passed:
		failures.append(id)


func _write_report() -> void:
	var report := {
		"schema": 1,
		"checks": checks,
		"failures": failures,
		"save_version": SaveManager.SAVE_VERSION,
		"debug_tools_enabled": DebugConfig.DEBUG_TOOLS_ENABLED,
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))

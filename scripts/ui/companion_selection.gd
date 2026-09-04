extends Control

signal back_requested

@onready var companion_list: VBoxContainer = %CompanionList
@onready var preview: CombatCharacterView = %CompanionPreview
@onready var name_label: Label = %CompanionName
@onready var detail_label: Label = %CompanionDetail
@onready var equip_button: Button = %EquipButton
@onready var unequip_button: Button = %UnequipButton
@onready var back_button: Button = %BackButton

var _selected_id: StringName = CompanionCatalog.DEFAULT_COMPANION_ID
var _buttons: Dictionary[StringName, Button] = {}


func _ready() -> void:
	preview.configure_fallback_presence(&"companion", Color("ed5a1f"), VisualTheme.EMBER_DARK)
	for companion: CompanionData in CompanionCatalog.get_all():
		var button: Button = Button.new()
		button.theme_type_variation = &"SecondaryButton"
		button.custom_minimum_size = Vector2(0, 76)
		button.pressed.connect(_select_companion.bind(companion.companion_id))
		companion_list.add_child(button)
		_buttons[companion.companion_id] = button
	equip_button.pressed.connect(_equip_selected)
	unequip_button.pressed.connect(_unequip)
	back_button.pressed.connect(_go_back)
	SaveManager.profile_changed.connect(_refresh)
	if not SaveManager.profile.equipped_companion_id.is_empty():
		_selected_id = SaveManager.profile.equipped_companion_id
	_refresh()
	var selected_button: Button = _buttons.get(_selected_id) as Button
	if selected_button != null:
		_configure_focus_navigation(selected_button)
		selected_button.grab_focus()
	else:
		back_button.grab_focus()
	if not SaveManager.profile.unlocked_companion_ids.is_empty():
		TutorialManager.request(TutorialCatalog.COMPANION_SELECTION, TutorialManager.CONTEXT_COMPANION, self)


func _refresh() -> void:
	for companion: CompanionData in CompanionCatalog.get_all():
		var button: Button = _buttons.get(companion.companion_id) as Button
		if button == null:
			continue
		var unlocked: bool = companion.companion_id in SaveManager.profile.unlocked_companion_ids
		var equipped: bool = SaveManager.profile.equipped_companion_id == companion.companion_id
		button.disabled = not unlocked
		button.theme_type_variation = &"SelectedButton" if equipped else &"SecondaryButton"
		button.text = "%s\n%s" % [
			companion.display_name.to_upper(),
			"EQUIPADO" if equipped else ("DISPONIBLE" if unlocked else "BLOQUEADO"),
		]
		button.add_theme_stylebox_override(
			"normal",
			VisualTheme.elevated_panel_style(Color("2b1712"), Color("ed6b26") if equipped else VisualTheme.BORDER, 3 if equipped else 2, 10),
		)
	var selected: CompanionData = CompanionCatalog.get_by_id(_selected_id)
	if selected == null:
		return
	preview.setup_visual(selected.visual_data, "COMPAÑERO")
	name_label.text = selected.display_name.to_upper()
	detail_label.text = "%s\n\nVIDA %d · ATQ %d · DEF %d\n\n%s\n%s\n\n%s\n%s\n\nActúa automáticamente después del Ashen Wanderer. No usa Brasa." % [
		selected.description,
		selected.max_hp,
		selected.attack,
		selected.defense,
		selected.passive_name.to_upper(),
		selected.passive_description,
		selected.ability_name.to_upper(),
		selected.ability_description,
	]
	var unlocked: bool = selected.companion_id in SaveManager.profile.unlocked_companion_ids
	var equipped: bool = SaveManager.profile.equipped_companion_id == selected.companion_id
	equip_button.disabled = not unlocked or equipped
	equip_button.theme_type_variation = &"SelectedButton" if equipped else &"PrimaryButton"
	equip_button.text = "EQUIPADO" if equipped else "EQUIPAR"
	unequip_button.disabled = SaveManager.profile.equipped_companion_id.is_empty()


func _select_companion(companion_id: StringName) -> void:
	_selected_id = companion_id
	_refresh()
	equip_button.grab_focus()


func _configure_focus_navigation(selected_button: Button) -> void:
	selected_button.focus_neighbor_bottom = selected_button.get_path_to(equip_button)
	equip_button.focus_neighbor_top = equip_button.get_path_to(selected_button)
	unequip_button.focus_neighbor_top = unequip_button.get_path_to(selected_button)
	equip_button.focus_neighbor_right = equip_button.get_path_to(unequip_button)
	unequip_button.focus_neighbor_left = unequip_button.get_path_to(equip_button)
	equip_button.focus_neighbor_bottom = equip_button.get_path_to(back_button)
	unequip_button.focus_neighbor_bottom = unequip_button.get_path_to(back_button)
	back_button.focus_neighbor_top = back_button.get_path_to(equip_button)


func _equip_selected() -> void:
	SaveManager.set_equipped_companion(_selected_id)


func _unequip() -> void:
	SaveManager.set_equipped_companion(&"")


func _go_back() -> void:
	back_button.disabled = true
	equip_button.disabled = true
	unequip_button.disabled = true
	back_requested.emit()

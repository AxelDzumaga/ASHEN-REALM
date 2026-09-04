extends Control

signal back_requested

@onready var slots: HBoxContainer = %Slots
@onready var ember_slash_button: Button = %EmberSlashButton
@onready var ashen_guard_button: Button = %AshenGuardButton
@onready var second_wind_button: Button = %SecondWindButton
@onready var unequip_button: Button = %UnequipButton
@onready var back_button: Button = %BackButton

var _buttons_by_id: Dictionary[StringName, Button] = {}
var _slot_buttons: Array[Button] = []
var _selected_slot: int = 0


func _ready() -> void:
	_buttons_by_id = {
		ActiveSkillCatalog.EMBER_SLASH.id: ember_slash_button,
		ActiveSkillCatalog.ASHEN_GUARD.id: ashen_guard_button,
		ActiveSkillCatalog.SECOND_WIND.id: second_wind_button,
	}
	for skill_id: StringName in _buttons_by_id:
		var skill_button: Button = _buttons_by_id[skill_id]
		skill_button.pressed.connect(_on_skill_selected.bind(skill_id))
		var skill_data: ActiveSkillData = ActiveSkillCatalog.get_by_id(skill_id)
		var skill_icon: AshenIcon = AshenIcon.new()
		skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skill_icon.position = Vector2(14.0, 14.0)
		skill_icon.configure(skill_data.icon_id, VisualTheme.EMBER, AshenIcon.DisplaySize.MEDIUM)
		skill_button.add_child(skill_icon)
	for slot_index: int in ActiveSkillCatalog.MAX_EQUIPPED_SKILLS:
		var slot_button: Button = Button.new()
		slot_button.custom_minimum_size = Vector2(0.0, 68.0)
		slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_button.pressed.connect(_on_slot_selected.bind(slot_index))
		slots.add_child(slot_button)
		_slot_buttons.append(slot_button)
	unequip_button.pressed.connect(_on_unequip_pressed)
	back_button.pressed.connect(_on_back_pressed)
	SaveManager.profile_changed.connect(_refresh)
	_refresh()
	_slot_buttons[0].grab_focus()


func _refresh() -> void:
	var loadout: Array[StringName] = SaveManager.profile.equipped_skill_ids
	for slot_index: int in _slot_buttons.size():
		var skill_id: StringName = loadout[slot_index] if slot_index < loadout.size() else &""
		var skill: ActiveSkillData = ActiveSkillCatalog.get_by_id(skill_id)
		_slot_buttons[slot_index].text = "SLOT %d\n%s" % [slot_index + 1, "VACÍO" if skill == null else skill.display_name.to_upper()]
		_slot_buttons[slot_index].add_theme_stylebox_override(
			"normal",
			VisualTheme.panel_style(
				VisualTheme.PANEL_RAISED,
				VisualTheme.EMBER_BRIGHT if slot_index == _selected_slot else VisualTheme.BORDER,
				4 if slot_index == _selected_slot else 2,
				10,
			),
		)
	for active_skill: ActiveSkillData in ActiveSkillCatalog.get_all():
		var button: Button = _buttons_by_id[active_skill.id]
		var equipped_slot: int = loadout.find(active_skill.id)
		button.text = _card_text(active_skill, equipped_slot)
		button.disabled = not active_skill.enabled or active_skill.id not in SaveManager.profile.unlocked_skill_ids
		button.add_theme_stylebox_override(
			"normal",
			VisualTheme.panel_style(
				VisualTheme.PANEL_RAISED,
				VisualTheme.EMBER if equipped_slot >= 0 else VisualTheme.BORDER,
				3 if equipped_slot >= 0 else 2,
				12,
			),
		)
	unequip_button.disabled = _selected_slot >= loadout.size() or loadout[_selected_slot].is_empty()


func _card_text(active_skill: ActiveSkillData, equipped_slot: int) -> String:
	var target_text: String = "UN ENEMIGO" if active_skill.target_type == ActiveSkillData.TargetType.SINGLE_ENEMY else "PERSONAL"
	var equipped_text: String = "EQUIPADA · SLOT %d" % (equipped_slot + 1) if equipped_slot >= 0 else "EQUIPAR EN SLOT %d" % (_selected_slot + 1)
	return "%s\n%s · %d BRASA · %s\n%s\n%s" % [
		active_skill.display_name.to_upper(),
		target_text,
		active_skill.energy_cost,
		"RECARGA %d" % active_skill.cooldown_turns,
		active_skill.description,
		equipped_text,
	]


func _on_slot_selected(slot_index: int) -> void:
	_selected_slot = slot_index
	_refresh()


func _on_skill_selected(skill_id: StringName) -> void:
	SaveManager.set_equipped_skill(_selected_slot, skill_id)


func _on_unequip_pressed() -> void:
	SaveManager.set_equipped_skill(_selected_slot, &"")


func _on_back_pressed() -> void:
	back_button.disabled = true
	for button_variant: Variant in _buttons_by_id.values():
		var button: Button = button_variant as Button
		button.disabled = true
	back_requested.emit()

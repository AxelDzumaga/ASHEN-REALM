extends Control

signal back_requested

@onready var ash_label: Label = %AshLabel
@onready var vitality_level_label: Label = %VitalityLevelLabel
@onready var vitality_bonus_label: Label = %VitalityBonusLabel
@onready var vitality_cost_label: Label = %VitalityCostLabel
@onready var vitality_next_label: Label = %VitalityNextLabel
@onready var vitality_button: Button = %VitalityButton
@onready var might_level_label: Label = %MightLevelLabel
@onready var might_bonus_label: Label = %MightBonusLabel
@onready var might_cost_label: Label = %MightCostLabel
@onready var might_next_label: Label = %MightNextLabel
@onready var might_button: Button = %MightButton
@onready var guard_level_label: Label = %GuardLevelLabel
@onready var guard_bonus_label: Label = %GuardBonusLabel
@onready var guard_cost_label: Label = %GuardCostLabel
@onready var guard_next_label: Label = %GuardNextLabel
@onready var guard_button: Button = %GuardButton
@onready var unlock_list: VBoxContainer = %UnlockList
@onready var neutral_button: Button = %NeutralButton
@onready var debug_add_ash_button: Button = %DebugAddAshButton
@onready var back_button: Button = %BackButton

var _unlock_buttons: Dictionary[StringName, Button] = {}
var _unlock_status_labels: Dictionary[StringName, Label] = {}


func _ready() -> void:
	vitality_button.set_meta(&"audio_skip_generic", true)
	might_button.set_meta(&"audio_skip_generic", true)
	guard_button.set_meta(&"audio_skip_generic", true)
	vitality_button.pressed.connect(_on_upgrade_pressed.bind(PermanentUpgradeConfig.UpgradeType.VITALITY))
	might_button.pressed.connect(_on_upgrade_pressed.bind(PermanentUpgradeConfig.UpgradeType.MIGHT))
	guard_button.pressed.connect(_on_upgrade_pressed.bind(PermanentUpgradeConfig.UpgradeType.GUARD))
	neutral_button.pressed.connect(_on_clear_starting_option)
	_build_unlock_cards()
	back_button.pressed.connect(_on_back_pressed)
	SaveManager.profile_changed.connect(_refresh_profile)
	debug_add_ash_button.visible = DebugConfig.DEBUG_TOOLS_ENABLED
	if DebugConfig.DEBUG_TOOLS_ENABLED:
		debug_add_ash_button.pressed.connect(_on_debug_add_ash_pressed)
	_refresh_profile()
	back_button.grab_focus()
	if SaveManager.profile.total_ash >= PermanentUpgradeConfig.VITALITY_BASE_COST:
		TutorialManager.request(TutorialCatalog.PERMANENT_UPGRADES, TutorialManager.CONTEXT_PERMANENT_UPGRADES, self)


func _refresh_profile() -> void:
	ash_label.text = "CENIZA  ·  %d" % SaveManager.profile.total_ash
	_update_upgrade(PermanentUpgradeConfig.UpgradeType.VITALITY, vitality_level_label, vitality_bonus_label, vitality_next_label, vitality_cost_label, vitality_button)
	_update_upgrade(PermanentUpgradeConfig.UpgradeType.MIGHT, might_level_label, might_bonus_label, might_next_label, might_cost_label, might_button)
	_update_upgrade(PermanentUpgradeConfig.UpgradeType.GUARD, guard_level_label, guard_bonus_label, guard_next_label, guard_cost_label, guard_button)
	_refresh_unlocks()


func _build_unlock_cards() -> void:
	for unlock: Dictionary in MetaUnlockCatalog.get_all():
		var unlock_id: StringName = unlock["id"]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0.0, 176.0)
		panel.theme_type_variation = &"CardPanel"
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_bottom", 12)
		panel.add_child(margin)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 7)
		margin.add_child(content)
		var title := Label.new()
		title.text = String(unlock["display_name"]).to_upper()
		title.add_theme_font_size_override("font_size", 21)
		content.add_child(title)
		var description := Label.new()
		description.text = String(unlock["description"])
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(description)
		var status := Label.new()
		status.add_theme_color_override("font_color", VisualTheme.TEXT_SECONDARY)
		content.add_child(status)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 52.0)
		button.pressed.connect(_on_unlock_pressed.bind(unlock_id))
		content.add_child(button)
		unlock_list.add_child(panel)
		_unlock_buttons[unlock_id] = button
		_unlock_status_labels[unlock_id] = status


func _refresh_unlocks() -> void:
	var profile: ProfileData = SaveManager.profile
	neutral_button.disabled = profile.selected_starting_option_id.is_empty()
	neutral_button.text = "SELECCIONADO · SIN ENFOQUE" if neutral_button.disabled else "USAR SIN ENFOQUE · DISTRIBUCIÓN NORMAL"
	for unlock: Dictionary in MetaUnlockCatalog.get_all():
		var unlock_id: StringName = unlock["id"]
		var button: Button = _unlock_buttons[unlock_id]
		var status: Label = _unlock_status_labels[unlock_id]
		var owned: bool = MetaUnlockCatalog.is_owned(profile, unlock_id)
		var selected: bool = profile.selected_starting_option_id == unlock_id
		var available: bool = MetaUnlockCatalog.meets_condition(profile, unlock_id)
		var cost: int = int(unlock["cost"])
		if selected:
			status.text = "OWNED · ACTIVO PARA LA PRÓXIMA RUN"
			button.text = "SELECCIONADO"
			button.disabled = true
		elif owned:
			status.text = "OWNED · DISPONIBLE"
			button.text = "SELECCIONAR"
			button.disabled = false
		elif not available:
			var milestone_id: StringName = unlock["required_milestone"]
			var milestone: MilestoneData = MilestoneCatalog.get_by_id(milestone_id)
			status.text = "LOCKED · REQUIERE %s" % (milestone.display_name.to_upper() if milestone != null else "HITO")
			button.text = "BLOQUEADO"
			button.disabled = true
		else:
			status.text = "AVAILABLE · COSTO %d CENIZA" % cost
			button.text = "DESBLOQUEAR Y SELECCIONAR"
			button.disabled = profile.total_ash < cost


func _on_unlock_pressed(unlock_id: StringName) -> void:
	if MetaUnlockCatalog.is_owned(SaveManager.profile, unlock_id):
		SaveManager.select_starting_option(unlock_id)
	elif SaveManager.try_purchase_meta_unlock(unlock_id):
		AudioManager.play_event(AudioManager.AudioEvent.LEVEL_UP, 1.05)


func _on_clear_starting_option() -> void:
	SaveManager.clear_starting_option()


func _update_upgrade(
	type: PermanentUpgradeConfig.UpgradeType,
	level_label: Label,
	bonus_label: Label,
	next_label: Label,
	cost_label: Label,
	button: Button,
) -> void:
	var level := PermanentUpgradeConfig.get_level(SaveManager.profile, type)
	var bonus := PermanentUpgradeConfig.get_total_bonus(type, level)
	level_label.text = "NIVEL %d / %d\n[%s%s]" % [
		level, PermanentUpgradeConfig.MAX_LEVEL,
		_progress_marks(level, "#"), _progress_marks(PermanentUpgradeConfig.MAX_LEVEL - level, "-"),
	]
	match type:
		PermanentUpgradeConfig.UpgradeType.VITALITY:
			bonus_label.text = "Bonificación actual:  +%d Vida máxima" % bonus
			next_label.text = "SIGUIENTE:  +%d Vida máxima" % PermanentUpgradeConfig.get_total_bonus(type, level + 1)
		PermanentUpgradeConfig.UpgradeType.MIGHT:
			bonus_label.text = "Bonificación actual:  +%d Ataque" % bonus
			next_label.text = "SIGUIENTE:  +%d Ataque" % PermanentUpgradeConfig.get_total_bonus(type, level + 1)
		PermanentUpgradeConfig.UpgradeType.GUARD:
			bonus_label.text = "Bonificación actual:  +%d Defensa" % bonus
			next_label.text = "SIGUIENTE:  +%d Defensa" % PermanentUpgradeConfig.get_total_bonus(type, level + 1)

	if level >= PermanentUpgradeConfig.MAX_LEVEL:
		cost_label.text = "MAX"
		next_label.text = "Todos los niveles desbloqueados"
		button.text = "MAX"
		button.disabled = true
		return

	var cost := PermanentUpgradeConfig.get_cost(type, level)
	cost_label.text = "COSTO: %d CENIZA" % cost
	button.text = "COMPRAR"
	button.disabled = SaveManager.profile.total_ash < cost


func _progress_marks(count: int, mark: String) -> String:
	var result: String = ""
	for _index: int in count:
		result += mark
	return result


func _on_upgrade_pressed(type: PermanentUpgradeConfig.UpgradeType) -> void:
	if SaveManager.try_purchase_upgrade(type):
		AudioManager.play_event(AudioManager.AudioEvent.LEVEL_UP, 0.9)


func _on_debug_add_ash_pressed() -> void:
	SaveManager.add_debug_ash(100)


func _on_back_pressed() -> void:
	back_button.disabled = true
	back_requested.emit()

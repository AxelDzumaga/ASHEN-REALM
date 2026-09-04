extends Control

signal continue_requested

@onready var reward_label: Label = %RewardLabel
@onready var continue_button: Button = %ContinueButton
@onready var treasure_emblem: AshenIcon = %TreasureEmblem

var _offers: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _selection_locked: bool = false


func _ready() -> void:
	if not RunManager.has_active_run():
		push_error("Treasure screen requires an active run.")
		return
	if RunManager.current_run.board_position in RunManager.current_run.resolved_treasure_positions:
		continue_requested.emit.call_deferred()
		return
	_offers = TreasureChoiceResolver.generate_offers(RunManager.current_run)
	if _offers.is_empty():
		push_error("Treasure choice produced no valid offers.")
		continue_requested.emit.call_deferred()
		return
	reward_label.hide()
	treasure_emblem.configure(&"treasure", VisualTheme.TREASURE, AshenIcon.DisplaySize.XLARGE)
	reward_label.add_theme_stylebox_override("normal", VisualTheme.elevated_panel_style(Color("2a2115"), VisualTheme.TREASURE, 3, 14))
	AudioManager.play_sfx(AudioManager.Sfx.TREASURE)
	continue_button.hide()
	var options_container := VBoxContainer.new()
	options_container.add_theme_constant_override("separation", 12)
	reward_label.get_parent().add_child(options_container)
	for offer: Dictionary in _offers:
		var button := Button.new()
		button.theme_type_variation = &"SecondaryButton"
		button.custom_minimum_size = Vector2(0, 126)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s\n%s" % [String(offer.get("label", "RECOMPENSA")), _compact_offer_description(String(offer.get("description", "")))]
		var offer_accent := _offer_accent(offer)
		for state: String in ["normal", "hover", "focus", "pressed", "disabled"]:
			var background := Color("241d18")
			var width := 2
			if state == "hover" or state == "focus":
				background = background.lightened(0.1)
				width = 3
			elif state == "pressed":
				background = background.darkened(0.08)
			var option_style := VisualTheme.elevated_panel_style(background, offer_accent, width, 12)
			option_style.content_margin_left = 82.0
			option_style.content_margin_right = 18.0
			button.add_theme_stylebox_override(state, option_style)
		button.tooltip_text = String(offer.get("description", ""))
		var icon := AshenIcon.new()
		icon.position = Vector2(22.0, 42.0)
		icon.configure(_offer_icon(offer), offer_accent, AshenIcon.DisplaySize.LARGE)
		button.add_child(icon)
		button.pressed.connect(_on_offer_pressed.bind(offer, button))
		options_container.add_child(button)
		_buttons.append(button)
	TelemetryManager.track_treasure_choice_shown(RunManager.current_run, _offers)
	_buttons[0].grab_focus()


func _offer_icon(offer: Dictionary) -> StringName:
	match String(offer.get("kind", "")):
		"recovery", "vitality":
			return &"heal"
		"ash":
			return &"ash"
		"augment":
			return &"augment"
		_:
			return &"treasure"


func _offer_accent(offer: Dictionary) -> Color:
	match String(offer.get("kind", "")):
		"recovery", "vitality": return VisualTheme.HEAL
		"ash": return VisualTheme.ASH
		"augment": return VisualTheme.EPIC
		_: return VisualTheme.TREASURE


func _compact_offer_description(value: String) -> String:
	return value.replace(" para esta partida", "").replace("Invocá ", "ACTIVA ").replace(" con menos Brasa acumulada", " · MENOR COSTE").replace(" de Ceniza", " CENIZA")


func _on_offer_pressed(offer: Dictionary, selected_button: Button) -> void:
	if _selection_locked:
		return
	_selection_locked = true
	for button: Button in _buttons:
		button.disabled = true
	var resolution: Dictionary = TreasureChoiceResolver.apply_offer(RunManager.current_run, offer)
	if not bool(resolution.get("applied", false)):
		return
	TelemetryManager.track_treasure_choice_selected(RunManager.current_run, String(offer.get("id", "")), String(resolution.get("kind", "none")))
	selected_button.text = "SELECCIONADO\n%s" % String(resolution.get("text", ""))
	selected_button.add_theme_stylebox_override("disabled", VisualTheme.elevated_panel_style(Color("4a3214"), VisualTheme.EMBER_BRIGHT, 4, 12))
	await get_tree().create_timer(0.75).timeout
	continue_requested.emit()

extends Control

## Primary button intent — game.gd interprets it against the current
## character count (0 -> create, 1 -> continue directly, 2-3 -> selector).
## Kept as one signal (rather than separate "new game"/"continue"/
## "select" signals) so this screen only reports the raw UI action; it
## does not need to know Profile System semantics itself.
signal start_game_requested
signal settings_requested
signal how_to_play_requested
signal new_character_requested

@onready var start_game_button: Button = %StartGameButton
@onready var new_character_button: Button = %NewCharacterButton
@onready var character_summary_label: Label = %CharacterSummaryLabel
@onready var settings_button: Button = %SettingsButton
@onready var how_to_play_button: Button = %HowToPlayButton
@onready var title: Label = %Title
@onready var hero_view: CombatCharacterView = %HeroView
@onready var crest_icon: AshenIcon = %CrestIcon
@onready var start_icon: AshenIcon = %StartIcon
@onready var settings_icon: AshenIcon = %SettingsIcon
@onready var help_icon: AshenIcon = %HelpIcon


func _ready() -> void:
	start_game_button.pressed.connect(_on_start_game_pressed)
	new_character_button.pressed.connect(_on_new_character_pressed)
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	how_to_play_button.pressed.connect(func() -> void: how_to_play_requested.emit())
	hero_view.setup_visual(PlayerVisualCatalog.ASHEN_WANDERER, "ASH")
	crest_icon.configure(&"ember", Color("b99a68"), AshenIcon.DisplaySize.MEDIUM)
	start_icon.configure(&"route", VisualTheme.EMBER_BRIGHT, AshenIcon.DisplaySize.LARGE)
	settings_icon.configure(&"cooldown", VisualTheme.ASH, AshenIcon.DisplaySize.MEDIUM)
	help_icon.configure(&"skill", VisualTheme.ASH, AshenIcon.DisplaySize.MEDIUM)
	_configure_button_motion()
	if not SettingsManager.reduce_motion:
		title.modulate.a = 0.0
		title.position.y += 12.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(title, "modulate:a", 1.0, 0.45)
		tween.tween_property(title, "position:y", title.position.y - 12.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	start_game_button.grab_focus()


func _configure_button_motion() -> void:
	for button: Button in [start_game_button, new_character_button, settings_button, how_to_play_button]:
		button.mouse_entered.connect(_animate_button.bind(button, true))
		button.mouse_exited.connect(_animate_button.bind(button, false))
		button.focus_entered.connect(_animate_button.bind(button, true))
		button.focus_exited.connect(_animate_button.bind(button, false))
		button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
		button.pivot_offset = button.size * 0.5


func _animate_button(button: Button, active: bool) -> void:
	if SettingsManager.reduce_motion or not is_instance_valid(button):
		return
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.018, 1.018) if active else Vector2.ONE, 0.12)


func _on_start_game_pressed() -> void:
	start_game_button.disabled = true
	new_character_button.disabled = true
	start_game_requested.emit()


func _on_new_character_pressed() -> void:
	start_game_button.disabled = true
	new_character_button.disabled = true
	new_character_requested.emit()


## Profile System startup UX (approved design): 0 characters -> NUEVA
## PARTIDA; 1 -> CONTINUAR directly (no selector shown) with a name/level
## summary and a NUEVO PERSONAJE option; 2-3 -> SELECCIONAR PERSONAJE.
## `has_active_run` (only meaningful in the one-character case) swaps the
## label to CONTINUAR EXPEDICIÓN — Active Run Persistence's Continue UX —
## so a player can tell "resume where I left off" apart from "nothing in
## progress, just enter the Refuge".
func configure_for_characters(characters: Array, has_active_run: bool = false) -> void:
	var count: int = characters.size()
	new_character_button.visible = count == 1
	if count == 0:
		start_game_button.text = "NUEVA PARTIDA"
		character_summary_label.visible = false
	elif count == 1:
		start_game_button.text = "CONTINUAR EXPEDICIÓN" if has_active_run else "CONTINUAR"
		var entry: Dictionary = characters[0]
		var display_name: String = String(entry.get("display_name", ""))
		var level: int = int(entry.get("player_level", 1))
		character_summary_label.text = "%s  ·  NIVEL %d" % [display_name, level]
		character_summary_label.visible = not display_name.is_empty()
	else:
		start_game_button.text = "SELECCIONAR PERSONAJE"
		character_summary_label.visible = false

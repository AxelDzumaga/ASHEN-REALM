extends Control

signal reward_selected(reward: BossRewardData)

const OPTION_COUNT := 3
const CONFIRMATION_DELAY := 0.75

@onready var cards: VBoxContainer = %Cards
@onready var status_label: Label = %StatusLabel

var _buttons: Array[Button] = []
var _selection_locked: bool = false


func _ready() -> void:
	if not RunManager.has_active_run() or not RunManager.current_run.run_completed:
		push_error("Boss Reward requires a completed active run.")
		return
	_create_options()
	AudioManager.play_sfx(AudioManager.Sfx.BOSS_REWARD)
	if not _buttons.is_empty():
		_buttons[0].grab_focus()
	TutorialManager.request(TutorialCatalog.BOSS_REWARD, TutorialManager.CONTEXT_BOSS_REWARD, self)


func _create_options() -> void:
	var run: RunState = RunManager.current_run
	var selected: Array[BossRewardData] = BuildRewardResolver.generate_boss_options(
		run,
		run.next_reward_offer_seed(&"boss_reward"),
		OPTION_COUNT,
	)
	if DebugConfig.DEBUG_TOOLS_ENABLED and not DebugConfig.DEBUG_FORCED_BOSS_REWARD_ID.is_empty():
		var forced: BossRewardData = BossRewardCatalog.get_by_id(DebugConfig.DEBUG_FORCED_BOSS_REWARD_ID)
		if forced != null and forced not in selected:
			selected[0] = forced
	for reward: BossRewardData in selected:
		_add_card(reward)


func _add_card(reward: BossRewardData) -> void:
	var button: Button = Button.new()
	button.theme_type_variation = &"SecondaryButton"
	button.custom_minimum_size = Vector2(0, 132)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 21)
	button.text = "%s\n%s" % [reward.display_name.to_upper(), reward.description.replace(" · ", "\n")]
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.set_meta(&"audio_skip_generic", true)
	button.add_theme_stylebox_override("normal", VisualTheme.elevated_panel_style(VisualTheme.CARD, VisualTheme.EMBER, 3, 12))
	button.add_theme_stylebox_override("focus", VisualTheme.button_style(Color("382617"), VisualTheme.EMBER_BRIGHT, 4))
	button.add_theme_stylebox_override("hover", VisualTheme.button_style(Color("382617"), VisualTheme.EMBER, 3))
	button.pressed.connect(_on_reward_pressed.bind(reward, button))
	var reward_icon: AshenIcon = AshenIcon.new()
	reward_icon.configure(reward.id, VisualTheme.EMBER_BRIGHT, AshenIcon.DisplaySize.LARGE)
	reward_icon.position = Vector2(16.0, 16.0)
	button.add_child(reward_icon)
	cards.add_child(button)
	_buttons.append(button)


func _on_reward_pressed(reward: BossRewardData, selected_button: Button) -> void:
	if _selection_locked or RunManager.current_run.boss_reward_applied:
		return
	_selection_locked = true
	for button: Button in _buttons:
		button.disabled = true
	if not BossRewardCatalog.apply(reward, RunManager.current_run):
		_selection_locked = false
		for button: Button in _buttons:
			button.disabled = false
		return
	selected_button.add_theme_stylebox_override("disabled", VisualTheme.button_style(VisualTheme.EMBER_DARK, VisualTheme.EMBER_BRIGHT, 4))
	selected_button.text = "SELECCIONADA\n%s\n\n%s" % [reward.display_name.to_upper(), reward.description]
	status_label.text = "Reclamada: %s" % reward.display_name
	AudioManager.play_event(AudioManager.AudioEvent.LOOT_REVEAL, 1.12)
	await get_tree().create_timer(CONFIRMATION_DELAY).timeout
	reward_selected.emit(reward)

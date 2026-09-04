extends Control

signal event_resolved

const RETURN_DELAY := 0.75

@onready var event_title: Label = %EventTitle
@onready var risk_tier_label: Label = %RiskTierLabel
@onready var description_label: Label = %DescriptionLabel
@onready var option_a_button: Button = %OptionAButton
@onready var option_b_button: Button = %OptionBButton
@onready var result_label: Label = %ResultLabel
@onready var event_emblem: AshenIcon = %EventEmblem
@onready var risk_icon: AshenIcon = %RiskIcon

var _event: EventData
var _event_pool: Array[EventData] = []
var _choice_locked: bool = false


func configure(event_pool: Array[EventData]) -> void:
	_event_pool = event_pool


func _ready() -> void:
	if not RunManager.has_active_run() or _event_pool.is_empty():
		push_error("Event screen requires an active run and event data.")
		return
	if RunManager.current_run.board_position in RunManager.current_run.resolved_event_positions:
		event_resolved.emit.call_deferred()
		return
	_event = EventResolver.select_for_run(_event_pool, RunManager.current_run)
	if _event == null:
		result_label.text = "No queda ningún encuentro pendiente en este lugar."
		option_a_button.hide()
		option_b_button.hide()
		RunManager.current_run.resolved_event_positions.append(RunManager.current_run.board_position)
		event_resolved.emit.call_deferred()
		return
	event_title.text = _event.title
	risk_tier_label.text = "RIESGO  ·  %s" % _event.get_difficulty_label()
	risk_tier_label.tooltip_text = _event.risk_summary
	risk_tier_label.modulate = _difficulty_color(_event.difficulty_tier)
	risk_tier_label.add_theme_stylebox_override("normal", VisualTheme.elevated_panel_style(Color("17141a"), _difficulty_color(_event.difficulty_tier), 2, 10))
	var tier_icon: StringName = [&"easy", &"medium", &"hard"][_event.difficulty_tier]
	event_emblem.configure(&"event", _difficulty_color(_event.difficulty_tier), AshenIcon.DisplaySize.XLARGE)
	risk_icon.configure(tier_icon, _difficulty_color(_event.difficulty_tier), AshenIcon.DisplaySize.SMALL)
	description_label.text = _event.description
	option_a_button.text = _option_text(true)
	option_b_button.text = _option_text(false)
	option_a_button.disabled = not EventResolver.can_choose(_event, true, RunManager.current_run)
	option_b_button.disabled = not EventResolver.can_choose(_event, false, RunManager.current_run)
	if option_a_button.disabled:
		option_a_button.text = "NO DISPONIBLE\n" + option_a_button.text
	if option_b_button.disabled:
		option_b_button.text = "NO DISPONIBLE\n" + option_b_button.text
	_decorate_option(option_a_button, true, Color("2b2119"), VisualTheme.EMBER)
	_decorate_option(option_b_button, false, Color("1d1921"), VisualTheme.EVENT)
	option_a_button.pressed.connect(_on_option_pressed.bind(true, option_a_button))
	option_b_button.pressed.connect(_on_option_pressed.bind(false, option_b_button))
	AudioManager.play_sfx(AudioManager.Sfx.EVENT)
	TelemetryManager.track_event_choice_shown(RunManager.current_run, _event.id, _event.option_id(true), _event.option_id(false))
	(option_b_button if option_a_button.disabled else option_a_button).grab_focus()


func _on_option_pressed(choose_option_a: bool, selected_button: Button) -> void:
	if _choice_locked:
		return
	if not EventResolver.can_choose(_event, choose_option_a, RunManager.current_run):
		return
	_choice_locked = true
	option_a_button.disabled = true
	option_b_button.disabled = true
	var resolution: Dictionary = EventApplier.apply_detailed(_event, choose_option_a, RunManager.current_run)
	if not bool(resolution.get("applied", false)):
		_choice_locked = false
		return
	RunManager.current_run.events_resolved += 1
	TelemetryManager.track_event_choice_selected(RunManager.current_run, _event.id, _event.option_id(choose_option_a), String(resolution.get("reward_type", "none")))
	result_label.text = "RESULTADO\n%s" % String(resolution.get("text", "Nada cambia."))
	if not SettingsManager.reduce_motion:
		selected_button.pivot_offset = selected_button.size * 0.5
		selected_button.scale = Vector2(1.035, 1.035)
		var tween: Tween = create_tween()
		tween.tween_property(selected_button, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(RETURN_DELAY).timeout
	event_resolved.emit()


func _option_text(option_a: bool) -> String:
	var label: String = _event.option_a_text if option_a else _event.option_b_text
	var effect: String = _event.option_a_effect_text if option_a else _event.option_b_effect_text
	var health_delta: int = _event.option_a_health_delta if option_a else _event.option_b_health_delta
	var projected_health: int = RunManager.current_run.current_health + health_delta
	var danger: bool = health_delta < 0 and projected_health * 100 <= RunManager.current_run.max_health * 25
	return "%s%s\n%s" % ["!  " if danger else "", label, _compact_effect(effect)]


func _compact_effect(effect: String) -> String:
	return effect.replace("Perdés ", "-").replace("Recuperás ", "+").replace("Ganás ", "").replace(" de Vida máxima", " VIDA MAX").replace(" de Vida actual", " VIDA").replace(" de Vida", " VIDA").replace(" de Ataque", " ATQ").replace(" de Defensa", " DEF").replace(" de Ceniza", " CENIZA").replace(" · ", "   ")


func _decorate_option(button: Button, option_a: bool, background: Color, accent: Color) -> void:
	for state: String in ["normal", "hover", "focus", "pressed", "disabled"]:
		var state_background := background
		var state_accent := accent
		var width := 2
		if state == "hover" or state == "focus":
			state_background = background.lightened(0.09)
			width = 3
		elif state == "pressed":
			state_background = background.darkened(0.08)
		elif state == "disabled":
			state_background = Color("17151a")
			state_accent = VisualTheme.LOCKED
		var style := VisualTheme.elevated_panel_style(state_background, state_accent, width, 12)
		style.content_margin_left = 78.0
		style.content_margin_right = 18.0
		button.add_theme_stylebox_override(state, style)
	var icon := AshenIcon.new()
	icon.position = Vector2(22.0, 40.0)
	icon.configure(_option_icon(option_a), accent, AshenIcon.DisplaySize.LARGE, not button.disabled)
	button.add_child(icon)


func _option_icon(option_a: bool) -> StringName:
	var health_delta: int = _event.option_a_health_delta if option_a else _event.option_b_health_delta
	var attack_delta: int = _event.option_a_attack_delta if option_a else _event.option_b_attack_delta
	var defense_delta: int = _event.option_a_defense_delta if option_a else _event.option_b_defense_delta
	var effect: String = (_event.option_a_effect_text if option_a else _event.option_b_effect_text).to_lower()
	if health_delta != 0: return &"health"
	if attack_delta != 0: return &"attack"
	if defense_delta != 0: return &"defense"
	if "ceniza" in effect: return &"ash"
	if "boon" in effect or "técnica" in effect: return &"boon"
	return &"route"


func _difficulty_color(tier: EventData.DifficultyTier) -> Color:
	match tier:
		EventData.DifficultyTier.EASY:
			return VisualTheme.HEAL
		EventData.DifficultyTier.HARD:
			return VisualTheme.DANGER
		_:
			return VisualTheme.EMBER

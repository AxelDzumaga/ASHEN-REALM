class_name TutorialOverlay
extends Control

signal input_guard_requested(frame_count: int)

var _visible_tutorial_id: StringName = &""
var _visibility_generation: int = 0

@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel
@onready var got_it_button: Button = %GotItButton
@onready var skip_button: Button = %SkipButton
@onready var confirmation: VBoxContainer = %Confirmation
@onready var confirm_yes_button: Button = %ConfirmYesButton
@onready var confirm_no_button: Button = %ConfirmNoButton

func _ready() -> void:
	add_to_group(&"tutorial_overlays")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	got_it_button.set_meta(&"audio_skip_generic", true)
	skip_button.set_meta(&"audio_skip_generic", true)
	confirm_yes_button.set_meta(&"audio_skip_generic", true)
	confirm_no_button.set_meta(&"audio_skip_generic", true)
	got_it_button.pressed.connect(_on_understood_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	confirm_yes_button.pressed.connect(_on_skip_confirmed)
	confirm_no_button.pressed.connect(_hide_confirmation)
	TutorialManager.tutorial_presented.connect(_show_tutorial)
	TutorialManager.tutorial_closed.connect(_close_tutorial)
	_trace(&"OVERLAY_READY")


func set_trace_enabled(enabled: bool) -> void:
	set_meta(&"tutorial_trace_enabled", enabled)


func _show_tutorial(data: TutorialData) -> void:
	_trace(&"SHOW_APPLIED", data.id)
	_visibility_generation += 1
	_visible_tutorial_id = data.id
	title_label.text = data.title
	body_label.text = data.body
	_hide_confirmation()
	_set_buttons_disabled(false)
	visible = true
	got_it_button.grab_focus()


func _show_confirmation() -> void:
	got_it_button.visible = false
	skip_button.visible = false
	confirmation.visible = true
	confirm_no_button.grab_focus()


func _on_understood_pressed() -> void:
	_trace(&"UNDERSTOOD_PRESSED")
	_hide_visual_immediately(&"understood")
	TutorialManager.complete_current()


func _on_skip_pressed() -> void:
	_trace(&"SKIP_PRESSED")
	_show_confirmation()


func _on_skip_confirmed() -> void:
	_trace(&"SKIP_CONFIRMED")
	_hide_visual_immediately(&"skip_confirmed")
	TutorialManager.skip_all()


func _hide_confirmation() -> void:
	confirmation.visible = false
	got_it_button.visible = true
	skip_button.visible = true


func _close_tutorial(_id: StringName, _result: TutorialManager.FinishResult) -> void:
	_trace(&"CLOSE_SIGNAL_RECEIVED", _id)
	_hide_visual_immediately(&"manager_signal", _id)


func _hide_visual_immediately(source: StringName, tutorial_id: StringName = &"") -> void:
	var closing_id: StringName = tutorial_id if not tutorial_id.is_empty() else _visible_tutorial_id
	_trace(&"OVERLAY_HIDE_BEFORE", closing_id, {"source": String(source)})
	if not visible:
		_trace(&"OVERLAY_HIDE_AFTER", closing_id, {"source": String(source), "already_hidden": true})
		return
	_set_buttons_disabled(true)
	visible = false
	_hide_confirmation()
	_visible_tutorial_id = &""
	_trace(&"OVERLAY_HIDE_AFTER", closing_id, {"source": String(source)})
	input_guard_requested.emit(2)
	_schedule_visibility_verification(_visibility_generation, closing_id)


func _schedule_visibility_verification(generation: int, tutorial_id: StringName) -> void:
	get_tree().process_frame.connect(
		_verify_hidden_after_frame.bind(generation, tutorial_id, 1),
		CONNECT_ONE_SHOT,
	)


func _verify_hidden_after_frame(generation: int, tutorial_id: StringName, frame: int) -> void:
	if generation != _visibility_generation:
		return
	_trace(&"VISIBILITY_CHANGED", tutorial_id, {"frame": frame, "expected_visible": false})
	if visible:
		push_error("TutorialOverlay became visible again without a new tutorial generation.")
	if frame < 2:
		get_tree().process_frame.connect(
			_verify_hidden_after_frame.bind(generation, tutorial_id, frame + 1),
			CONNECT_ONE_SHOT,
		)


func _trace(event: StringName, tutorial_id: StringName = &"", extra: Dictionary = {}) -> void:
	if not bool(get_meta(&"tutorial_trace_enabled", false)):
		return
	var details: Dictionary = {
		"overlay_instance_id": get_instance_id(),
		"button_instance_id": got_it_button.get_instance_id() if got_it_button != null else 0,
		"node_path": String(get_path()),
		"tutorial_id": String(tutorial_id),
		"visible": visible,
	}
	details.merge(extra, true)
	print("[TUTORIAL_TRACE] %s %s" % [event, JSON.stringify(details)])


func _set_buttons_disabled(disabled: bool) -> void:
	got_it_button.disabled = disabled
	skip_button.disabled = disabled
	confirm_yes_button.disabled = disabled
	confirm_no_button.disabled = disabled

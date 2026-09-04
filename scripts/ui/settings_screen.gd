extends Control

signal back_requested

@onready var master_slider: HSlider = %MasterSlider
@onready var master_value: Label = %MasterValue
@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_value: Label = %SfxValue
@onready var reduce_motion_check: CheckButton = %ReduceMotionCheck
@onready var back_button: Button = %BackButton


func _ready() -> void:
	master_slider.value = SettingsManager.master_volume * 100.0
	music_slider.value = SettingsManager.music_volume * 100.0
	sfx_slider.value = SettingsManager.sfx_volume * 100.0
	reduce_motion_check.button_pressed = SettingsManager.reduce_motion
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	reduce_motion_check.toggled.connect(SettingsManager.set_reduce_motion)
	back_button.pressed.connect(_on_back_pressed)
	_configure_focus_navigation()
	_refresh_values()
	master_slider.grab_focus()


func _on_master_changed(value: float) -> void:
	SettingsManager.set_master_volume(value / 100.0)
	_refresh_values()


func _on_sfx_changed(value: float) -> void:
	SettingsManager.set_sfx_volume(value / 100.0)
	_refresh_values()


func _on_music_changed(value: float) -> void:
	SettingsManager.set_music_volume(value / 100.0)
	_refresh_values()


func _refresh_values() -> void:
	master_value.text = "%d%%" % roundi(master_slider.value)
	music_value.text = "%d%%" % roundi(music_slider.value)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value)


func _configure_focus_navigation() -> void:
	master_slider.focus_mode = Control.FOCUS_ALL
	music_slider.focus_mode = Control.FOCUS_ALL
	sfx_slider.focus_mode = Control.FOCUS_ALL
	reduce_motion_check.focus_mode = Control.FOCUS_ALL
	back_button.focus_mode = Control.FOCUS_ALL
	master_slider.focus_neighbor_bottom = master_slider.get_path_to(music_slider)
	music_slider.focus_neighbor_top = music_slider.get_path_to(master_slider)
	music_slider.focus_neighbor_bottom = music_slider.get_path_to(sfx_slider)
	sfx_slider.focus_neighbor_top = sfx_slider.get_path_to(music_slider)
	sfx_slider.focus_neighbor_bottom = sfx_slider.get_path_to(reduce_motion_check)
	reduce_motion_check.focus_neighbor_top = reduce_motion_check.get_path_to(sfx_slider)
	reduce_motion_check.focus_neighbor_bottom = reduce_motion_check.get_path_to(back_button)
	back_button.focus_neighbor_top = back_button.get_path_to(reduce_motion_check)
	master_slider.focus_next = master_slider.focus_neighbor_bottom
	music_slider.focus_previous = music_slider.focus_neighbor_top
	music_slider.focus_next = music_slider.focus_neighbor_bottom
	sfx_slider.focus_previous = sfx_slider.focus_neighbor_top
	sfx_slider.focus_next = sfx_slider.focus_neighbor_bottom
	reduce_motion_check.focus_previous = reduce_motion_check.focus_neighbor_top
	reduce_motion_check.focus_next = reduce_motion_check.focus_neighbor_bottom
	back_button.focus_previous = back_button.focus_neighbor_top


func _on_back_pressed() -> void:
	back_button.disabled = true
	back_requested.emit()

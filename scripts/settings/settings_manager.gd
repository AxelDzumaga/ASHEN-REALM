extends Node

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_MUSIC_VOLUME := 0.8
const DEFAULT_SFX_VOLUME := 1.0
const DEFAULT_ANALYTICS_ENABLED := false

var master_volume: float = DEFAULT_MASTER_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var reduce_motion: bool = false
var analytics_enabled: bool = DEFAULT_ANALYTICS_ENABLED


func _ready() -> void:
	load_settings()
	apply_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		_reset_defaults()
		return
	master_volume = clampf(float(config.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", DEFAULT_SFX_VOLUME)), 0.0, 1.0)
	reduce_motion = bool(config.get_value("accessibility", "reduce_motion", false))
	analytics_enabled = bool(config.get_value("privacy", "analytics_enabled", DEFAULT_ANALYTICS_ENABLED))


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_master_volume(master_volume)
	_save_and_notify()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_sfx_volume(sfx_volume)
	_save_and_notify()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_music_volume(music_volume)
	_save_and_notify()


func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled
	_save_and_notify()


func apply_settings() -> void:
	AudioManager.set_master_volume(master_volume)
	AudioManager.set_music_volume(music_volume)
	AudioManager.set_sfx_volume(sfx_volume)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("accessibility", "reduce_motion", reduce_motion)
	config.set_value("privacy", "analytics_enabled", analytics_enabled)
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("No se pudieron guardar los ajustes.")


func _save_and_notify() -> void:
	save_settings()
	settings_changed.emit()


func _reset_defaults() -> void:
	master_volume = DEFAULT_MASTER_VOLUME
	music_volume = DEFAULT_MUSIC_VOLUME
	sfx_volume = DEFAULT_SFX_VOLUME
	reduce_motion = false
	analytics_enabled = DEFAULT_ANALYTICS_ENABLED

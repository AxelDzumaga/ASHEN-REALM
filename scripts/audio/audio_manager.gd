extends Node

enum Sfx {
	UI_CLICK,
	DICE_ROLL,
	PLAYER_ATTACK,
	ENEMY_ATTACK,
	HEAL,
	UPGRADE_SELECTED,
	EQUIPMENT_EQUIPPED,
	LOOT_OBTAINED,
	COMBAT_ENTER,
	BOSS_ENCOUNTER,
	EVENT,
	TREASURE,
	ELITE,
	BIOME_ENTER,
	SYNERGY_ACTIVATED,
	EPIC_REVEAL,
	BOSS_REWARD,
	SKILL_READY,
	EMBER_SLASH,
	ASHEN_GUARD,
	SECOND_WIND,
	SKILL_AUGMENT_SELECTED,
	CODEX_DISCOVERED,
	TUTORIAL_OPEN,
	VICTORY,
	DEFEAT,
}

enum AudioEvent {
	UI_CLICK,
	UI_CONFIRM,
	UI_BACK,
	EQUIP,
	DICE_ROLL,
	DICE_LAND,
	BOARD_STEP,
	BASIC_ATTACK,
	SKILL_ATTACK,
	IMPACT_PLAYER,
	CRITICAL,
	GUARD_ACTIVATE,
	GUARD_CONSUMED,
	HEAL,
	BURN_TICK,
	STATUS_APPLY,
	COMPANION_ATTACK,
	COMPANION_SPECIAL,
	COMPANION_DEATH,
	ENEMY_SPECIAL,
	ENEMY_DEATH,
	BOSS_PHASE,
	BOSS_REBUKE,
	BOSS_SUMMON,
	BOSS_DEATH,
	LEVEL_UP,
	SYNERGY_ACTIVATE,
	LOOT_REVEAL,
	SKILL_READY,
	VICTORY,
	DEFEAT,
}

enum Priority {
	LOW,
	NORMAL,
	HIGH,
	VERY_HIGH,
}

enum MusicState {
	SILENT,
	LOBBY,
	BOARD,
	COMBAT,
	BOSS,
	RESULTS,
}

const SAMPLE_RATE: int = 22050
const PLAYER_POOL_SIZE: int = 6
const DETERMINISTIC_PITCH_OFFSETS: Array[float] = [-0.02, 0.0, 0.02, 0.0]

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _player_priorities: Array[int] = []
var _next_player: int = 0
var _last_event_msec: Dictionary[int, int] = {}
var _event_pitch_indices: Dictionary[int, int] = {}
var _music_player: AudioStreamPlayer
var _music_streams: Dictionary[int, AudioStream] = {}
var _music_state: MusicState = MusicState.SILENT
var _background_paused: bool = false


func _ready() -> void:
	_build_provisional_streams()
	for index in PLAYER_POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "SfxPlayer%d" % (index + 1)
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)
		_player_priorities.append(Priority.LOW)
		player.finished.connect(_on_player_finished.bind(index))
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = &"Music"
	add_child(_music_player)
	get_tree().node_added.connect(_on_node_added)
	_attach_existing_buttons(get_tree().root)


func play_sfx(effect: Sfx, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	_play_stream(effect, pitch_scale, volume_db, Priority.NORMAL)


func play_event(event: AudioEvent, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	var now_msec: int = Time.get_ticks_msec()
	var event_key: int = int(event)
	var last_msec: int = int(_last_event_msec.get(event_key, -100000))
	if now_msec - last_msec < _dedupe_window_msec(event):
		return
	_last_event_msec[event_key] = now_msec
	var resolved_pitch: float = pitch_scale * _event_base_pitch(event)
	if _uses_pitch_variation(event):
		var pitch_index: int = int(_event_pitch_indices.get(event_key, 0))
		resolved_pitch += DETERMINISTIC_PITCH_OFFSETS[pitch_index % DETERMINISTIC_PITCH_OFFSETS.size()]
		_event_pitch_indices[event_key] = pitch_index + 1
	_play_stream(_event_sfx(event), resolved_pitch, volume_db + _event_volume_db(event), _event_priority(event))


func set_music_state(state: MusicState) -> void:
	if _music_state == state:
		return
	_music_state = state
	if _music_player == null:
		return
	var stream: AudioStream = _music_streams.get(int(state)) as AudioStream
	if stream == null:
		_music_player.stop()
		_music_player.stream = null
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stop()
	_music_player.stream = stream
	_music_player.play()


func get_music_state() -> MusicState:
	return _music_state


func set_background_paused(paused: bool) -> void:
	if _background_paused == paused:
		return
	_background_paused = paused
	for player: AudioStreamPlayer in _players:
		player.stream_paused = paused
	if _music_player != null:
		_music_player.stream_paused = paused


func _play_stream(effect: Sfx, pitch_scale: float, volume_db: float, priority: Priority) -> void:
	if _background_paused or not _streams.has(effect) or _players.is_empty():
		return
	var player_index: int = _select_player(priority)
	if player_index < 0:
		return
	var player: AudioStreamPlayer = _players[player_index]
	player.stop()
	player.stream = _streams[effect]
	player.pitch_scale = clampf(pitch_scale, 0.5, 2.0)
	player.volume_db = volume_db
	_player_priorities[player_index] = int(priority)
	player.play()


func _select_player(priority: Priority) -> int:
	for offset: int in _players.size():
		var candidate: int = (_next_player + offset) % _players.size()
		if not _players[candidate].playing:
			_next_player = (candidate + 1) % _players.size()
			return candidate
	var lowest_priority: int = _player_priorities[0]
	var lowest_index: int = 0
	for index: int in range(1, _player_priorities.size()):
		if _player_priorities[index] < lowest_priority:
			lowest_priority = _player_priorities[index]
			lowest_index = index
	if int(priority) < lowest_priority:
		return -1
	_next_player = (lowest_index + 1) % _players.size()
	return lowest_index


func _on_player_finished(index: int) -> void:
	if index >= 0 and index < _player_priorities.size():
		_player_priorities[index] = Priority.LOW


func set_master_volume(linear_value: float) -> void:
	_set_bus_volume(&"Master", linear_value)


func set_music_volume(linear_value: float) -> void:
	_set_bus_volume(&"Music", linear_value)


func set_sfx_volume(linear_value: float) -> void:
	_set_bus_volume(&"SFX", linear_value)


func _set_bus_volume(bus_name: StringName, linear_value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var safe_value: float = clampf(linear_value, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, safe_value <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(safe_value, 0.0001)))


func _on_node_added(node: Node) -> void:
	if node is Button:
		_attach_button.call_deferred(node as Button)


func _attach_existing_buttons(node: Node) -> void:
	if node is Button:
		_attach_button(node as Button)
	for child in node.get_children():
		_attach_existing_buttons(child)


func _attach_button(button: Button) -> void:
	if not is_instance_valid(button) or button.has_meta(&"audio_feedback_attached"):
		return
	button.set_meta(&"audio_feedback_attached", true)
	button.pressed.connect(_on_button_pressed.bind(button))


func _on_button_pressed(button: Button) -> void:
	if not is_instance_valid(button):
		return
	if not bool(button.get_meta(&"audio_skip_generic", false)):
		var normalized_name: String = button.name.to_lower()
		if "back" in normalized_name or "return" in normalized_name or "mainmenu" in normalized_name:
			play_event(AudioEvent.UI_BACK)
		elif "start" in normalized_name or "confirm" in normalized_name or "continue" in normalized_name:
			play_event(AudioEvent.UI_CONFIRM)
		else:
			play_event(AudioEvent.UI_CLICK)
	if SettingsManager.reduce_motion:
		button.scale = Vector2.ONE
		return
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2(0.97, 0.97)
	var tween: Tween = button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _event_sfx(event: AudioEvent) -> Sfx:
	match event:
		AudioEvent.UI_CLICK: return Sfx.UI_CLICK
		AudioEvent.UI_CONFIRM, AudioEvent.UI_BACK: return Sfx.UI_CLICK
		AudioEvent.EQUIP: return Sfx.EQUIPMENT_EQUIPPED
		AudioEvent.DICE_ROLL: return Sfx.DICE_ROLL
		AudioEvent.DICE_LAND, AudioEvent.BOARD_STEP: return Sfx.UI_CLICK
		AudioEvent.BASIC_ATTACK, AudioEvent.COMPANION_ATTACK: return Sfx.PLAYER_ATTACK
		AudioEvent.SKILL_ATTACK, AudioEvent.COMPANION_SPECIAL, AudioEvent.BURN_TICK: return Sfx.EMBER_SLASH
		AudioEvent.IMPACT_PLAYER, AudioEvent.ENEMY_SPECIAL, AudioEvent.ENEMY_DEATH: return Sfx.ENEMY_ATTACK
		AudioEvent.CRITICAL: return Sfx.EPIC_REVEAL
		AudioEvent.GUARD_ACTIVATE, AudioEvent.GUARD_CONSUMED: return Sfx.ASHEN_GUARD
		AudioEvent.HEAL: return Sfx.HEAL
		AudioEvent.STATUS_APPLY: return Sfx.EVENT
		AudioEvent.COMPANION_DEATH: return Sfx.DEFEAT
		AudioEvent.BOSS_PHASE: return Sfx.BOSS_ENCOUNTER
		AudioEvent.BOSS_REBUKE: return Sfx.ENEMY_ATTACK
		AudioEvent.BOSS_SUMMON: return Sfx.BOSS_REWARD
		AudioEvent.BOSS_DEATH: return Sfx.VICTORY
		AudioEvent.LEVEL_UP: return Sfx.UPGRADE_SELECTED
		AudioEvent.SYNERGY_ACTIVATE: return Sfx.SYNERGY_ACTIVATED
		AudioEvent.LOOT_REVEAL: return Sfx.LOOT_OBTAINED
		AudioEvent.SKILL_READY: return Sfx.SKILL_READY
		AudioEvent.VICTORY: return Sfx.VICTORY
		AudioEvent.DEFEAT: return Sfx.DEFEAT
		_: return Sfx.UI_CLICK


func _event_priority(event: AudioEvent) -> Priority:
	match event:
		AudioEvent.BOARD_STEP, AudioEvent.BURN_TICK: return Priority.LOW
		AudioEvent.CRITICAL, AudioEvent.COMPANION_SPECIAL, AudioEvent.ENEMY_SPECIAL, AudioEvent.BOSS_REBUKE: return Priority.HIGH
		AudioEvent.BOSS_PHASE, AudioEvent.BOSS_SUMMON, AudioEvent.BOSS_DEATH, AudioEvent.VICTORY, AudioEvent.DEFEAT: return Priority.VERY_HIGH
		_: return Priority.NORMAL


func _dedupe_window_msec(event: AudioEvent) -> int:
	match event:
		AudioEvent.UI_CLICK, AudioEvent.BOARD_STEP: return 45
		AudioEvent.BURN_TICK, AudioEvent.STATUS_APPLY: return 70
		AudioEvent.BOSS_PHASE, AudioEvent.BOSS_SUMMON, AudioEvent.BOSS_DEATH, AudioEvent.VICTORY, AudioEvent.DEFEAT: return 180
		_: return 55


func _uses_pitch_variation(event: AudioEvent) -> bool:
	return event in [
		AudioEvent.UI_CLICK, AudioEvent.BOARD_STEP, AudioEvent.BASIC_ATTACK,
		AudioEvent.IMPACT_PLAYER, AudioEvent.COMPANION_ATTACK, AudioEvent.ENEMY_DEATH,
	]


func _event_base_pitch(event: AudioEvent) -> float:
	match event:
		AudioEvent.UI_BACK: return 0.88
		AudioEvent.UI_CONFIRM: return 1.08
		AudioEvent.DICE_LAND: return 1.14
		AudioEvent.BOARD_STEP: return 0.82
		AudioEvent.COMPANION_ATTACK: return 1.12
		AudioEvent.COMPANION_SPECIAL: return 1.08
		AudioEvent.COMPANION_DEATH: return 1.18
		AudioEvent.ENEMY_SPECIAL: return 0.9
		AudioEvent.ENEMY_DEATH: return 0.76
		AudioEvent.BOSS_REBUKE: return 0.72
		AudioEvent.BOSS_SUMMON: return 0.9
		AudioEvent.BOSS_DEATH: return 0.78
		AudioEvent.BURN_TICK: return 1.16
		AudioEvent.GUARD_CONSUMED: return 0.84
		_: return 1.0


func _event_volume_db(event: AudioEvent) -> float:
	match event:
		AudioEvent.UI_CLICK: return -5.0
		AudioEvent.UI_BACK, AudioEvent.UI_CONFIRM: return -4.0
		AudioEvent.BOARD_STEP, AudioEvent.BURN_TICK: return -10.0
		AudioEvent.STATUS_APPLY, AudioEvent.ENEMY_DEATH: return -7.0
		AudioEvent.COMPANION_DEATH: return -5.0
		AudioEvent.CRITICAL: return -2.0
		AudioEvent.BOSS_PHASE, AudioEvent.BOSS_SUMMON, AudioEvent.BOSS_DEATH: return -1.0
		_: return 0.0


func _build_provisional_streams() -> void:
	_streams[Sfx.UI_CLICK] = _make_stream(760.0, 980.0, 0.055, 0.22, 0.0)
	_streams[Sfx.DICE_ROLL] = _make_stream(150.0, 105.0, 0.30, 0.28, 0.72)
	_streams[Sfx.PLAYER_ATTACK] = _make_stream(360.0, 105.0, 0.18, 0.38, 0.20)
	_streams[Sfx.ENEMY_ATTACK] = _make_stream(150.0, 62.0, 0.22, 0.42, 0.32)
	_streams[Sfx.HEAL] = _make_stream(410.0, 790.0, 0.38, 0.25, 0.04)
	_streams[Sfx.UPGRADE_SELECTED] = _make_stream(470.0, 940.0, 0.34, 0.27, 0.02)
	_streams[Sfx.EQUIPMENT_EQUIPPED] = _make_stream(260.0, 520.0, 0.24, 0.30, 0.10)
	_streams[Sfx.LOOT_OBTAINED] = _make_stream(570.0, 1080.0, 0.44, 0.25, 0.03)
	_streams[Sfx.COMBAT_ENTER] = _make_stream(125.0, 210.0, 0.28, 0.36, 0.25)
	_streams[Sfx.BOSS_ENCOUNTER] = _make_stream(82.0, 42.0, 0.62, 0.48, 0.22)
	_streams[Sfx.EVENT] = _make_stream(310.0, 470.0, 0.34, 0.22, 0.06)
	_streams[Sfx.TREASURE] = _make_stream(520.0, 1120.0, 0.48, 0.28, 0.02)
	_streams[Sfx.ELITE] = _make_stream(115.0, 68.0, 0.46, 0.42, 0.20)
	_streams[Sfx.BIOME_ENTER] = _make_stream(190.0, 430.0, 0.52, 0.24, 0.08)
	_streams[Sfx.SYNERGY_ACTIVATED] = _make_stream(420.0, 860.0, 0.28, 0.24, 0.03)
	_streams[Sfx.EPIC_REVEAL] = _make_stream(540.0, 1180.0, 0.42, 0.27, 0.01)
	_streams[Sfx.BOSS_REWARD] = _make_stream(180.0, 720.0, 0.58, 0.3, 0.04)
	_streams[Sfx.SKILL_READY] = _make_stream(620.0, 1180.0, 0.30, 0.27, 0.01)
	_streams[Sfx.EMBER_SLASH] = _make_stream(480.0, 82.0, 0.34, 0.46, 0.18)
	_streams[Sfx.ASHEN_GUARD] = _make_stream(190.0, 340.0, 0.38, 0.34, 0.08)
	_streams[Sfx.SECOND_WIND] = _make_stream(330.0, 820.0, 0.46, 0.27, 0.03)
	_streams[Sfx.SKILL_AUGMENT_SELECTED] = _make_stream(440.0, 1020.0, 0.38, 0.28, 0.02)
	_streams[Sfx.CODEX_DISCOVERED] = _make_stream(360.0, 760.0, 0.34, 0.22, 0.01)
	_streams[Sfx.TUTORIAL_OPEN] = _make_stream(420.0, 650.0, 0.22, 0.16, 0.01)
	_streams[Sfx.VICTORY] = _make_stream(390.0, 900.0, 0.70, 0.30, 0.02)
	_streams[Sfx.DEFEAT] = _make_stream(230.0, 72.0, 0.62, 0.34, 0.08)


func _make_stream(start_frequency: float, end_frequency: float, duration: float, amplitude: float, noise_mix: float) -> AudioStreamWAV:
	var sample_count: int = maxi(1, int(SAMPLE_RATE * duration))
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(sample_count * 2)
	var phase: float = 0.0
	for index in sample_count:
		var progress: float = float(index) / float(sample_count)
		var frequency: float = lerpf(start_frequency, end_frequency, progress)
		phase += TAU * frequency / SAMPLE_RATE
		var tone: float = sin(phase)
		var pseudo_random: float = fposmod(sin(float(index) * 12.9898) * 43758.5453, 1.0)
		var noise: float = pseudo_random * 2.0 - 1.0
		var attack: float = minf(1.0, progress / 0.035)
		var envelope: float = attack * pow(1.0 - progress, 2.0)
		var sample: int = clampi(int(32767.0 * amplitude * envelope * lerpf(tone, noise, noise_mix)), -32768, 32767)
		pcm[index * 2] = sample & 0xff
		pcm[index * 2 + 1] = (sample >> 8) & 0xff

	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream

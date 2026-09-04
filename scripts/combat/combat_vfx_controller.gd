class_name CombatVFXController
extends Control

const NORMAL_DEATH_DURATION := 0.34
const ELITE_DEATH_DURATION := 0.42
const BOSS_DEATH_DURATION := 0.62
const PLAYER_DEATH_DURATION := 0.4

var _player_visual: Control
var _enemy_visual: Control
var _is_elite: bool = false
var _is_boss: bool = false
var _enemy_name: String = "ENEMIGO"
var _slash: Line2D
var _slash_trail: Line2D
var _ring: Line2D
var _veil: ColorRect
var _badge: Label
var _badge_tween: Tween


func setup(
	player_visual: Control,
	enemy_visual: Control,
	enemy_name: String,
	is_elite: bool,
	is_boss: bool,
) -> void:
	_player_visual = player_visual
	_enemy_visual = enemy_visual
	_enemy_name = enemy_name
	_is_elite = is_elite
	_is_boss = is_boss
	_ensure_nodes()
	_reset_visual(_player_visual)
	_reset_visual(_enemy_visual)


func play_entrance(pyre_emphasis: bool = false) -> void:
	if not _valid_targets():
		return
	if pyre_emphasis:
		show_badge("PYRE HEART", VisualTheme.EMBER)
		_show_ring(_player_visual, VisualTheme.EMBER, 0.34)
	if SettingsManager.reduce_motion:
		_reset_visual(_enemy_visual)
		return
	var duration: float = 0.24
	if _is_elite:
		duration = 0.34
		show_badge("ÉLITE · %s" % _enemy_name.to_upper(), VisualTheme.ELITE)
	if _is_boss:
		duration = 0.68
		_show_ring(_enemy_visual, VisualTheme.BOSS, 0.58)
		_show_veil(_enemy_visual, Color(0.62, 0.12, 0.08, 0.13), 0.42)
		show_badge("JEFE · %s" % _enemy_name.to_upper(), VisualTheme.BOSS)
	_enemy_visual.pivot_offset = _enemy_visual.size * 0.5
	_enemy_visual.modulate = Color(0.45, 0.38, 0.4, 0.0)
	_enemy_visual.scale = Vector2(0.82, 0.82) if _is_boss else Vector2(0.94, 0.94)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_enemy_visual, "modulate", Color.WHITE, duration)
	tween.tween_property(_enemy_visual, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished


func player_attack(burning: bool = false) -> void:
	player_attack_target(_enemy_visual, burning)


func player_attack_target(target_visual: Control, burning: bool = false, critical: bool = false) -> void:
	var hit_color: Color = Color(1.42, 0.78, 0.48, 1.0) if critical else (Color(1.25, 0.64, 0.42, 1.0) if burning else Color(1.18, 0.68, 0.58, 1.0))
	_impact_flash(target_visual, hit_color)
	_show_basic_slash(target_visual, VisualTheme.EMBER_BRIGHT if burning else Color("ffe3bd"))
	_show_ring(target_visual, VisualTheme.EMBER_BRIGHT if burning else Color("ffd58a"), 0.16 if burning else 0.11)
	if critical:
		_show_ring(target_visual, VisualTheme.EMBER_BRIGHT, 0.2)


func enemy_attack(mitigation_label: String = "", retaliation: bool = false) -> void:
	enemy_attack_from(_enemy_visual, mitigation_label, retaliation)


func enemy_attack_from(source_visual: Control, mitigation_label: String = "", retaliation: bool = false) -> void:
	enemy_attack_target_from(source_visual, _player_visual, mitigation_label, retaliation)


func enemy_attack_target_from(
	source_visual: Control,
	target_visual: Control,
	mitigation_label: String = "",
	retaliation: bool = false,
) -> void:
	if not is_instance_valid(target_visual):
		return
	if not mitigation_label.is_empty():
		show_badge(mitigation_label, VisualTheme.EVENT)
		_show_ring(target_visual, VisualTheme.EVENT, 0.26)
		_show_veil(target_visual, Color(0.42, 0.39, 0.36, 0.24), 0.24)
	_impact_flash(target_visual, Color(1.18, 0.62, 0.56, 1.0))
	if retaliation:
		_impact_flash(source_visual, Color(1.18, 0.58, 0.34, 1.0))


func ember_slash(execution: bool = false) -> void:
	ember_slash_target(_enemy_visual, execution)


func ember_slash_target(target_visual: Control, execution: bool = false, critical: bool = false) -> void:
	if execution or critical:
		show_badge("EJECUCIÓN" if execution else "CRÍTICO", VisualTheme.EMBER_BRIGHT)
	_show_slash(target_visual)
	_impact_flash(target_visual, Color(1.5, 0.82, 0.38, 1.0) if critical else Color(1.35, 0.68, 0.32, 1.0))
	_show_ring(target_visual, VisualTheme.EMBER_BRIGHT, 0.22 if critical else 0.18)


func show_damage_number(
	target_visual: Control,
	amount: int,
	critical: bool = false,
	healing: bool = false,
	color: Color = Color.TRANSPARENT,
	delay: float = 0.0,
) -> void:
	if amount <= 0 or not is_instance_valid(target_visual):
		return
	_ensure_nodes()
	var number := Label.new()
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.z_index = 40
	number.text = "%s%d" % ["+" if healing else "-", amount]
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var resolved_color: Color = color
	if resolved_color.a <= 0.0:
		resolved_color = VisualTheme.HEAL if healing else (VisualTheme.EMBER_BRIGHT if critical else Color("fff0df"))
	number.add_theme_color_override("font_color", resolved_color)
	number.add_theme_color_override("font_outline_color", Color(0.055, 0.025, 0.02, 0.96))
	number.add_theme_constant_override("outline_size", 7 if critical else 5)
	number.add_theme_font_size_override("font_size", 48 if critical else (36 if healing else 32))
	var rect: Rect2 = _rect_in_layer(target_visual)
	number.position = rect.position + Vector2(rect.size.x * 0.5 - 92.0, rect.size.y * 0.35 - 32.0)
	number.size = Vector2(184.0, 64.0)
	number.pivot_offset = number.size * 0.5
	number.scale = Vector2(0.72, 0.72) if critical else Vector2(0.86, 0.86)
	number.modulate.a = 0.0 if delay > 0.0 else 1.0
	add_child(number)
	if SettingsManager.reduce_motion:
		number.modulate.a = 1.0
		var reduced_tween: Tween = create_tween()
		reduced_tween.tween_interval(0.28 + delay)
		reduced_tween.tween_property(number, "modulate:a", 0.0, 0.08)
		reduced_tween.tween_callback(number.queue_free)
		return
	var tween: Tween = create_tween().set_parallel(true)
	if delay > 0.0:
		tween.tween_property(number, "modulate:a", 1.0, 0.04).set_delay(delay)
	tween.tween_property(number, "position:y", number.position.y - (62.0 if critical else 48.0), 0.46).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(number, "scale", Vector2.ONE, 0.16).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(number, "modulate:a", 0.0, 0.16).set_delay(delay + 0.34)
	tween.chain().tween_callback(number.queue_free)


func status_tick(target_visual: Control, is_damage: bool) -> void:
	if not is_instance_valid(target_visual):
		return
	if is_damage:
		_impact_flash(target_visual, Color(1.12, 0.48, 0.28, 1.0))
	else:
		_show_ring(target_visual, VisualTheme.HEAL, 0.2)


func guard_activation() -> void:
	show_badge("GUARDIA ACTIVA", VisualTheme.EVENT)
	_show_ring(_player_visual, VisualTheme.EVENT, 0.3)
	await _emphasize(_player_visual, Color(0.72, 0.79, 1.12, 1.0), 0.28)


func heal(amount: int, defense_bonus: int = 0) -> void:
	var badge_text: String = "+%d VIDA" % amount
	if defense_bonus > 0:
		badge_text += " · DEFENSA +%d" % defense_bonus
	show_badge(badge_text, VisualTheme.HEAL)
	_show_ring(_player_visual, VisualTheme.HEAL, 0.32)
	show_damage_number(_player_visual, amount, false, true)
	await _emphasize(_player_visual, Color(0.68, 1.08, 0.76, 1.0), 0.3)


func show_last_ember(active: bool) -> void:
	show_badge("LAST EMBER ACTIVO" if active else "LAST EMBER DISIPADO", VisualTheme.DANGER if active else VisualTheme.TEXT_SECONDARY)


func show_secondary(text: String, color: Color) -> void:
	if text.is_empty():
		return
	show_badge(text, color)


func boss_telegraph(target_visual: Control, text: String, accent: Color) -> void:
	show_badge(text, accent)
	_show_ring(target_visual, accent, 0.3)
	await _emphasize(target_visual, accent.lightened(0.28), 0.24)


func boss_phase_transition(target_visual: Control, phase_text: String, accent: Color) -> void:
	show_badge(phase_text, accent)
	_show_ring(target_visual, accent, 0.42)
	_show_veil(target_visual, Color(accent.r, accent.g, accent.b, 0.18), 0.28)
	await _emphasize(target_visual, accent.lightened(0.22), 0.32)


func boss_summon(boss_visual: Control, add_visuals: Array[Control], accent: Color) -> void:
	show_badge("CALL EMBERS · INVOCACIÓN", accent)
	_show_ring(boss_visual, accent, 0.38)
	if add_visuals.is_empty():
		return
	if SettingsManager.reduce_motion:
		for add_visual: Control in add_visuals:
			_reset_visual(add_visual)
		return
	var tween: Tween = create_tween().set_parallel(true)
	for add_visual: Control in add_visuals:
		if not is_instance_valid(add_visual):
			continue
		add_visual.pivot_offset = add_visual.size * 0.5
		add_visual.modulate = Color(accent.r, accent.g, accent.b, 0.0)
		add_visual.scale = Vector2(0.82, 0.82)
		tween.tween_property(add_visual, "modulate", Color.WHITE, 0.28)
		tween.tween_property(add_visual, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished


func boss_add_cleanup(add_visuals: Array[Control]) -> void:
	if add_visuals.is_empty():
		return
	if SettingsManager.reduce_motion:
		for add_visual: Control in add_visuals:
			if is_instance_valid(add_visual):
				add_visual.hide()
		return
	var tween: Tween = create_tween().set_parallel(true)
	for add_visual: Control in add_visuals:
		if is_instance_valid(add_visual):
			tween.tween_property(add_visual, "modulate:a", 0.0, 0.18)
	await tween.finished
	for add_visual: Control in add_visuals:
		if is_instance_valid(add_visual):
			add_visual.hide()


func enemy_death(absorb_to_player: bool = false) -> void:
	await enemy_death_target(_enemy_visual, get_enemy_death_duration(), _is_boss, absorb_to_player)


func enemy_death_target(target_visual: Control, duration: float, boss_mass: bool = false, absorb_to_player: bool = false) -> void:
	if not is_instance_valid(target_visual):
		return
	if absorb_to_player:
		_show_ring(_player_visual, VisualTheme.HEAL, duration)
	if SettingsManager.reduce_motion:
		target_visual.modulate = Color(0.28, 0.25, 0.27, 0.35)
		return
	target_visual.pivot_offset = target_visual.size * 0.5
	var death_factor: Vector2 = Vector2(0.9, 0.82) if not boss_mass else Vector2(0.94, 0.9)
	var target_scale: Vector2 = target_visual.scale * death_factor
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(target_visual, "modulate", Color(0.24, 0.2, 0.22, 0.0), duration)
	tween.tween_property(target_visual, "scale", target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if not boss_mass:
		tween.tween_property(target_visual, "rotation", 0.035, duration)
	await tween.finished


func player_death() -> void:
	if not is_instance_valid(_player_visual):
		return
	if SettingsManager.reduce_motion:
		_player_visual.modulate = Color(0.3, 0.27, 0.29, 0.45)
		return
	_player_visual.pivot_offset = _player_visual.size * 0.5
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_player_visual, "modulate", Color(0.28, 0.24, 0.27, 0.18), PLAYER_DEATH_DURATION)
	tween.tween_property(_player_visual, "scale", Vector2(0.92, 0.84), PLAYER_DEATH_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_player_visual, "rotation", -0.045, PLAYER_DEATH_DURATION)
	await tween.finished


func get_enemy_death_duration() -> float:
	if SettingsManager.reduce_motion:
		return 0.0
	if _is_boss:
		return BOSS_DEATH_DURATION
	if _is_elite:
		return ELITE_DEATH_DURATION
	return NORMAL_DEATH_DURATION


func get_player_death_duration() -> float:
	return 0.0 if SettingsManager.reduce_motion else PLAYER_DEATH_DURATION


func show_badge(text: String, color: Color) -> void:
	_ensure_nodes()
	if is_instance_valid(_badge_tween):
		_badge_tween.kill()
	_badge.text = text
	_badge.modulate = color
	_badge.modulate.a = 1.0
	_badge.show()
	_badge_tween = create_tween()
	_badge_tween.tween_interval(0.3)
	_badge_tween.tween_property(_badge, "modulate:a", 0.0, 0.12)
	_badge_tween.tween_callback(_badge.hide)


func _impact_flash(target: Control, color: Color) -> void:
	if not is_instance_valid(target):
		return
	target.pivot_offset = target.size * 0.5
	var base_scale: Vector2 = target.scale
	var tween: Tween = create_tween().set_parallel(true)
	target.modulate = color
	tween.tween_property(target, "modulate", Color.WHITE, 0.12).set_delay(0.045)
	tween.tween_property(target, "scale", base_scale * Vector2(1.055, 0.945), 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(target, "scale", base_scale, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _essential_flash(target: Control, color: Color) -> void:
	target.modulate = color
	var tween: Tween = create_tween()
	tween.tween_property(target, "modulate", Color.WHITE, 0.1)
	await tween.finished


func _emphasize(target: Control, color: Color, duration: float) -> void:
	if not is_instance_valid(target):
		return
	if SettingsManager.reduce_motion:
		await _essential_flash(target, color)
		return
	target.pivot_offset = target.size * 0.5
	target.modulate = color
	target.scale = Vector2(0.96, 0.96)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(target, "modulate", Color.WHITE, duration)
	tween.tween_property(target, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished


func _show_slash(target: Control) -> void:
	if SettingsManager.reduce_motion or not is_instance_valid(target):
		return
	var rect: Rect2 = _rect_in_layer(target)
	var slash_points := PackedVector2Array([
		rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.76),
		rect.position + Vector2(rect.size.x * 0.48, rect.size.y * 0.37),
		rect.position + Vector2(rect.size.x * 0.88, rect.size.y * 0.18),
	])
	_slash.points = slash_points
	_slash.width = 9.0
	_slash.default_color = Color("fff1a6")
	_slash_trail.points = slash_points
	_slash_trail.width = 30.0
	_slash_trail.default_color = Color(1.0, 0.16, 0.025, 0.68)
	_slash.modulate = Color.WHITE
	_slash_trail.modulate = Color.WHITE
	_slash_trail.show()
	_slash.show()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_slash, "modulate:a", 0.0, 0.24)
	tween.tween_property(_slash_trail, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(_slash.hide)
	tween.chain().tween_callback(_slash_trail.hide)


func _show_basic_slash(target: Control, color: Color) -> void:
	if SettingsManager.reduce_motion or not is_instance_valid(target):
		return
	var rect: Rect2 = _rect_in_layer(target)
	_slash.points = PackedVector2Array([
		rect.position + Vector2(rect.size.x * 0.27, rect.size.y * 0.68),
		rect.position + Vector2(rect.size.x * 0.73, rect.size.y * 0.31),
	])
	_slash.width = 6.0
	_slash.default_color = color
	_slash.modulate = Color.WHITE
	_slash.show()
	var tween: Tween = create_tween()
	tween.tween_property(_slash, "modulate:a", 0.0, 0.16)
	tween.tween_callback(_slash.hide)


func _show_ring(target: Control, color: Color, duration: float) -> void:
	if SettingsManager.reduce_motion or not is_instance_valid(target):
		return
	var rect: Rect2 = _rect_in_layer(target)
	var radius: float = maxf(34.0, minf(rect.size.x, rect.size.y) * 0.42)
	var points := PackedVector2Array()
	for index: int in 25:
		var angle: float = TAU * float(index) / 24.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	_ring.points = points
	_ring.position = rect.get_center()
	_ring.default_color = color
	_ring.modulate = Color.WHITE
	_ring.scale = Vector2(0.88, 0.88)
	_ring.show()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_ring, "scale", Vector2(1.1, 1.1), duration)
	tween.tween_property(_ring, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(_ring.hide)


func _show_veil(target: Control, color: Color, duration: float) -> void:
	if SettingsManager.reduce_motion or not is_instance_valid(target):
		return
	var rect: Rect2 = _rect_in_layer(target)
	_veil.position = rect.position
	_veil.size = rect.size
	_veil.color = color
	_veil.modulate = Color.WHITE
	_veil.show()
	var tween: Tween = create_tween()
	tween.tween_property(_veil, "modulate:a", 0.0, duration)
	tween.tween_callback(_veil.hide)


func _rect_in_layer(target: Control) -> Rect2:
	var global_rect: Rect2 = target.get_global_rect()
	var local_position: Vector2 = get_global_transform().affine_inverse() * global_rect.position
	return Rect2(local_position, global_rect.size)


func _valid_targets() -> bool:
	return is_instance_valid(_player_visual) and is_instance_valid(_enemy_visual)


func _reset_visual(target: Control) -> void:
	if not is_instance_valid(target):
		return
	target.modulate = Color.WHITE
	target.scale = Vector2.ONE
	target.rotation = 0.0


func _ensure_nodes() -> void:
	if _slash != null:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slash = Line2D.new()
	_slash.name = "EmberSlash"
	_slash.width = 7.0
	_slash.default_color = VisualTheme.EMBER_BRIGHT
	_slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_slash.end_cap_mode = Line2D.LINE_CAP_ROUND
	_slash.hide()
	add_child(_slash)
	_slash_trail = Line2D.new()
	_slash_trail.name = "EmberSlashTrail"
	_slash_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_slash_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_slash_trail.hide()
	add_child(_slash_trail)
	move_child(_slash_trail, _slash.get_index())
	_ring = Line2D.new()
	_ring.name = "EffectRing"
	_ring.width = 4.0
	_ring.closed = true
	_ring.hide()
	add_child(_ring)
	_veil = ColorRect.new()
	_veil.name = "MitigationVeil"
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.hide()
	add_child(_veil)
	_badge = Label.new()
	_badge.name = "SecondaryBadge"
	_badge.anchor_left = 0.5
	_badge.anchor_top = 0.34
	_badge.anchor_right = 0.5
	_badge.anchor_bottom = 0.34
	_badge.offset_left = -150.0
	_badge.offset_top = -21.0
	_badge.offset_right = 150.0
	_badge.offset_bottom = 21.0
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_theme_font_size_override("font_size", 18)
	_badge.add_theme_stylebox_override("normal", VisualTheme.elevated_panel_style(Color(0.07, 0.055, 0.06, 0.72), VisualTheme.BORDER, 1, 8))
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.hide()
	add_child(_badge)

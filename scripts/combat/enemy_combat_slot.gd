class_name EnemyCombatSlot
extends Control

signal target_requested(requested_actor: CombatActor)

enum HUDMode {
	FULL,
	MINION,
	HIDDEN,
}

var actor: CombatActor
var character_view: CombatCharacterView
var _hud: PanelContainer
var _name_label: Label
var _role_label: Label
var _health_label: Label
var _health_bar: ProgressBar
var _stats_label: Label
var _status_row: HBoxContainer
var _intent_badge: AshenBadge
var _accent: Color = VisualTheme.EMBER_BRIGHT
var _selected: bool = false
var _hovered: bool = false
var _target_input_enabled: bool = false
var _hud_mode: HUDMode = HUDMode.FULL


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	resized.connect(queue_redraw)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_build_view()
	_build_hud()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if _target_input_enabled and _hovered and not _selected and actor != null and actor.is_targetable():
		var hover_color: Color = _accent
		hover_color.a = 0.22
		draw_rect(Rect2(Vector2(6.0, 6.0), size - Vector2(12.0, 12.0)), hover_color, false, 2.0)
	if not _selected:
		return
	var marker_color: Color = VisualTheme.EMBER_BRIGHT
	var ground_center := Vector2(size.x * 0.5, size.y * 0.705)
	draw_arc(ground_center, minf(42.0, size.x * 0.2), 0.05, PI - 0.05, 22, marker_color, 4.0, true)
	draw_arc(ground_center, minf(42.0, size.x * 0.2), PI + 0.05, TAU - 0.05, 22, Color(marker_color.r, marker_color.g, marker_color.b, 0.42), 2.0, true)
	var pointer_center := Vector2(size.x * 0.5, size.y * 0.22)
	var pointer := PackedVector2Array([
		pointer_center + Vector2(-10.0, -5.0),
		pointer_center + Vector2(10.0, -5.0),
		pointer_center + Vector2(0.0, 8.0),
	])
	draw_colored_polygon(pointer, marker_color)


func setup(slot_actor: CombatActor, accent: Color, hud_mode: HUDMode = HUDMode.FULL) -> void:
	actor = slot_actor
	_accent = accent
	_hud_mode = hud_mode
	var fallback_kind: StringName = &"boss" if actor.actor_type == CombatActor.ActorType.BOSS else &"normal"
	var fallback_text: String = "MINION" if actor.actor_type == CombatActor.ActorType.MINION else ("JEFE" if actor.actor_type == CombatActor.ActorType.BOSS else "ENEMIGO")
	var visual_accent: Color = actor.visual_data.accent if actor.visual_data != null else VisualTheme.DANGER
	character_view.configure_fallback_presence(fallback_kind, visual_accent, accent)
	character_view.setup_visual(actor.visual_data, fallback_text)
	actor.set_visual_view(character_view)
	_hud.visible = _hud_mode != HUDMode.HIDDEN
	# Keep combat focused on silhouettes and HP instead of card-like metadata.
	_role_label.visible = false
	_stats_label.visible = false
	_status_row.visible = _hud_mode == HUDMode.FULL
	if _hud_mode == HUDMode.MINION:
		_hud.anchor_top = 0.87
	_health_bar.add_theme_stylebox_override("background", VisualTheme.panel_style(Color("0d0b11"), VisualTheme.BORDER_DARK, 1, 5))
	_health_bar.add_theme_stylebox_override("fill", VisualTheme.panel_style(VisualTheme.DANGER, VisualTheme.DANGER, 0, 5))
	update_actor()


func update_actor(effective_attack: int = -1, effective_defense: int = -1) -> void:
	if actor == null:
		return
	if not actor.is_targetable():
		_selected = false
	_name_label.text = actor.display_name.to_upper()
	_role_label.text = _get_role_name(actor)
	_health_label.text = "%d / %d" % [actor.get_current_hp(), actor.get_max_hp()]
	_health_bar.max_value = actor.get_max_hp()
	_health_bar.value = actor.get_current_hp()
	_stats_label.text = "ATQ %d  ·  DEF %d" % [
		actor.get_attack() if effective_attack < 0 else effective_attack,
		actor.get_defense() if effective_defense < 0 else effective_defense,
	]
	if _hud_mode == HUDMode.FULL:
		_refresh_statuses()
	_hud.modulate.a = 0.48 if not actor.is_alive() else 1.0
	_apply_hud_style()
	queue_redraw()


func set_intent(intent: EnemyIntent) -> void:
	if _intent_badge == null:
		return
	_intent_badge.visible = intent != null and intent.is_valid and actor != null and actor.is_alive()
	if not _intent_badge.visible:
		return
	_intent_badge.configure(
		intent.get_icon_id(),
		intent.get_compact_text(),
		_intent_variant(intent),
		AshenIcon.DisplaySize.SMALL,
		intent.get_compact_counter(),
	)


func set_selected(value: bool) -> void:
	var next_value: bool = value and actor != null and actor.is_targetable()
	if _selected == next_value:
		return
	_selected = next_value
	character_view.set_targeted(_selected)
	_name_label.text = actor.display_name.to_upper()
	_apply_hud_style()
	queue_redraw()


func is_selected() -> bool:
	return _selected


func set_target_input_enabled(value: bool) -> void:
	_target_input_enabled = value
	if not value:
		_hovered = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not _target_input_enabled or actor == null or not actor.is_targetable():
		return
	var requested: bool = false
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		requested = mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		# El combate es deliberadamente single-touch: dedos secundarios no cambian objetivo.
		requested = touch_event.index == 0 and touch_event.pressed
	if requested:
		target_requested.emit(actor)
		accept_event()


func _on_mouse_entered() -> void:
	_hovered = _target_input_enabled
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()


func _apply_hud_style() -> void:
	if _hud == null:
		return
	var border_color: Color = VisualTheme.EMBER_BRIGHT if _selected else VisualTheme.DANGER
	var border_width: int = 2 if _selected else 0
	var background: Color = Color(0.095, 0.055, 0.025, 0.82) if _selected else Color(0.025, 0.02, 0.03, 0.68)
	var style: StyleBoxFlat = CombatStage.hud_style(background, border_color, border_width)
	style.content_margin_left = 6.0
	style.content_margin_top = 4.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 4.0
	_hud.add_theme_stylebox_override("panel", style)


func _build_view() -> void:
	character_view = CombatCharacterView.new()
	character_view.name = "CharacterView"
	character_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	character_view.anchor_bottom = 0.86
	var static_art: TextureRect = TextureRect.new()
	static_art.name = "StaticArt"
	static_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	static_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	static_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	static_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_view.add_child(static_art)
	var fallback: Label = Label.new()
	fallback.name = "FallbackLabel"
	fallback.anchor_left = 0.2
	fallback.anchor_top = 0.68
	fallback.anchor_right = 0.8
	fallback.anchor_bottom = 0.9
	fallback.text = "ENEMIGO"
	fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback.add_theme_font_size_override("font_size", 12)
	fallback.add_theme_color_override("font_color", VisualTheme.DANGER)
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_view.add_child(fallback)
	add_child(character_view)
	_intent_badge = AshenBadge.new()
	_intent_badge.name = "IntentBadge"
	_intent_badge.z_index = 6
	_intent_badge.anchor_left = 0.06
	_intent_badge.anchor_top = 0.015
	_intent_badge.anchor_right = 0.94
	_intent_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent_badge.visible = false
	add_child(_intent_badge)


func _build_hud() -> void:
	_hud = PanelContainer.new()
	_hud.name = "CompactHUD"
	_hud.z_index = 4
	_hud.anchor_left = 0.05
	_hud.anchor_top = 0.845
	_hud.anchor_right = 0.95
	_hud.anchor_bottom = 0.995
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var content: VBoxContainer = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 1)
	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.add_theme_font_size_override("font_size", 12)
	content.add_child(_name_label)
	_role_label = Label.new()
	_role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role_label.add_theme_font_size_override("font_size", VisualTheme.FONT_CAPTION)
	_role_label.add_theme_color_override("font_color", VisualTheme.TEXT_SECONDARY)
	content.add_child(_role_label)
	_health_label = Label.new()
	_health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_label.add_theme_font_size_override("font_size", 12)
	content.add_child(_health_label)
	_health_bar = ProgressBar.new()
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_bar.custom_minimum_size = Vector2(0.0, 9.0)
	_health_bar.show_percentage = false
	content.add_child(_health_bar)
	_stats_label = Label.new()
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", VisualTheme.FONT_CAPTION)
	_stats_label.add_theme_color_override("font_color", VisualTheme.TEXT_SECONDARY)
	content.add_child(_stats_label)
	_status_row = HBoxContainer.new()
	_status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_status_row.add_theme_constant_override("separation", 2)
	content.add_child(_status_row)
	_hud.add_child(content)
	add_child(_hud)


func _refresh_statuses() -> void:
	for child: Node in _status_row.get_children():
		_status_row.remove_child(child)
		child.queue_free()
	var statuses: Array[StatusEffectInstance] = actor.get_statuses()
	var visible_count: int = mini(2, statuses.size())
	for index: int in visible_count:
		var instance: StatusEffectInstance = statuses[index]
		var badge: AshenBadge = AshenBadge.new()
		var variant: AshenBadge.Variant = AshenBadge.Variant.UTILITY
		match instance.data.category:
			StatusEffectData.Category.BUFF:
				variant = AshenBadge.Variant.BUFF
			StatusEffectData.Category.DEBUFF, StatusEffectData.Category.DOT:
				variant = AshenBadge.Variant.DEBUFF
			StatusEffectData.Category.DEFENSE:
				variant = AshenBadge.Variant.DEFENSE
		badge.configure(
			instance.data.icon_id,
			instance.data.display_name.to_upper(),
			variant,
			AshenIcon.DisplaySize.SMALL,
			_status_counter(instance),
		)
		_status_row.add_child(badge)
	if statuses.size() > visible_count:
		var overflow: Label = Label.new()
		overflow.text = "+%d" % (statuses.size() - visible_count)
		_status_row.add_child(overflow)


func _get_role_name(target_actor: CombatActor) -> String:
	if target_actor == null:
		return "ENEMIGO"
	var enemy_data: EnemyData = target_actor.source_data as EnemyData
	if enemy_data == null or enemy_data.ai_profile == null:
		return "ENEMIGO"
	return enemy_data.ai_profile.get_role_name()


func _intent_variant(intent: EnemyIntent) -> AshenBadge.Variant:
	match intent.category:
		EnemyIntent.Category.DEFEND:
			return AshenBadge.Variant.NEUTRAL
		EnemyIntent.Category.SUPPORT:
			return AshenBadge.Variant.HEAL
		EnemyIntent.Category.SUMMON, EnemyIntent.Category.SPECIAL:
			return AshenBadge.Variant.SYNERGY
		_:
			return AshenBadge.Variant.DANGER


func _status_counter(instance: StatusEffectInstance) -> String:
	var parts: Array[String] = []
	if instance.stacks > 1:
		parts.append("×%d" % instance.stacks)
	if instance.data.duration_type != StatusEffectData.DurationType.PERMANENT_COMBAT:
		parts.append(str(instance.remaining_duration))
	return " · ".join(parts)

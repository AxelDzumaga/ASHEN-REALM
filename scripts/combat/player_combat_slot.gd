class_name PlayerCombatSlot
extends Control

## Combat Domain M6 — presentación genérica de UN actor del Player Team
## (protagonista o AI_ALLY). Deliberadamente separado de EnemyCombatSlot,
## nunca generalizado a un CombatActorSlot común: EnemyCombatSlot lleva
## conceptos que ningún Player Team actor necesita (intent badge, tap-to-
## target, HUDMode de boss/minion) — forzarlos acá produciría un
## componente lleno de condicionales sin beneficio real (ver handoff M6
## sección 7/8). El panel de skills/energía del protagonista sigue siendo
## su propio sistema separado (skill_panel/energy_bar en combat.gd) — esta
## clase nunca lo toca ni lo reemplaza.
##
## No escribe nada en CombatActor (ese objeto ya no tiene ningún campo de
## presentación) — combat.gd es quien registra
## actor_id -> character_view en su propio _actor_views tras llamar setup().

var actor: CombatActor
var character_view: CombatCharacterView
var _hud: PanelContainer
var _name_label: Label
var _health_label: Label
var _health_bar: ProgressBar
var _status_row: HBoxContainer
var _accent: Color = VisualTheme.EMBER_BRIGHT
var _active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_view()
	_build_hud()


func setup(slot_actor: CombatActor, accent: Color) -> void:
	actor = slot_actor
	_accent = accent
	var is_companion: bool = actor.actor_type == CombatActor.ActorType.COMPANION
	var fallback_kind: StringName = &"companion" if is_companion else &"player"
	var fallback_text: String = "COMPAÑERO" if is_companion else "ASH"
	var visual_accent: Color = actor.visual_data.accent if actor.visual_data != null else VisualTheme.EMBER_BRIGHT
	character_view.configure_fallback_presence(fallback_kind, visual_accent, accent)
	character_view.setup_visual(actor.visual_data, fallback_text)
	_health_bar.add_theme_stylebox_override("background", VisualTheme.panel_style(Color("0d0b11"), VisualTheme.BORDER_DARK, 1, 5))
	_health_bar.add_theme_stylebox_override("fill", VisualTheme.panel_style(VisualTheme.HEAL, VisualTheme.HEAL, 0, 5))
	update_actor()


func update_actor() -> void:
	if actor == null:
		return
	_name_label.text = actor.display_name.to_upper()
	_health_label.text = "%d / %d" % [actor.get_current_hp(), actor.get_max_hp()]
	_health_bar.max_value = actor.get_max_hp()
	_health_bar.value = actor.get_current_hp()
	_refresh_statuses()
	_hud.modulate.a = 0.48 if not actor.is_alive() else 1.0
	_apply_hud_style()
	queue_redraw()


## Combat Domain M6 sección 18 — resalte funcional de turno activo,
## conducido directamente por CombatTurnController.actor_turn_started/
## actor_turn_ended (nunca por un CombatEvent duplicado).
func set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	_apply_hud_style()


func _apply_hud_style() -> void:
	if _hud == null:
		return
	var border_color: Color = VisualTheme.EMBER_BRIGHT if _active else VisualTheme.BORDER_DARK
	var border_width: int = 2 if _active else 0
	var background: Color = Color(0.095, 0.055, 0.025, 0.82) if _active else Color(0.025, 0.02, 0.03, 0.68)
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
	fallback.text = "ASH"
	fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback.add_theme_font_size_override("font_size", 12)
	fallback.add_theme_color_override("font_color", VisualTheme.EMBER_BRIGHT)
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	character_view.add_child(fallback)
	add_child(character_view)


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


func _status_counter(instance: StatusEffectInstance) -> String:
	var parts: Array[String] = []
	if instance.stacks > 1:
		parts.append("×%d" % instance.stacks)
	if instance.data.duration_type != StatusEffectData.DurationType.PERMANENT_COMBAT:
		parts.append(str(instance.remaining_duration))
	return " · ".join(parts)

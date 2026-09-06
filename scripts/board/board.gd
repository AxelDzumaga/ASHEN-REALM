extends Control

const BoardTurnControllerSource = preload("res://scripts/board/board_turn_controller.gd")
const BoardTileResolutionAdapterSource = preload("res://scripts/board/board_tile_resolution_adapter.gd")
const RouteBranchDataSource = preload("res://scripts/board/route_branch_data.gd")

signal pause_requested
signal combat_requested(is_boss: bool, is_elite: bool)
signal event_requested
signal treasure_requested
signal route_destination_selected(destination: int)
signal branch_choice_selected(branch: int)

const COLUMNS := 4
const TILE_HEIGHT := 92
const BOSS_TILE_EXTRA_HEIGHT := 12
const ROW_GAP := 24
const BOARD_VERTICAL_MARGIN := 24
const MOVE_DURATION := 0.18
const ROLL_REVEAL_DELAY := 0.35

@onready var health_label: AshenBadge = %HealthLabel
@onready var attack_label: AshenBadge = %AttackLabel
@onready var defense_label: AshenBadge = %DefenseLabel
@onready var position_label: AshenBadge = %PositionLabel
@onready var run_ash_label: AshenBadge = %RunAshLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var run_level_label: AshenBadge = %RunLevelLabel
@onready var run_xp_bar: ProgressBar = %RunXpBar
@onready var run_xp_label: Label = %RunXpLabel
@onready var dice_result_label: Label = %DiceResultLabel
@onready var event_label: Label = %EventLabel
@onready var board_scroll: ScrollContainer = %BoardScroll
@onready var board_content: Control = %BoardContent
@onready var path_rows: VBoxContainer = %PathRows
@onready var path_lines: PathLines = %PathLines
@onready var player_marker: PanelContainer = %PlayerMarker
@onready var player_marker_icon: AshenIcon = %PlayerMarkerIcon
@onready var roll_button: Button = %RollButton
@onready var return_button: Button = %ReturnButton
@onready var debug_panel: PanelContainer = %DebugPanel
@onready var debug_dice_option: OptionButton = %DebugDiceOption
@onready var debug_force_combat_button: Button = %DebugForceCombatButton
@onready var debug_go_boss_button: Button = %DebugGoBossButton
@onready var debug_damage_button: Button = %DebugDamageButton
@onready var debug_heal_button: Button = %DebugHealButton
@onready var debug_attack_button: Button = %DebugAttackButton
@onready var debug_force_event_button: Button = %DebugForceEventButton
@onready var debug_force_treasure_button: Button = %DebugForceTreasureButton
@onready var debug_force_elite_button: Button = %DebugForceEliteButton
@onready var debug_grant_boon_button: Button = %DebugGrantBoonButton
@onready var biome_label: Label = %BiomeLabel
@onready var biome_rules_label: Label = %BiomeRulesLabel
@onready var synergy_label: Label = %SynergyLabel
@onready var seed_label: Label = %SeedLabel
@onready var biome_banner: PanelContainer = %BiomeBanner
@onready var biome_thumbnail: TextureRect = %BiomeThumbnail
@onready var biome_banner_title: Label = %BiomeBannerTitle
@onready var biome_banner_subtitle: Label = %BiomeBannerSubtitle
@onready var background: ColorRect = %Background

var _dice_roller := DiceRoller.new()
var _turn_controller: RefCounted
var _tile_controls: Array[Control] = []
var _is_moving := false
var _combat_pending := false
var _highlighted_tile_index := -1
var _forced_dice_result := 0
var _has_forced_tile: bool = false
var _forced_tile_type: BoardTileData.TileType = BoardTileData.TileType.EMPTY
var _tile_types: Array[int] = []
var _pending_route_destinations: Array[int] = []
var _pending_route_origin: int = -1


func _ready() -> void:
	if not RunManager.has_active_run():
		RunManager.start_new_run()
	_tile_types = RunManager.current_run.board_tile_sequence
	if _tile_types.is_empty():
		push_error("Board requires a generated tile sequence in RunState.")
		return
	_turn_controller = BoardTurnControllerSource.new(RunManager.current_run, _tile_types, _dice_roller)

	_build_board()
	player_marker.add_theme_stylebox_override("panel", VisualTheme.elevated_panel_style(Color("3b2517"), VisualTheme.EMBER_BRIGHT, 3, 26))
	player_marker_icon.configure(&"ember", VisualTheme.EMBER_BRIGHT, AshenIcon.DisplaySize.MEDIUM)
	dice_result_label.add_theme_stylebox_override("normal", VisualTheme.elevated_panel_style(Color("1e1816"), VisualTheme.EMBER_DARK, 2, 12))
	roll_button.set_meta(&"audio_skip_generic", true)
	roll_button.pressed.connect(_on_roll_button_pressed)
	return_button.pressed.connect(_on_return_button_pressed)
	_setup_debug_tools()
	_update_hud()
	_update_biome_header()
	# Keep the primary action locked until the contextual intro reaches a safe
	# completion point. Android can deliver rapid taps during these awaits.
	roll_button.disabled = true

	await get_tree().process_frame
	_update_path_lines()
	_place_marker_immediately(RunManager.current_run.board_position)
	await _ensure_current_tile_visible()
	_show_biome_intro()
	_show_pending_synergy_announcement()
	var board_intro_resolved: bool = await TutorialManager.request_and_wait(
		TutorialCatalog.BOARD_INTRO, TutorialManager.CONTEXT_BOARD, self,
	)
	if not board_intro_resolved or not is_inside_tree():
		return
	roll_button.disabled = RunManager.current_run.board_locked
	if not roll_button.disabled:
		roll_button.grab_focus()


func _build_board() -> void:
	_tile_controls.resize(_tile_types.size())
	var row_count: int = ceili(float(_tile_types.size()) / COLUMNS)
	var content_height: int = row_count * TILE_HEIGHT + maxi(0, row_count - 1) * ROW_GAP + BOARD_VERTICAL_MARGIN + BOSS_TILE_EXTRA_HEIGHT
	board_content.custom_minimum_size = Vector2(0, content_height)

	for row_index in row_count:
		var row: HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 34)
		path_rows.add_child(row)

		var first_index := row_index * COLUMNS
		var last_index := mini(first_index + COLUMNS, _tile_types.size())
		var row_indices: Array[int] = []
		for tile_index in range(first_index, last_index):
			row_indices.append(tile_index)
		if row_index % 2 == 1:
			row_indices.reverse()

		for tile_index in row_indices:
			var tile := _create_tile(tile_index, _tile_types[tile_index])
			row.add_child(tile)
			_tile_controls[tile_index] = tile


func _create_tile(index: int, tile_type: int) -> PanelContainer:
	var tile: PanelContainer = PanelContainer.new()
	tile.custom_minimum_size = Vector2(112, 104 if tile_type == BoardTileData.TileType.BOSS else TILE_HEIGHT)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.focus_mode = Control.FOCUS_ALL
	tile.gui_input.connect(_on_tile_gui_input.bind(index))

	var border_width: int = _tile_border_width(tile_type)
	var radius: int = 16 if tile_type == BoardTileData.TileType.BOSS else 34
	var style: StyleBoxFlat = VisualTheme.elevated_panel_style(_tile_color(tile_type).darkened(0.28), _tile_border_color(tile_type), border_width, radius)
	tile.add_theme_stylebox_override("panel", style)

	var content: VBoxContainer = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 1)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(content)
	var icon: AshenIcon = AshenIcon.new()
	icon.configure(_tile_icon_id(tile_type), _tile_border_color(tile_type), AshenIcon.DisplaySize.LARGE if tile_type == BoardTileData.TileType.BOSS else AshenIcon.DisplaySize.MEDIUM)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(icon)
	var number_label: Label = Label.new()
	number_label.text = "%02d" % (index + 1)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.add_theme_font_size_override("font_size", 12)
	number_label.add_theme_color_override("font_color", VisualTheme.TEXT_SECONDARY)
	number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(number_label)
	var type_label: Label = Label.new()
	type_label.text = _tile_name(tile_type)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 15 if tile_type == BoardTileData.TileType.BOSS else 13)
	type_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	type_label.add_theme_constant_override("shadow_offset_y", 2)
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(type_label)
	var state_label: Label = Label.new()
	state_label.name = "StateMark"
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	state_label.add_theme_font_size_override("font_size", VisualTheme.FONT_CAPTION)
	state_label.add_theme_color_override("font_color", VisualTheme.TEXT_SECONDARY)
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(state_label)
	return tile


func _tile_color(type: int) -> Color:
	match type:
		BoardTileData.TileType.COMBAT:
			return VisualTheme.COMBAT.darkened(0.45)
		BoardTileData.TileType.HEAL:
			return VisualTheme.HEAL_DARK
		BoardTileData.TileType.BOSS:
			return VisualTheme.DANGER_DARK
		BoardTileData.TileType.EVENT:
			return VisualTheme.EVENT.darkened(0.52)
		BoardTileData.TileType.TREASURE:
			return VisualTheme.TREASURE.darkened(0.58)
		BoardTileData.TileType.ELITE:
			return VisualTheme.ELITE.darkened(0.5)
		_:
			return VisualTheme.PANEL_RAISED


func _tile_border_color(type: int) -> Color:
	match type:
		BoardTileData.TileType.COMBAT:
			return VisualTheme.COMBAT
		BoardTileData.TileType.HEAL:
			return Color("b87961")
		BoardTileData.TileType.BOSS:
			return VisualTheme.BOSS
		BoardTileData.TileType.EVENT:
			return VisualTheme.EVENT
		BoardTileData.TileType.TREASURE:
			return VisualTheme.TREASURE
		BoardTileData.TileType.ELITE:
			return VisualTheme.ELITE
		_:
			return VisualTheme.BORDER


func _tile_border_width(type: int) -> int:
	match type:
		BoardTileData.TileType.BOSS:
			return 5
		BoardTileData.TileType.ELITE:
			return 4
		_:
			return 2


func _tile_name(type: int) -> String:
	match type:
		BoardTileData.TileType.COMBAT:
			return "COMBATE"
		BoardTileData.TileType.HEAL:
			return "CURACIÓN"
		BoardTileData.TileType.BOSS:
			return "JEFE"
		BoardTileData.TileType.EVENT:
			return "EVENTO"
		BoardTileData.TileType.TREASURE:
			return "TESORO"
		BoardTileData.TileType.ELITE:
			return "ÉLITE"
		_:
			return "CAMINO"


func _tile_icon_id(type: int) -> StringName:
	match type:
		BoardTileData.TileType.COMBAT:
			return &"combat"
		BoardTileData.TileType.HEAL:
			return &"heal"
		BoardTileData.TileType.BOSS:
			return &"boss"
		BoardTileData.TileType.EVENT:
			return &"event"
		BoardTileData.TileType.TREASURE:
			return &"treasure"
		BoardTileData.TileType.ELITE:
			return &"elite"
		_:
			return &"ash"


func _on_roll_button_pressed() -> void:
	if _is_moving or RunManager.current_run.board_locked or _turn_controller == null or _turn_controller.is_turn_locked():
		return

	var plan: Dictionary = _turn_controller.request_roll(_forced_dice_result)
	if plan.is_empty():
		push_error("Board turn controller rejected the roll request.")
		return
	var result: int = int(plan["roll"])
	AudioManager.play_event(AudioManager.AudioEvent.DICE_ROLL)
	dice_result_label.text = "DADO  ·  %d" % result
	_animate_dice_result()
	event_label.text = "Resultado confirmado."
	_is_moving = true
	roll_button.disabled = true
	return_button.disabled = true
	await get_tree().create_timer(ROLL_REVEAL_DELAY).timeout
	AudioManager.play_event(AudioManager.AudioEvent.DICE_LAND)
	var destination: int = int(plan["destinations"][0])
	event_label.text = "Avanzando %d casillas..." % (destination - RunManager.current_run.board_position)
	await _move_player_to(destination)
	await _ensure_current_tile_visible()
	var resolution: Dictionary = _turn_controller.request_tile_resolution()
	if resolution.is_empty():
		push_error("Board turn controller rejected tile resolution.")
	else:
		await _resolve_current_tile(int(resolution["tile_type"]))
	_turn_controller.complete_resolution()
	_is_moving = false
	roll_button.disabled = RunManager.current_run.board_locked or _combat_pending
	return_button.disabled = _combat_pending
	if not roll_button.disabled:
		roll_button.grab_focus()


func _move_player_to(target_index: int) -> void:
	if _turn_controller == null or _turn_controller.get_selected_destination() != target_index:
		push_error("Rejected invalid route destination: %d" % target_index)
		return
	while true:
		if int(_turn_controller.get("state")) == BoardTurnControllerSource.State.ROUTE_DECISION:
			await _handle_fork_pause()
			if int(_turn_controller.get("state")) != BoardTurnControllerSource.State.MOVING:
				break
			continue
		if not _turn_controller.has_pending_steps():
			break
		var tile_index: int = _turn_controller.advance_one_step()
		if tile_index < 0:
			push_error("Board turn controller failed during movement.")
			return
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(player_marker, "position", _marker_position(tile_index), MOVE_DURATION)
		await tween.finished
		AudioManager.play_event(AudioManager.AudioEvent.BOARD_STEP)
		_pulse_marker()
		_update_position_label()
		_highlight_current_tile(tile_index)
		board_scroll.ensure_control_visible(_tile_controls[tile_index])


## Intercepción obligatoria: MOVE llegó a un FORK sin carril elegido. Pausa
## la animación (no consume ni agrega movimiento), presenta Ruta A/B con
## Partial Information y espera la elección antes de que el loop de arriba
## siga consumiendo los pasos restantes del mismo roll.
func _handle_fork_pause() -> void:
	var fork_index: int = int(_turn_controller.get("_pending_fork_index"))
	var branch_data: RefCounted = RunManager.current_run.route_branches.get(fork_index)
	if branch_data == null:
		push_error("Fork reached without generated branch data at index %d" % fork_index)
		_turn_controller.abort_turn()
		return
	var chosen: int = await _request_branch_choice(fork_index, branch_data)
	_turn_controller.choose_branch(chosen)


func _request_route_choice(destinations: Array[int], origin: int) -> int:
	_pending_route_destinations = destinations.duplicate()
	_pending_route_origin = origin
	_refresh_path_states()
	event_label.text = "ELEGÍ TU DESTINO\nTocá una casilla marcada"
	TelemetryManager.track_route_choice_shown(
		RunManager.current_run,
		_tile_type_key(_tile_types[destinations[0]]), _tile_type_key(_tile_types[destinations[1]]),
		destinations[0] - origin, destinations[1] - origin,
	)
	await get_tree().process_frame
	board_scroll.ensure_control_visible(_tile_controls[destinations[1]])
	var selected: int = await route_destination_selected
	_pending_route_destinations.clear()
	_pending_route_origin = -1
	_refresh_path_states()
	event_label.text = "Ruta elegida · avanzando %d casillas..." % (selected - origin)
	return selected


## Partial Information aprobada: identidad + peligro + enfoque + primer nodo
## visible, sin revelar las 4 casillas completas de ninguna ruta. No es un
## popup de arte final — controles procedurales simples, consistentes con el
## resto del HUD de Board2D.
func _request_branch_choice(fork_index: int, branch_data: RefCounted) -> int:
	event_label.text = "BIFURCACIÓN\nElegí tu ruta"
	var overlay := PanelContainer.new()
	overlay.name = "RouteChoiceOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	overlay.add_theme_stylebox_override("panel", VisualTheme.elevated_panel_style(Color("241a14"), VisualTheme.EMBER_BRIGHT, 3, 18))
	add_child(overlay)
	var rows := HBoxContainer.new()
	rows.add_theme_constant_override("separation", 18)
	overlay.add_child(rows)
	TelemetryManager.track_route_choice_shown(
		RunManager.current_run,
		_tile_type_key(branch_data.first_tile_for(RouteBranchDataSource.ROUTE_A)),
		_tile_type_key(branch_data.first_tile_for(RouteBranchDataSource.ROUTE_B)),
		1, 1,
	)
	for branch: int in [RouteBranchDataSource.ROUTE_A, RouteBranchDataSource.ROUTE_B]:
		var archetype: StringName = branch_data.archetype_for(branch)
		var button := Button.new()
		button.custom_minimum_size = Vector2(180, 120)
		var label: String = "A" if branch == RouteBranchDataSource.ROUTE_A else "B"
		button.text = "RUTA %s\n%s\nPELIGRO: %s\nENFOQUE: %s\n1er nodo: %s" % [
			label, RouteBranchDataSource.display_name(archetype), RouteBranchDataSource.danger_label(archetype),
			RouteBranchDataSource.focus_label(archetype), _tile_name(branch_data.first_tile_for(branch)),
		]
		button.pressed.connect(func() -> void: branch_choice_selected.emit(branch))
		rows.add_child(button)
	var chosen: int = await branch_choice_selected
	overlay.queue_free()
	var archetype_chosen: StringName = branch_data.archetype_for(chosen)
	event_label.text = "RUTA %s ELEGIDA\n%s" % [
		"A" if chosen == RouteBranchDataSource.ROUTE_A else "B", RouteBranchDataSource.display_name(archetype_chosen),
	]
	TelemetryManager.track_route_choice_selected(RunManager.current_run, _tile_type_key(branch_data.first_tile_for(chosen)), 1)
	return chosen


func _on_tile_gui_input(event: InputEvent, tile_index: int) -> void:
	if tile_index not in _pending_route_destinations:
		return
	var selected: bool = (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	) or (
		event is InputEventScreenTouch and event.pressed
	) or (
		event is InputEventKey and event.pressed and event.is_action(&"ui_accept")
	)
	if not selected:
		return
	_tile_controls[tile_index].accept_event()
	route_destination_selected.emit(tile_index)


func _resolve_current_tile(tile_type: int) -> void:
	if _has_forced_tile and tile_type != BoardTileData.TileType.BOSS:
		_has_forced_tile = false
		await _resolve_tile_type(_forced_tile_type)
		_update_hud()
		return
	await _resolve_tile_type(tile_type)
	_update_hud()


func _resolve_tile_type(type: int) -> void:
	var intent: int = BoardTileResolutionAdapterSource.get_intent(type)
	match intent:
		BoardTileResolutionAdapterSource.Intent.COMBAT:
			if not await TutorialManager.request_and_wait(TutorialCatalog.TILE_COMBAT, TutorialManager.CONTEXT_BOARD, self):
				return
			_start_combat(false, false)
		BoardTileResolutionAdapterSource.Intent.HEAL:
			if not await TutorialManager.request_and_wait(TutorialCatalog.TILE_HEAL, TutorialManager.CONTEXT_BOARD, self):
				return
			var inline_result: Dictionary = BoardTileResolutionAdapterSource.resolve_inline(intent, RunManager.current_run)
			var recovered: int = int(inline_result.get("recovered", 0))
			event_label.text = "CURACIÓN\n+%d VIDA" % recovered
			AudioManager.play_event(AudioManager.AudioEvent.HEAL)
			_flash_event(VisualTheme.HEAL)
			_pulse_health_label()
		BoardTileResolutionAdapterSource.Intent.BOSS:
			if not await TutorialManager.request_and_wait(TutorialCatalog.TILE_BOSS, TutorialManager.CONTEXT_BOARD, self):
				return
			_start_combat(true, false)
		BoardTileResolutionAdapterSource.Intent.EVENT:
			if not await TutorialManager.request_and_wait(TutorialCatalog.TILE_EVENT, TutorialManager.CONTEXT_BOARD, self):
				return
			_start_event()
		BoardTileResolutionAdapterSource.Intent.TREASURE:
			if not await TutorialManager.request_and_wait(TutorialCatalog.TILE_TREASURE, TutorialManager.CONTEXT_BOARD, self):
				return
			_start_treasure()
		BoardTileResolutionAdapterSource.Intent.ELITE:
			if not await TutorialManager.request_and_wait(TutorialCatalog.TILE_ELITE, TutorialManager.CONTEXT_BOARD, self):
				return
			_start_combat(false, true)
		_:
			var inline_result: Dictionary = BoardTileResolutionAdapterSource.resolve_inline(intent, RunManager.current_run)
			event_label.text = String(inline_result.get("message", "El camino está despejado"))


func _start_combat(is_boss: bool, is_elite: bool) -> void:
	_combat_pending = true
	if is_boss:
		RunManager.current_run.board_locked = true
		event_label.text = "JEFE\n%s" % RunManager.current_run.biome_data.boss.display_name
	elif is_elite:
		event_label.text = "ENCUENTRO ÉLITE\nUn enemigo poderoso custodia el camino"
	else:
		event_label.text = "Un enemigo bloquea tu camino"
	combat_requested.emit(is_boss, is_elite)


func _start_event() -> void:
	_combat_pending = true
	event_label.text = "La ceniza oculta una decisión"
	event_requested.emit()


func _start_treasure() -> void:
	_combat_pending = true
	event_label.text = "Un tesoro olvidado te espera"
	treasure_requested.emit()


func resume_after_combat() -> void:
	_combat_pending = false
	event_label.text = "¡Victoria! Continuá por el camino."
	_update_hud()
	roll_button.disabled = RunManager.current_run.board_locked
	return_button.disabled = false
	if not roll_button.disabled:
		roll_button.grab_focus()
	call_deferred("_focus_current_path_position")


func resume_after_interaction(message: String) -> void:
	_combat_pending = false
	event_label.text = message
	_update_hud()
	roll_button.disabled = RunManager.current_run.board_locked
	return_button.disabled = false
	if not roll_button.disabled:
		roll_button.grab_focus()
	call_deferred("_focus_current_path_position")


func _place_marker_immediately(tile_index: int) -> void:
	player_marker.position = _marker_position(tile_index)
	player_marker.show()
	_highlight_current_tile(tile_index)


func _highlight_current_tile(tile_index: int) -> void:
	if _highlighted_tile_index == tile_index:
		return
	if _highlighted_tile_index >= 0:
		_set_tile_highlight(_highlighted_tile_index, false)
	_set_tile_highlight(tile_index, true)
	_highlighted_tile_index = tile_index
	_refresh_path_states()


func _set_tile_highlight(tile_index: int, highlighted: bool) -> void:
	var style := _tile_controls[tile_index].get_theme_stylebox("panel") as StyleBoxFlat
	if highlighted:
		style.border_color = VisualTheme.EMBER_BRIGHT
		style.set_border_width_all(6)
		return
	var tile_type: int = _tile_types[tile_index]
	style.border_color = _tile_border_color(tile_type)
	var border_width: int = _tile_border_width(tile_type)
	style.set_border_width_all(border_width)


func _refresh_path_states() -> void:
	for index in _tile_controls.size():
		var style: StyleBoxFlat = _tile_controls[index].get_theme_stylebox("panel") as StyleBoxFlat
		var base_color: Color = _tile_color(_tile_types[index])
		var state_label: Label = _tile_controls[index].get_node("StateMark") as Label
		style.border_color = VisualTheme.EMBER_BRIGHT if index == RunManager.current_run.board_position else _tile_border_color(_tile_types[index])
		style.set_border_width_all(6 if index == RunManager.current_run.board_position else _tile_border_width(_tile_types[index]))
		if index < RunManager.current_run.board_position:
			style.bg_color = base_color.darkened(0.35)
			_tile_controls[index].modulate = Color(0.72, 0.7, 0.76)
			state_label.text = "PASADA"
		elif index == RunManager.current_run.board_position:
			style.bg_color = base_color.lightened(0.12)
			_tile_controls[index].modulate = Color.WHITE
			state_label.text = "ACTUAL"
		else:
			style.bg_color = base_color.darkened(0.5)
			_tile_controls[index].modulate = Color(0.62, 0.6, 0.67)
			state_label.text = ""
		if index in _pending_route_destinations:
			var option_index: int = _pending_route_destinations.find(index)
			style.bg_color = base_color.lightened(0.18)
			style.border_color = VisualTheme.EMBER_BRIGHT
			style.set_border_width_all(7)
			_tile_controls[index].modulate = Color.WHITE
			state_label.text = "%s · +%d" % ["A" if option_index == 0 else "B", index - _pending_route_origin]
			state_label.add_theme_color_override("font_color", VisualTheme.EMBER_BRIGHT)
			_tile_controls[index].tooltip_text = "Destino %s: %s, distancia %d" % ["A" if option_index == 0 else "B", _tile_name(_tile_types[index]), index - _pending_route_origin]
		else:
			state_label.add_theme_color_override("font_color", VisualTheme.TEXT_SECONDARY)
			_tile_controls[index].tooltip_text = ""
	path_lines.set_progress(RunManager.current_run.board_position)


func _tile_type_key(type: int) -> String:
	match type:
		BoardTileData.TileType.COMBAT: return "combat"
		BoardTileData.TileType.HEAL: return "heal"
		BoardTileData.TileType.BOSS: return "boss"
		BoardTileData.TileType.EVENT: return "event"
		BoardTileData.TileType.TREASURE: return "treasure"
		BoardTileData.TileType.ELITE: return "elite"
		_: return "empty"


func _update_path_lines() -> void:
	var points := PackedVector2Array()
	var path_inverse := path_lines.get_global_transform().affine_inverse()
	for tile in _tile_controls:
		var tile_center_global := tile.get_global_transform() * (tile.size * 0.5)
		points.append(path_inverse * tile_center_global)
	path_lines.set_points(points)


func _animate_dice_result() -> void:
	if SettingsManager.reduce_motion:
		dice_result_label.modulate = Color.WHITE
		dice_result_label.scale = Vector2.ONE
		return
	dice_result_label.pivot_offset = dice_result_label.size * 0.5
	dice_result_label.scale = Vector2(0.72, 0.72)
	dice_result_label.modulate = VisualTheme.EMBER_BRIGHT
	var tween := create_tween().set_parallel(true)
	tween.tween_property(dice_result_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(dice_result_label, "modulate", Color.WHITE, 0.3)


func _pulse_marker() -> void:
	if SettingsManager.reduce_motion:
		return
	player_marker.pivot_offset = player_marker.size * 0.5
	player_marker.scale = Vector2(1.16, 1.16)
	var tween := create_tween()
	tween.tween_property(player_marker, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash_event(color: Color) -> void:
	if SettingsManager.reduce_motion:
		event_label.modulate = Color.WHITE
		return
	event_label.modulate = color
	var tween := create_tween()
	tween.tween_property(event_label, "modulate", Color.WHITE, 0.35)


func _pulse_health_label() -> void:
	if SettingsManager.reduce_motion:
		return
	health_label.pivot_offset = health_label.size * 0.5
	health_label.modulate = VisualTheme.HEAL
	health_label.scale = Vector2(1.08, 1.08)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(health_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(health_label, "modulate", Color.WHITE, 0.35)


func _marker_position(tile_index: int) -> Vector2:
	var tile: Control = _tile_controls[tile_index]
	var tile_center_global: Vector2 = tile.get_global_transform() * (tile.size * 0.5)
	var tile_center_local: Vector2 = board_content.get_global_transform().affine_inverse() * tile_center_global
	return tile_center_local - player_marker.size * 0.5


func _ensure_current_tile_visible() -> void:
	await get_tree().process_frame
	var current_index: int = clampi(RunManager.current_run.board_position, 0, _tile_controls.size() - 1)
	board_scroll.ensure_control_visible(_tile_controls[current_index])


func _focus_current_path_position() -> void:
	if _tile_controls.is_empty():
		return
	var current_index: int = clampi(RunManager.current_run.board_position, 0, _tile_controls.size() - 1)
	board_scroll.ensure_control_visible(_tile_controls[current_index])


func _update_hud() -> void:
	health_label.configure(&"health", "%d/%d" % [RunManager.current_run.current_health, RunManager.current_run.max_health], AshenBadge.Variant.HEAL, AshenIcon.DisplaySize.SMALL)
	attack_label.configure(&"attack", "%d" % RunManager.current_run.attack, AshenBadge.Variant.EMBER, AshenIcon.DisplaySize.SMALL)
	defense_label.configure(&"defense", "%d" % RunManager.current_run.defense, AshenBadge.Variant.NEUTRAL, AshenIcon.DisplaySize.SMALL)
	run_ash_label.configure(&"ash", "%d" % RunManager.current_run.run_ash, AshenBadge.Variant.EMBER, AshenIcon.DisplaySize.SMALL)
	var xp_requirement: int = RunManager.current_run.get_xp_to_next_level()
	run_level_label.configure(&"ember", "NV. %d" % RunManager.current_run.run_level, AshenBadge.Variant.EMBER, AshenIcon.DisplaySize.SMALL)
	run_xp_bar.max_value = float(maxi(1, xp_requirement))
	run_xp_bar.value = float(RunManager.current_run.current_xp)
	run_xp_label.text = "MÁXIMO" if xp_requirement <= 0 else "%d / %d XP" % [RunManager.current_run.current_xp, xp_requirement]
	var synergy_names: Array[String] = []
	for synergy_id: StringName in RunManager.current_run.active_synergy_ids:
		if synergy_names.size() >= 2:
			break
		synergy_names.append(BoonSynergyResolver.get_display_name(synergy_id))
	synergy_label.text = "SINERGIAS · %d%s" % [
		RunManager.current_run.active_synergy_ids.size(),
		" · " + " / ".join(synergy_names) if not synergy_names.is_empty() else "",
	]
	_update_position_label()


func _show_pending_synergy_announcement() -> void:
	var activated: Array[StringName] = RunManager.current_run.consume_pending_synergy_announcements()
	if activated.is_empty():
		return
	DiscoveryTracker.discover_active_synergies(RunManager.current_run)
	var names: Array[String] = []
	for synergy_id: StringName in activated:
		names.append(BoonSynergyResolver.get_display_name(synergy_id))
	var first: SynergyData = SynergyCatalog.get_by_id(activated[0])
	event_label.text = "SINERGIA ACTIVADA\n%s%s" % [
		" / ".join(names),
		"\n%s" % first.description if first != null else "",
	]
	TutorialManager.request(TutorialCatalog.SYNERGY_ACTIVATED, TutorialManager.CONTEXT_BOARD, self)


func _update_position_label() -> void:
	position_label.configure(&"event", "%d / %d" % [RunManager.current_run.board_position + 1, _tile_types.size()], AshenBadge.Variant.NEUTRAL, AshenIcon.DisplaySize.SMALL)
	progress_bar.max_value = float(_tile_types.size())
	progress_bar.value = float(RunManager.current_run.board_position + 1)


func _update_biome_header() -> void:
	var biome: BiomeData = RunManager.current_run.biome_data
	biome_label.text = biome.display_name.to_upper() if biome != null else "REGIÓN DESCONOCIDA"
	biome_rules_label.text = BiomeModifierResolver.get_compact_summary(biome)
	if biome != null:
		background.color = biome.background_color
		var thumbnail: Texture2D = biome.get_board_thumbnail()
		biome_thumbnail.texture = thumbnail
		biome_thumbnail.visible = thumbnail != null
		biome_label.modulate = biome.accent_color
		path_lines.configure(biome.accent_color)
		progress_bar.add_theme_stylebox_override("background", VisualTheme.panel_style(Color("100d12"), VisualTheme.BORDER_DARK, 1, 6))
		progress_bar.add_theme_stylebox_override("fill", VisualTheme.panel_style(biome.accent_color.darkened(0.22), biome.accent_color, 0, 6))
		run_xp_bar.add_theme_stylebox_override("background", VisualTheme.panel_style(Color("100d12"), VisualTheme.BORDER_DARK, 1, 6))
		run_xp_bar.add_theme_stylebox_override("fill", VisualTheme.panel_style(VisualTheme.EMBER_DARK, VisualTheme.EMBER_BRIGHT, 0, 6))
		biome_banner.add_theme_stylebox_override("panel", VisualTheme.panel_style(biome.panel_color, biome.accent_color, 3, 14))
	seed_label.visible = DebugConfig.DEBUG_TOOLS_ENABLED
	seed_label.text = "Seed: %d" % RunManager.current_run.board_seed


func _show_biome_intro() -> void:
	var run := RunManager.current_run
	if run.biome_intro_shown or run.biome_data == null:
		return
	run.biome_intro_shown = true
	biome_banner_title.text = run.biome_data.display_name.to_upper()
	biome_banner_subtitle.text = "%s\n%s" % [run.biome_data.subtitle, BiomeModifierResolver.get_compact_summary(run.biome_data)]
	biome_banner.visible = true
	AudioManager.play_sfx(AudioManager.Sfx.BIOME_ENTER, run.biome_data.entry_audio_pitch)
	if SettingsManager.reduce_motion:
		biome_banner.modulate.a = 1.0
		return
	biome_banner.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(biome_banner, "modulate:a", 1.0, 0.2)
	tween.tween_interval(0.8)
	tween.tween_property(biome_banner, "modulate:a", 0.0, 0.25)
	tween.finished.connect(func() -> void: biome_banner.hide())


func _on_return_button_pressed() -> void:
	if _is_moving:
		return
	pause_requested.emit()


func _setup_debug_tools() -> void:
	debug_panel.visible = DebugConfig.DEBUG_TOOLS_ENABLED
	if not DebugConfig.DEBUG_TOOLS_ENABLED:
		return

	debug_dice_option.add_item("Random", 0)
	for result: int in range(DiceRoller.MIN_RESULT, DiceRoller.MAX_RESULT + 1):
		debug_dice_option.add_item("Force %d" % result, result)
	debug_dice_option.item_selected.connect(_on_debug_dice_selected)
	debug_force_combat_button.pressed.connect(_on_debug_force_combat_pressed)
	debug_go_boss_button.pressed.connect(_on_debug_go_boss_pressed)
	debug_damage_button.pressed.connect(_on_debug_damage_pressed)
	debug_heal_button.pressed.connect(_on_debug_heal_pressed)
	debug_attack_button.pressed.connect(_on_debug_attack_pressed)
	debug_force_event_button.pressed.connect(_on_debug_force_event_pressed)
	debug_force_treasure_button.pressed.connect(_on_debug_force_treasure_pressed)
	debug_force_elite_button.pressed.connect(_on_debug_force_elite_pressed)
	debug_grant_boon_button.text = "Grant Configured Boons"
	debug_grant_boon_button.pressed.connect(_on_debug_grant_boon_pressed)


func _on_debug_dice_selected(index: int) -> void:
	_forced_dice_result = debug_dice_option.get_item_id(index)


func _on_debug_force_combat_pressed() -> void:
	_set_forced_tile(BoardTileData.TileType.COMBAT, "Combat")


func _on_debug_force_event_pressed() -> void:
	_set_forced_tile(BoardTileData.TileType.EVENT, "Event")


func _on_debug_force_treasure_pressed() -> void:
	_set_forced_tile(BoardTileData.TileType.TREASURE, "Treasure")


func _on_debug_force_elite_pressed() -> void:
	_set_forced_tile(BoardTileData.TileType.ELITE, "Elite")


func _on_debug_grant_boon_pressed() -> void:
	var granted: Array[String] = []
	for boon_id: StringName in DebugConfig.DEBUG_BOON_GRANTS:
		var amount: int = DebugConfig.DEBUG_BOON_GRANTS[boon_id]
		if amount <= 0:
			continue
		var total: int = RunManager.current_run.add_boon(boon_id, amount)
		granted.append("%s x%d" % [boon_id, total])
	event_label.text = "DEBUG: " + ", ".join(granted) if not granted.is_empty() else "DEBUG: No boons configured"


func _set_forced_tile(type: BoardTileData.TileType, label: String) -> void:
	_has_forced_tile = true
	_forced_tile_type = type
	event_label.text = "DEBUG: Next landing will resolve %s" % label


func _on_debug_go_boss_pressed() -> void:
	if _is_moving or _combat_pending:
		return
	RunManager.current_run.board_position = _tile_types.size() - 1
	_place_marker_immediately(RunManager.current_run.board_position)
	_update_hud()
	_resolve_current_tile(_tile_types[RunManager.current_run.board_position])
	roll_button.disabled = true
	return_button.disabled = true


func _on_debug_damage_pressed() -> void:
	RunManager.current_run.current_health = maxi(1, RunManager.current_run.current_health - 30)
	event_label.text = "DEBUG: Player HP reduced"
	_update_hud()


func _on_debug_heal_pressed() -> void:
	var recovered := RunManager.current_run.heal(30)
	event_label.text = "DEBUG: Restored %d HP" % recovered
	_update_hud()


func _on_debug_attack_pressed() -> void:
	RunManager.current_run.attack += 10
	event_label.text = "DEBUG: Attack increased by 10"
	_update_hud()


## Slice de QA aislada por argumento de debug build; no habilita herramientas globales.
func debug_prepare_route_visual(mode: StringName) -> void:
	if not DebugConfig.is_visual_slice_enabled() or _tile_controls.size() < 10:
		return
	var origin: int = 4
	var destinations: Array[int] = [7, 8]
	match mode:
		&"route_elite_heal":
			_tile_types[7] = BoardTileData.TileType.ELITE
			_tile_types[8] = BoardTileData.TileType.HEAL
			_rebuild_tile_visuals_for_slice()
		&"route_treasure":
			origin = 3
			destinations = [5, 6]
			_tile_types[5] = BoardTileData.TileType.COMBAT
			_tile_types[6] = BoardTileData.TileType.TREASURE
			_rebuild_tile_visuals_for_slice()
		&"route_single":
			RunManager.current_run.board_position = origin
			_place_marker_immediately(origin)
			_update_hud()
			event_label.text = "DADO · 3\nÚnico destino: movimiento automático"
			return
		_:
			pass
	RunManager.current_run.board_position = origin
	_pending_route_origin = origin
	_pending_route_destinations = destinations
	roll_button.disabled = true
	_place_marker_immediately(origin)
	_refresh_path_states()
	_update_hud()
	event_label.text = "ELEGÍ TU DESTINO\nTocá A o B"
	board_scroll.ensure_control_visible(_tile_controls[destinations[1]])


func _rebuild_tile_visuals_for_slice() -> void:
	# Sólo actualiza el texto/icono lógico necesario para capturas; no toca Resources.
	for index: int in _tile_controls.size():
		var tile: Control = _tile_controls[index]
		var content: VBoxContainer = tile.get_child(0) as VBoxContainer
		if content == null or content.get_child_count() < 3:
			continue
		var icon: AshenIcon = content.get_child(0) as AshenIcon
		var type_label: Label = content.get_child(2) as Label
		if icon != null:
			icon.configure(_tile_icon_id(_tile_types[index]), _tile_border_color(_tile_types[index]), AshenIcon.DisplaySize.MEDIUM)
		if type_label != null:
			type_label.text = _tile_name(_tile_types[index])

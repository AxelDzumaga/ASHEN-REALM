class_name AshenWastesMap3D
extends Control

signal pause_requested
signal combat_requested(is_boss: bool, is_elite: bool)
signal event_requested
signal treasure_requested
signal route_destination_selected(destination: int)
signal branch_choice_selected(branch: int)

const BoardTurnControllerSource = preload("res://scripts/board/board_turn_controller.gd")
const BoardTileResolutionAdapterSource = preload("res://scripts/board/board_tile_resolution_adapter.gd")
const MapLayout3DSource = preload("res://scripts/board3d/map_layout_3d.gd")
const MapTile3DSource = preload("res://scripts/board3d/map_tile_3d.gd")
const MapSandboxContextSource = preload("res://scripts/board3d/map_sandbox_context.gd")
const RouteBranchDataSource = preload("res://scripts/board/route_branch_data.gd")

const MOVE_DURATION := 0.18
const ROLL_REVEAL_DELAY := 0.35

@onready var terrain_root: Node3D = %TerrainRoot
@onready var connection_root: Node3D = %ConnectionRoot
@onready var tile_root: Node3D = %TileRoot
@onready var player_marker: Node3D = %PlayerMarker3D
@onready var equipment_shoulder_left: MeshInstance3D = %EquipmentShoulderLeft
@onready var equipment_shoulder_right: MeshInstance3D = %EquipmentShoulderRight
@onready var equipment_weapon_blade: MeshInstance3D = %EquipmentWeaponBlade
@onready var camera_rig: Node3D = %CameraRig
@onready var camera: Camera3D = %Camera3D
@onready var hud_root: Control = %SafeAreaRoot
@onready var hud_layer: CanvasLayer = $HUDLayer

var _run: RunState
var _sandbox_mode := false
var _positions: Array[Vector3] = []
var _tiles: Array[StaticBody3D] = []
## fork_index -> {RouteBranchData.ROUTE_A/ROUTE_B: Array[MapTile3D]} — sólo
## existen para el/los fork(s) generados en esta run.
var _branch_tiles: Dictionary = {}
## fork_index -> {RouteBranchData.ROUTE_A/ROUTE_B: Array[Vector3]}
var _branch_positions: Dictionary = {}
var _materials: Dictionary = {}
var _turn_controller: RefCounted
var _dice_roller := DiceRoller.new()
var _is_moving := false
var _interaction_pending := false
var _forced_dice_result := 0
var _pending_route_destinations: Array[int] = []
var _route_input_committed := false
var _playtest_mode := false
var _fps_samples := 0
var _fps_total := 0.0
var _fps_min := INF
var _fps_update_accumulator := 0.0
var _fps_warmup_remaining := 1.0

var _stats_label: Label
var _position_label: Label
var _dice_label: Label
var _event_label: Label
var _roll_button: Button
var _pause_button: Button
var _reset_button: Button
var _seed_label: Label
var _diagnostic_label: Label


func configure_playtest_mode(enabled: bool) -> void:
	_playtest_mode = enabled


## Active Run Persistence — forwarded to BoardTurnController's injected
## checkpoint hook. No-ops with no selected character (e.g. isolated
## tests, --map3d-prototype launches, which bypass character selection
## entirely) rather than erroring.
func _checkpoint_active_run(run: RunState, phase: String, reason: String) -> void:
	if CharacterProfileRepository.selected_character_id.is_empty():
		return
	ActiveRunRepository.checkpoint(CharacterProfileRepository.selected_character_id, run, phase, reason)


func _ready() -> void:
	if theme == null:
		theme = VisualTheme.create_theme()
	_resolve_context()
	_playtest_mode = _playtest_mode or _sandbox_mode
	set_process(_playtest_mode)
	if _run == null or _run.board_tile_sequence.size() != MapLayout3DSource.POSITION_COUNT:
		push_error("Map3D requires an active 30-position board.")
		return
	_positions = MapLayout3DSource.get_positions(_run.board_tile_sequence.size())
	_create_materials()
	_build_terrain()
	_build_connections()
	_build_tiles()
	_build_hud()
	_turn_controller = BoardTurnControllerSource.new(_run, _run.board_tile_sequence, _dice_roller, _checkpoint_active_run)
	_place_player_immediately(_run.board_position)
	_apply_equipment_visuals()
	_update_hud()
	await get_tree().process_frame
	camera_rig.focus_navigation(_run.board_position, _positions, 0.0)
	if is_instance_valid(self) and int(_turn_controller.get("state")) == BoardTurnControllerSource.State.ROUTE_DECISION:
		# Active Run Persistence resume: same reasoning as Board2D — the
		# controller detected we're sitting on an unresolved fork, reopen
		# the same A/B choice immediately.
		await _handle_fork_pause()


func _resolve_context() -> void:
	if RunManager.has_active_run():
		_run = RunManager.current_run
		_sandbox_mode = false
	else:
		_run = MapSandboxContextSource.create_run()
		_sandbox_mode = true


func _create_materials() -> void:
	_materials = {
		BoardTileData.TileType.EMPTY: _material(Color("5a504c"), 0.0),
		BoardTileData.TileType.HEAL: _material(Color("5f9a72"), 0.18),
		BoardTileData.TileType.BOSS: _material(Color("c34c45"), 0.28),
		BoardTileData.TileType.COMBAT: _material(Color("b86d3e"), 0.08),
		BoardTileData.TileType.EVENT: _material(Color("6f82ad"), 0.08),
		BoardTileData.TileType.TREASURE: _material(Color("d5a441"), 0.16),
		BoardTileData.TileType.ELITE: _material(Color("d0654e"), 0.2),
		BoardTileData.TileType.FORK: _material(Color("caa24a"), 0.22),
	}


## Nodos 3D no tienen `modulate`; el tinte por carril (A/B) se aplica como un
## material propio en vez de intentar teñir el StaticBody3D directamente.
func _tinted_material(tile_type: int, tint: Color) -> StandardMaterial3D:
	var base: StandardMaterial3D = _materials[tile_type]
	var result: StandardMaterial3D = base.duplicate()
	result.albedo_color = result.albedo_color.lerp(tint, 0.4)
	return result


func _material(color: Color, emission_strength: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.86
	if emission_strength > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = emission_strength
	return result


## Primitivas provisionales sobre el marcador del jugador, reutilizando el mismo
## catálogo y color por rareza que ya usa el equipamiento visual en Combat2D/Lobby
## (EquipmentVisualCatalog, VisualTheme.rarity_color) — sin duplicar esa lógica.
func _apply_equipment_visuals() -> void:
	var weapon: EquipmentData = EquipmentCatalog.get_by_id(String(_run.equipped_weapon_id))
	var armor: EquipmentData = EquipmentCatalog.get_by_id(String(_run.equipped_armor_id))
	_apply_equipment_mesh(equipment_weapon_blade, weapon)
	_apply_equipment_mesh(equipment_shoulder_left, armor)
	_apply_equipment_mesh(equipment_shoulder_right, armor)


func _apply_equipment_mesh(mesh_instance: MeshInstance3D, item: EquipmentData) -> void:
	var visual: EquipmentVisualData = EquipmentVisualCatalog.get_for_item(item)
	mesh_instance.visible = visual != null
	if visual == null:
		return
	var material := _material(visual.accent, 0.3 + float(item.rarity) * 0.35)
	material.albedo_color = material.albedo_color.lerp(VisualTheme.rarity_color(item.rarity), 0.4)
	mesh_instance.material_override = material


func _build_tiles() -> void:
	_tiles.resize(_run.board_tile_sequence.size())
	for index: int in _run.board_tile_sequence.size():
		var tile: StaticBody3D = MapTile3DSource.new()
		tile.configure(index, _run.board_tile_sequence[index], _materials[_run.board_tile_sequence[index]])
		tile.position = _positions[index]
		if _is_reserved_branch_window(index):
			# Las 4 casillas reservadas de cada fork no representan contenido
			# jugable propio (ver RESERVED SPINE WINDOW): quedan ocultas y sin
			# colisión, pero el tile existe igual para que _tiles conserve un
			# elemento por índice (varios consumidores — incluyendo tests —
			# asumen _tiles.size() == board length sin huecos null).
			tile.visible = false
			tile.collision_layer = 0
		tile_root.add_child(tile)
		_tiles[index] = tile
	_build_branch_lanes()


func _is_reserved_branch_window(index: int) -> bool:
	for fork_index: int in _run.route_branches:
		if index > fork_index and index <= fork_index + RouteBranchDataSource.BRANCH_LENGTH:
			return true
	return false


## Construye las dos rutas físicamente separadas de cada fork generado:
## divergen desde el FORK y reconvergen en el MERGE (MapLayout3D.get_branch_
## position). Ambas quedan visibles antes de elegir; sólo la elegida se
## camina (_move_player_to usa _branch_positions del carril activo).
func _build_branch_lanes() -> void:
	for fork_index: int in _run.route_branches:
		var branch_data: RefCounted = _run.route_branches[fork_index]
		var merge_index: int = fork_index + RouteBranchDataSource.BRANCH_LENGTH + 1
		var lane_tiles: Dictionary = {RouteBranchDataSource.ROUTE_A: [], RouteBranchDataSource.ROUTE_B: []}
		var lane_positions: Dictionary = {RouteBranchDataSource.ROUTE_A: [], RouteBranchDataSource.ROUTE_B: []}
		for branch: int in [RouteBranchDataSource.ROUTE_A, RouteBranchDataSource.ROUTE_B]:
			var side: int = 1 if branch == RouteBranchDataSource.ROUTE_A else -1
			var tint: Color = Color("ffb35c") if branch == RouteBranchDataSource.ROUTE_A else Color("6fb8d6")
			for local_position: int in range(1, RouteBranchDataSource.BRANCH_LENGTH + 1):
				var world_position: Vector3 = MapLayout3DSource.get_branch_position(
					fork_index, merge_index, side, local_position, RouteBranchDataSource.BRANCH_LENGTH, _positions,
				)
				var tile_type: int = branch_data.tile_type_for(branch, fork_index + local_position)
				var tile: StaticBody3D = MapTile3DSource.new()
				tile.configure(fork_index + local_position, tile_type, _tinted_material(tile_type, tint))
				tile.position = world_position
				tile_root.add_child(tile)
				lane_tiles[branch].append(tile)
				lane_positions[branch].append(world_position)
			_connect_branch_lane(fork_index, merge_index, branch, lane_positions[branch], tint)
		_branch_tiles[fork_index] = lane_tiles
		_branch_positions[fork_index] = lane_positions


func _connect_branch_lane(fork_index: int, merge_index: int, branch: int, lane_positions: Array, tint: Color) -> void:
	var waypoints: Array[Vector3] = [_positions[fork_index]]
	for position: Vector3 in lane_positions:
		waypoints.append(position)
	waypoints.append(_positions[merge_index])
	var road_material := _material(Color("302925"))
	road_material.albedo_color = road_material.albedo_color.lerp(tint, 0.35)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.22
	cylinder.bottom_radius = 0.26
	cylinder.height = 1.0
	cylinder.radial_segments = 6
	cylinder.material = road_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = cylinder
	multimesh.instance_count = waypoints.size() - 1
	for index: int in range(waypoints.size() - 1):
		var start: Vector3 = waypoints[index]
		var finish: Vector3 = waypoints[index + 1]
		var direction: Vector3 = finish - start
		var basis := Basis(Quaternion(Vector3.UP, direction.normalized())).scaled_local(Vector3(1.0, direction.length(), 1.0))
		var origin: Vector3 = (start + finish) * 0.5 - Vector3(0.0, 0.2, 0.0)
		multimesh.set_instance_transform(index, Transform3D(basis, origin))
	var instance := MultiMeshInstance3D.new()
	instance.name = "BranchLane%d_%d" % [fork_index, branch]
	instance.multimesh = multimesh
	connection_root.add_child(instance)


func _build_connections() -> void:
	var road_material := _material(Color("302925"))
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.28
	cylinder.bottom_radius = 0.34
	cylinder.height = 1.0
	cylinder.radial_segments = 8
	cylinder.material = road_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = cylinder
	var segment_indices: Array[int] = []
	for index: int in range(_positions.size() - 1):
		# La ventana reservada de un fork no tiene un único camino recto ni
		# tiles reales en sus 4 posiciones: las dos rutas divergentes
		# (_build_branch_lanes) ocupan ese tramo en su lugar.
		if _is_reserved_branch_window(index) or _is_reserved_branch_window(index + 1):
			continue
		segment_indices.append(index)
	multimesh.instance_count = segment_indices.size()
	for multimesh_index: int in segment_indices.size():
		var index: int = segment_indices[multimesh_index]
		var start: Vector3 = _positions[index]
		var finish: Vector3 = _positions[index + 1]
		var direction: Vector3 = finish - start
		var basis := Basis(Quaternion(Vector3.UP, direction.normalized())).scaled_local(Vector3(1.0, direction.length(), 1.0))
		var origin: Vector3 = (start + finish) * 0.5 - Vector3(0.0, 0.2, 0.0)
		multimesh.set_instance_transform(multimesh_index, Transform3D(basis, origin))
	var instance := MultiMeshInstance3D.new()
	instance.name = "PathConnectionsMultiMesh"
	instance.multimesh = multimesh
	connection_root.add_child(instance)


func _build_terrain() -> void:
	var bounds: AABB = MapLayout3DSource.get_bounds(MapLayout3DSource.get_positions())
	var ground := MeshInstance3D.new()
	ground.name = "AshGround"
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(25.0, 1.2, bounds.size.z + 16.0)
	ground_mesh.material = _material(Color("171317"))
	ground.mesh = ground_mesh
	ground.position = bounds.get_center() + Vector3(0.0, -1.05, 0.0)
	terrain_root.add_child(ground)
	_build_rock_multimesh(bounds)
	_build_rock_shard_multimesh(bounds)
	_build_ruin_multimesh(bounds)
	_build_thorn_multimesh(bounds)
	_build_ember_crack_multimesh(bounds)


func _build_rock_multimesh(bounds: AABB) -> void:
	var rock_mesh := BoxMesh.new()
	rock_mesh.size = Vector3(1.0, 1.0, 1.0)
	rock_mesh.material = _material(Color("292329"))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = rock_mesh
	multimesh.instance_count = 72
	for index: int in multimesh.instance_count:
		var z: float = bounds.position.z + 2.0 + fmod(float(index) * 5.17, bounds.size.z + 4.0)
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var x: float = side * (7.5 + fmod(float(index) * 1.73, 4.2))
		var scale_value := Vector3(0.55 + fmod(float(index) * 0.17, 0.9), 0.5 + fmod(float(index) * 0.29, 1.6), 0.6 + fmod(float(index) * 0.11, 1.0))
		var basis := Basis(Vector3.UP, float(index) * 0.47).scaled(scale_value)
		multimesh.set_instance_transform(index, Transform3D(basis, Vector3(x, -0.2, z)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "AshRocksMultiMesh"
	instance.multimesh = multimesh
	terrain_root.add_child(instance)


## Segunda silueta de roca (prisma angular) para que el campo de piedras no
## se lea como una sola forma repetida — mismo patrón determinista que el
## resto de las multimesh de terreno.
func _build_rock_shard_multimesh(bounds: AABB) -> void:
	var shard_mesh := PrismMesh.new()
	shard_mesh.size = Vector3(0.9, 1.3, 0.7)
	shard_mesh.material = _material(Color("332b30"))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = shard_mesh
	multimesh.instance_count = 26
	for index: int in multimesh.instance_count:
		var z: float = bounds.position.z + 3.0 + fmod(float(index) * 9.53, bounds.size.z + 3.0)
		var side: float = -1.0 if index % 2 == 1 else 1.0
		var x: float = side * (9.5 + fmod(float(index) * 2.11, 5.0))
		var scale_value := Vector3(0.6 + fmod(float(index) * 0.23, 0.7), 0.7 + fmod(float(index) * 0.19, 1.1), 0.55 + fmod(float(index) * 0.13, 0.6))
		var basis := Basis(Vector3.UP, float(index) * 0.61).scaled(scale_value)
		multimesh.set_instance_transform(index, Transform3D(basis, Vector3(x, -0.15, z)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "AshRockShardsMultiMesh"
	instance.multimesh = multimesh
	terrain_root.add_child(instance)


func _build_ruin_multimesh(bounds: AABB) -> void:
	var column_mesh := CylinderMesh.new()
	column_mesh.top_radius = 0.34
	column_mesh.bottom_radius = 0.48
	column_mesh.height = 3.0
	column_mesh.radial_segments = 7
	column_mesh.material = _material(Color("403638"))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = column_mesh
	multimesh.instance_count = 18
	for index: int in multimesh.instance_count:
		var z: float = bounds.position.z + 5.0 + fmod(float(index) * 7.9, bounds.size.z)
		var x: float = (-9.2 if index % 2 == 0 else 9.2) + sin(float(index))
		var height_scale: float = 0.45 + fmod(float(index) * 0.23, 0.65)
		var basis := Basis(Vector3.UP, float(index) * 0.31).scaled(Vector3(1.0, height_scale, 1.0))
		multimesh.set_instance_transform(index, Transform3D(basis, Vector3(x, 0.1, z)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "RuinsMultiMesh"
	instance.multimesh = multimesh
	terrain_root.add_child(instance)


## Zarzas/ramas muertas — prop nuevo, silueta fina y alta para romper la
## sensación de vacío entre rocas y ruinas sin competir por atención con el
## camino ni las casillas.
func _build_thorn_multimesh(bounds: AABB) -> void:
	var thorn_mesh := CylinderMesh.new()
	thorn_mesh.top_radius = 0.0
	thorn_mesh.bottom_radius = 0.1
	thorn_mesh.height = 1.4
	thorn_mesh.radial_segments = 5
	thorn_mesh.material = _material(Color("241d1a"))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = thorn_mesh
	multimesh.instance_count = 30
	for index: int in multimesh.instance_count:
		var z: float = bounds.position.z + 1.5 + fmod(float(index) * 6.47, bounds.size.z + 3.0)
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var x: float = side * (6.4 + fmod(float(index) * 2.87, 6.5))
		var lean: float = -0.18 + fmod(float(index) * 0.07, 0.36)
		var height_scale: float = 0.5 + fmod(float(index) * 0.31, 0.9)
		var basis := Basis(Vector3.FORWARD, lean).rotated(Vector3.UP, float(index) * 0.83).scaled(Vector3(0.8, height_scale, 0.8))
		multimesh.set_instance_transform(index, Transform3D(basis, Vector3(x, 0.0, z)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "ThornsMultiMesh"
	instance.multimesh = multimesh
	terrain_root.add_child(instance)


func _build_ember_crack_multimesh(bounds: AABB) -> void:
	var crack_mesh := BoxMesh.new()
	crack_mesh.size = Vector3(0.16, 0.04, 2.8)
	crack_mesh.material = _material(Color("d0471f"), 0.85)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = crack_mesh
	multimesh.instance_count = 10
	for index: int in multimesh.instance_count:
		var z: float = bounds.position.z + 4.0 + fmod(float(index) * 8.9, bounds.size.z)
		var x: float = -5.8 + fmod(float(index) * 3.17, 11.6)
		var basis := Basis(Vector3.UP, -0.45 + float(index) * 0.37)
		multimesh.set_instance_transform(index, Transform3D(basis, Vector3(x, -0.41, z)))
	var instance := MultiMeshInstance3D.new()
	instance.name = "EmberCracksMultiMesh"
	instance.multimesh = multimesh
	terrain_root.add_child(instance)


func _build_hud() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 28)
	hud_root.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var title := Label.new()
	title.text = "THE ASHEN WASTES · MAP3D PROTOTYPE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	content.add_child(title)
	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_stats_label)
	_position_label = Label.new()
	_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_position_label)
	_diagnostic_label = Label.new()
	_diagnostic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diagnostic_label.add_theme_font_size_override("font_size", 13)
	_diagnostic_label.add_theme_color_override("font_color", VisualTheme.TEXT_SECONDARY)
	_diagnostic_label.visible = _playtest_mode
	content.add_child(_diagnostic_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	_event_label = Label.new()
	_event_label.custom_minimum_size.y = 64
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_event_label.text = "Tirá el D4 para avanzar."
	_event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_event_label)
	_dice_label = Label.new()
	_dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_label.add_theme_font_size_override("font_size", 34)
	_dice_label.text = "D4"
	content.add_child(_dice_label)
	_roll_button = Button.new()
	_roll_button.name = "RollButton"
	_roll_button.theme_type_variation = &"PrimaryButton"
	_roll_button.custom_minimum_size.y = 76
	_roll_button.text = "TIRAR D4"
	_roll_button.pressed.connect(_on_roll_pressed)
	content.add_child(_roll_button)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(actions)
	_pause_button = Button.new()
	_pause_button.text = "PAUSA"
	_pause_button.pressed.connect(func() -> void: pause_requested.emit())
	actions.add_child(_pause_button)
	_seed_label = Label.new()
	_seed_label.text = "SANDBOX · SEED %d" % _run.board_seed
	_seed_label.visible = _playtest_mode
	actions.add_child(_seed_label)
	_reset_button = Button.new()
	_reset_button.text = "RESET"
	_reset_button.visible = _sandbox_mode
	_reset_button.pressed.connect(_reset_sandbox)
	actions.add_child(_reset_button)


func _on_roll_pressed() -> void:
	if _is_moving or _interaction_pending or _turn_controller == null or _turn_controller.is_turn_locked():
		return
	var plan: Dictionary = _turn_controller.request_roll(_forced_dice_result)
	if plan.is_empty():
		return
	var result: int = int(plan["roll"])
	var origin: int = int(plan["origin"])
	var destination: int = int(plan["destinations"][0])
	_is_moving = true
	_roll_button.disabled = true
	_pause_button.disabled = true
	_dice_label.text = "D4 · %d" % result
	_event_label.text = "Resultado confirmado."
	AudioManager.play_event(AudioManager.AudioEvent.DICE_ROLL)
	await get_tree().create_timer(ROLL_REVEAL_DELAY).timeout
	AudioManager.play_event(AudioManager.AudioEvent.DICE_LAND)
	_event_label.text = "Avanzando %d casillas..." % (destination - origin)
	await _move_player_to(destination)
	var resolution: Dictionary = _turn_controller.request_tile_resolution()
	if not resolution.is_empty():
		await _resolve_current_tile(int(resolution["tile_type"]))
	_turn_controller.complete_resolution()
	_finish_input_cycle()


func _move_player_to(destination: int) -> void:
	while true:
		if int(_turn_controller.get("state")) == BoardTurnControllerSource.State.ROUTE_DECISION:
			await _handle_fork_pause()
			_update_current_tile(_run.board_position)
			if int(_turn_controller.get("state")) != BoardTurnControllerSource.State.MOVING:
				break
			continue
		if not _turn_controller.has_pending_steps():
			break
		var to_index: int = _turn_controller.advance_one_step()
		if to_index < 0:
			return
		var start: Vector3 = player_marker.position
		var target: Vector3 = _effective_position(to_index) + Vector3(0.0, 1.05, 0.0)
		var flat_target := Vector3(target.x, player_marker.position.y, target.z)
		if player_marker.position.distance_to(flat_target) > 0.01:
			player_marker.look_at(flat_target, Vector3.UP)
		var look_ahead: Vector3 = _effective_position(mini(to_index + 2, _run.board_tile_sequence.size() - 1)) + Vector3(0.0, 1.05, 0.0)
		camera_rig.follow_step_to_position(target, look_ahead, MOVE_DURATION)
		var midpoint: Vector3 = start.lerp(target, 0.5) + Vector3(0.0, 0.38, 0.0)
		var tween := create_tween()
		tween.tween_property(player_marker, "position", midpoint, MOVE_DURATION * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(player_marker, "position", target, MOVE_DURATION * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tween.finished
		AudioManager.play_event(AudioManager.AudioEvent.BOARD_STEP)
		_pulse_player()
		_update_current_tile(to_index)
		_update_hud()
	camera_rig.focus_arrival(destination, _positions)
	await get_tree().create_timer(0.12).timeout
	camera_rig.focus_navigation(destination, _positions)


## Intercepción obligatoria: MOVE llegó a un FORK sin carril elegido. No
## consume ni agrega movimiento del roll actual, y no resuelve contenido.
func _handle_fork_pause() -> void:
	var fork_index: int = int(_turn_controller.get("_pending_fork_index"))
	var branch_data: RefCounted = _run.route_branches.get(fork_index)
	if branch_data == null:
		_turn_controller.abort_turn()
		return
	var lanes: Dictionary = _branch_positions.get(fork_index, {})
	var focus_points: Array[Vector3] = [_positions[fork_index]]
	for branch: int in [RouteBranchDataSource.ROUTE_A, RouteBranchDataSource.ROUTE_B]:
		for position: Vector3 in (lanes.get(branch, []) as Array):
			focus_points.append(position)
	camera_rig.focus_world_points(focus_points)
	var chosen: int = await _request_branch_choice(fork_index, branch_data)
	_turn_controller.choose_branch(chosen)


## Partial Information aprobada: identidad + peligro + enfoque + primer nodo
## visible; nunca revela las 4 casillas completas. Overlay 2D simple sobre el
## HUD — ambos carriles ya son visibles/comparables en el mundo 3D detrás.
func _request_branch_choice(fork_index: int, branch_data: RefCounted) -> int:
	_event_label.text = "BIFURCACIÓN · elegí tu ruta"
	if not _sandbox_mode:
		TelemetryManager.track_route_choice_shown(
			_run, _tile_type_key(branch_data.first_tile_for(RouteBranchDataSource.ROUTE_A)),
			_tile_type_key(branch_data.first_tile_for(RouteBranchDataSource.ROUTE_B)), 1, 1,
		)
	var overlay := PanelContainer.new()
	overlay.name = "BranchChoiceOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hud_layer.add_child(overlay)
	var rows := HBoxContainer.new()
	rows.add_theme_constant_override("separation", 18)
	overlay.add_child(rows)
	for branch: int in [RouteBranchDataSource.ROUTE_A, RouteBranchDataSource.ROUTE_B]:
		var archetype: StringName = branch_data.archetype_for(branch)
		# L0 (2026-09-08): antes A y B sólo se distinguían por la letra en texto
		# plano. El color de peligro (mismo VisualTheme.difficulty_color que ya
		# usa el resto de la UI) + un ícono de enfoque (mismos ids que combate/
		# curación/tesoro en el resto del juego) dan una segunda y tercera señal
		# no basada únicamente en leer el texto.
		var accent: Color = VisualTheme.difficulty_color(RouteBranchDataSource.danger_tier(archetype))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		var icon := AshenIcon.new()
		icon.configure(RouteBranchDataSource.icon_id(archetype), accent, AshenIcon.DisplaySize.LARGE)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
		var button := Button.new()
		button.custom_minimum_size = Vector2(200, 130)
		button.add_theme_stylebox_override("normal", VisualTheme.button_style(VisualTheme.CARD, accent, 3))
		button.add_theme_stylebox_override("hover", VisualTheme.button_style(VisualTheme.CARD.lightened(0.08), accent, 4))
		button.add_theme_stylebox_override("focus", VisualTheme.button_style(VisualTheme.CARD.lightened(0.08), accent, 4))
		var label: String = "A" if branch == RouteBranchDataSource.ROUTE_A else "B"
		button.text = "RUTA %s\n%s\nPELIGRO: %s\nENFOQUE: %s\n1er nodo: %s" % [
			label, RouteBranchDataSource.display_name(archetype), RouteBranchDataSource.danger_label(archetype),
			RouteBranchDataSource.focus_label(archetype), _tile_type_key(branch_data.first_tile_for(branch)).to_upper(),
		]
		button.pressed.connect(func() -> void: branch_choice_selected.emit(branch))
		column.add_child(button)
		rows.add_child(column)
	var chosen: int = await branch_choice_selected
	overlay.queue_free()
	var archetype_chosen: StringName = branch_data.archetype_for(chosen)
	_event_label.text = "RUTA %s ELEGIDA · %s" % [
		"A" if chosen == RouteBranchDataSource.ROUTE_A else "B", RouteBranchDataSource.display_name(archetype_chosen),
	]
	if not _sandbox_mode:
		TelemetryManager.track_route_choice_selected(_run, _tile_type_key(branch_data.first_tile_for(chosen)), 1)
	return chosen


## Posición mundial de `index` según el carril activo (ver RouteBranchData);
## fuera de una rama activa devuelve la posición normal del spine.
func _effective_position(index: int) -> Vector3:
	if _run.active_branch != RouteBranchDataSource.NONE and _run.active_fork_index >= 0:
		var fork_index: int = _run.active_fork_index
		if index > fork_index and index <= fork_index + RouteBranchDataSource.BRANCH_LENGTH:
			var local_position: int = index - fork_index - 1
			return _branch_positions[fork_index][_run.active_branch][local_position]
	return _positions[clampi(index, 0, _positions.size() - 1)]


func _resolve_current_tile(tile_type: int) -> void:
	var intent: int = BoardTileResolutionAdapterSource.get_intent(tile_type)
	match intent:
		BoardTileResolutionAdapterSource.Intent.HEAL:
			var result: Dictionary = BoardTileResolutionAdapterSource.resolve_inline(intent, _run)
			_event_label.text = "CURACIÓN · +%d VIDA" % int(result.get("recovered", 0))
			AudioManager.play_event(AudioManager.AudioEvent.HEAL)
		BoardTileResolutionAdapterSource.Intent.COMBAT:
			_event_label.text = "Un enemigo bloquea el camino"
			_request_external_interaction(&"combat", false, false)
		BoardTileResolutionAdapterSource.Intent.ELITE:
			_event_label.text = "ENCUENTRO ÉLITE"
			_request_external_interaction(&"elite", false, true)
		BoardTileResolutionAdapterSource.Intent.BOSS:
			_event_label.text = "JEFE · ASHEN WARDEN"
			_request_external_interaction(&"boss", true, false)
		BoardTileResolutionAdapterSource.Intent.EVENT:
			_event_label.text = "La ceniza oculta una decisión"
			_request_external_interaction(&"event")
		BoardTileResolutionAdapterSource.Intent.TREASURE:
			_event_label.text = "Un tesoro olvidado te espera"
			_request_external_interaction(&"treasure")
		_:
			var result: Dictionary = BoardTileResolutionAdapterSource.resolve_inline(intent, _run)
			_event_label.text = String(result.get("message", "El camino está despejado"))
	_update_hud()


func _request_external_interaction(kind: StringName, is_boss: bool = false, is_elite: bool = false) -> void:
	# Al ejecutar la escena directamente no existe Game para abrir pantallas. El
	# sandbox informa la misma intención lógica y continúa sin tocar perfil/save.
	if _sandbox_mode:
		_event_label.text += " · SOLICITUD SANDBOX"
		match kind:
			&"combat", &"elite", &"boss": combat_requested.emit(is_boss, is_elite)
			&"event": event_requested.emit()
			&"treasure": treasure_requested.emit()
		return
	_interaction_pending = true
	if is_boss:
		_run.board_locked = true
	match kind:
		&"combat", &"elite", &"boss": combat_requested.emit(is_boss, is_elite)
		&"event": event_requested.emit()
		&"treasure": treasure_requested.emit()


func resume_after_combat() -> void:
	_interaction_pending = false
	_event_label.text = "¡Victoria! Continuá por el camino."
	_restore_after_interaction()


func resume_after_interaction(message: String) -> void:
	_interaction_pending = false
	_event_label.text = message
	_restore_after_interaction()


func terminate_after_defeat() -> void:
	# Derrota es terminal: invalida cualquier selección/resolución pendiente antes
	# de que Game libere la instancia y abra Results.
	_interaction_pending = true
	_is_moving = false
	_route_input_committed = true
	for destination: int in _pending_route_destinations:
		if destination >= 0 and destination < _tiles.size():
			_tiles[destination].set_route_marker("")
	_pending_route_destinations.clear()
	if _turn_controller != null:
		_turn_controller.abort_turn()
	if _run != null:
		_run.board_locked = true
	if _roll_button != null:
		_roll_button.disabled = true
	if _pause_button != null:
		_pause_button.disabled = true
	set_hud_suspended(true)


func set_hud_suspended(suspended: bool) -> void:
	# El HUD vive en CanvasLayer para quedar siempre delante del mundo 3D. Game
	# lo oculta mientras sus overlays globales de pausa ocupan la pantalla.
	hud_layer.visible = not suspended


func _restore_after_interaction() -> void:
	_place_player_immediately(_run.board_position)
	_update_hud()
	_roll_button.disabled = _run.board_locked
	_pause_button.disabled = false
	camera_rig.focus_navigation(_run.board_position, _positions)


func _finish_input_cycle() -> void:
	_is_moving = false
	_roll_button.disabled = _run.board_locked or _interaction_pending
	_pause_button.disabled = _interaction_pending
	if not _interaction_pending:
		camera_rig.focus_navigation(_run.board_position, _positions)


func _place_player_immediately(index: int) -> void:
	player_marker.position = _effective_position(index) + Vector3(0.0, 1.05, 0.0)
	_update_current_tile(index)


func _update_current_tile(index: int) -> void:
	for tile_index: int in _tiles.size():
		var tile: StaticBody3D = _tiles[tile_index]
		if tile == null:
			# Casilla reservada de un fork: no tiene tile propio en el spine
			# (ver _build_tiles/_is_reserved_branch_window).
			continue
		tile.set_progress_state(tile_index < index, tile_index == index)
	_update_branch_visuals(index)


## Progreso visual de los carriles: el elegido sigue mostrando visitado/actual
## como cualquier tile del spine; el no elegido queda oculto en cuanto hay
## una elección confirmada (nunca se camina, tampoco se ve como si se hiciera).
func _update_branch_visuals(index: int) -> void:
	for fork_index: int in _branch_tiles:
		var lanes: Dictionary = _branch_tiles[fork_index]
		var chosen: int = _run.active_branch if _run.active_fork_index == fork_index else RouteBranchDataSource.NONE
		var committed: bool = chosen != RouteBranchDataSource.NONE or index > fork_index + RouteBranchDataSource.BRANCH_LENGTH
		for branch: int in [RouteBranchDataSource.ROUTE_A, RouteBranchDataSource.ROUTE_B]:
			var tiles: Array = lanes[branch]
			var is_unchosen: bool = committed and branch != chosen
			for local_index: int in tiles.size():
				var tile: StaticBody3D = tiles[local_index]
				var branch_position: int = fork_index + local_index + 1
				tile.visible = not is_unchosen
				if not is_unchosen:
					tile.set_progress_state(branch_position < index, branch_position == index)


func _pulse_player() -> void:
	player_marker.scale = Vector3(1.12, 0.9, 1.12)
	var tween := create_tween()
	tween.tween_property(player_marker, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_hud() -> void:
	if _stats_label == null:
		return
	_stats_label.text = "VIDA %d/%d   ·   ATQ %d   ·   DEF %d   ·   CENIZA %d" % [
		_run.current_health, _run.max_health, _run.attack, _run.defense, _run.run_ash,
	]
	_position_label.text = "POSICIÓN %d / %d" % [_run.board_position + 1, _run.board_tile_sequence.size()]
	_update_diagnostic_label()


func _process(delta: float) -> void:
	if not _playtest_mode or _diagnostic_label == null:
		return
	if _fps_warmup_remaining > 0.0:
		_fps_warmup_remaining -= delta
		_update_diagnostic_label()
		return
	_fps_update_accumulator += delta
	if _fps_update_accumulator < 0.5:
		return
	_fps_update_accumulator = 0.0
	var fps: float = Engine.get_frames_per_second()
	if fps > 0.0:
		_fps_samples += 1
		_fps_total += fps
		_fps_min = minf(_fps_min, fps)
	_update_diagnostic_label()


func _update_diagnostic_label() -> void:
	if _diagnostic_label == null or not _playtest_mode:
		return
	if _fps_samples == 0:
		_diagnostic_label.text = "FPS -- · MIN -- · AVG -- · INDEX %d · SEED %d" % [
			_run.board_position, _run.board_seed,
		]
		return
	var current_fps: int = Engine.get_frames_per_second()
	var average_fps: float = _fps_total / float(_fps_samples) if _fps_samples > 0 else float(current_fps)
	var minimum_fps: float = _fps_min if _fps_samples > 0 else float(current_fps)
	_diagnostic_label.text = "FPS %d · MIN %.0f · AVG %.0f · INDEX %d · SEED %d" % [
		current_fps, minimum_fps, average_fps, _run.board_position, _run.board_seed,
	]


func _reset_sandbox() -> void:
	if not _sandbox_mode or _is_moving:
		return
	_run = MapSandboxContextSource.create_run()
	get_tree().reload_current_scene()


func _input(event: InputEvent) -> void:
	_handle_route_input(event)


func _unhandled_input(event: InputEvent) -> void:
	# Respaldo para eventos enviados directamente por tests/herramientas. En PC el
	# camino principal debe ser _input(), antes de que el HUD fullscreen consuma GUI.
	_handle_route_input(event)


func _handle_route_input(event: InputEvent) -> void:
	if not _is_route_selection_active():
		return
	var accepted := false
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accepted = _try_select_route(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			accepted = _try_select_route(event.position)
	elif event is InputEventKey:
		if event.pressed and not event.echo:
			var keycode: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			if keycode == KEY_A:
				accepted = _try_commit_route_selection(_pending_route_destinations[0])
			elif keycode == KEY_B and _pending_route_destinations.size() == 2:
				accepted = _try_commit_route_selection(_pending_route_destinations[1])
	if accepted:
		get_viewport().set_input_as_handled()


func _try_select_route(screen_position: Vector2) -> bool:
	if not _is_route_selection_active():
		return false
	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_end: Vector3 = origin + camera.project_ray_normal(screen_position) * 200.0
	var excluded: Array[RID] = []
	var candidates: Array[int] = []
	# Los touch targets A/B pueden solaparse para que sean cómodos en móvil. Se
	# recorren sólo esos impactos y se elige el centro proyectado más cercano.
	for _pass: int in _pending_route_destinations.size():
		var query := PhysicsRayQueryParameters3D.create(origin, ray_end, 1, excluded)
		var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
		var collider: Object = hit.get("collider")
		if collider == null or not collider is StaticBody3D or collider.get_script() != MapTile3DSource:
			break
		var selected: int = int(collider.get("board_index"))
		if selected < 0 or selected >= _tiles.size() or _tiles[selected] != collider:
			return false
		if selected not in _pending_route_destinations:
			return false
		candidates.append(selected)
		excluded.append((collider as StaticBody3D).get_rid())
	if candidates.is_empty():
		return false
	var closest: int = candidates[0]
	var closest_distance: float = INF
	for destination: int in candidates:
		var projected_center: Vector2 = camera.unproject_position(
			_tiles[destination].global_position + Vector3(0.0, 0.25, 0.0)
		)
		var distance: float = projected_center.distance_squared_to(screen_position)
		if distance < closest_distance:
			closest = destination
			closest_distance = distance
	return _try_commit_route_selection(closest)


func _try_commit_route_selection(destination: int) -> bool:
	if not _is_route_selection_active() or destination not in _pending_route_destinations:
		return false
	_route_input_committed = true
	var option_index: int = _pending_route_destinations.find(destination)
	_event_label.text = "RUTA %s CONFIRMADA" % ("A" if option_index == 0 else "B")
	route_destination_selected.emit(destination)
	return true


func _is_route_selection_active() -> bool:
	if _pending_route_destinations.size() != 2 or _route_input_committed or camera == null or _turn_controller == null:
		return false
	return int(_turn_controller.get("state")) == BoardTurnControllerSource.State.ROUTE_SELECTION


func _tile_type_key(type: int) -> String:
	match type:
		BoardTileData.TileType.COMBAT: return "combat"
		BoardTileData.TileType.HEAL: return "heal"
		BoardTileData.TileType.BOSS: return "boss"
		BoardTileData.TileType.EVENT: return "event"
		BoardTileData.TileType.TREASURE: return "treasure"
		BoardTileData.TileType.ELITE: return "elite"
		_: return "empty"

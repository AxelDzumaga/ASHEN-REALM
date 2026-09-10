class_name MapTile3D
extends StaticBody3D

var board_index: int = -1
var tile_type: int = BoardTileData.TileType.EMPTY
var _base_scale := Vector3.ONE
var _route_label: Label3D
var _platform: MeshInstance3D
var _dim_materials: Array[StandardMaterial3D] = []
var _dim_base_colors: Array[Color] = []
var _dim_base_emission: Array[float] = []
var _current_glow: MeshInstance3D
var _is_current := false
var _is_visited := false
var _route_tween: Tween
var _glow_tween: Tween


func configure(index: int, type: int, material: Material) -> void:
	board_index = index
	tile_type = type
	name = "Tile%02d" % index
	collision_layer = 1
	collision_mask = 0
	_build_platform(material)
	_build_current_glow()
	_build_index_label()
	_base_scale = scale


func set_route_marker(marker: String) -> void:
	_route_label.text = marker
	_route_label.visible = not marker.is_empty()
	if _route_tween != null and _route_tween.is_valid():
		_route_tween.kill()
	_route_tween = null
	if _route_label.visible:
		scale = _base_scale * 1.14
		_route_tween = create_tween().set_loops()
		_route_tween.tween_property(self, "scale", _base_scale * 1.24, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_route_tween.tween_property(self, "scale", _base_scale * 1.14, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_apply_progress_visual()


func set_current(active: bool) -> void:
	_is_current = active
	if not _route_label.visible:
		_apply_progress_visual()


## Cierto mientras la casilla está actualmente renderizada con el color
## atenuado (ver _apply_progress_visual) — expuesto para tests, ya que el
## mecanismo real es un cambio de color de material, no GeometryInstance3D.transparency
## (esa propiedad no tiene efecto bajo el renderer Mobile del proyecto).
func is_visually_dimmed() -> bool:
	return not _dim_materials.is_empty() and not _dim_materials[0].albedo_color.is_equal_approx(_dim_base_colors[0])


func set_progress_state(visited: bool, current: bool) -> void:
	_is_visited = visited
	_is_current = current
	if not _route_label.visible:
		_apply_progress_visual()


func _apply_progress_visual() -> void:
	scale = _base_scale * (1.11 if _is_current else (0.96 if _is_visited else 1.0))
	# GeometryInstance3D.transparency no tiene efecto visual bajo el renderer
	# Mobile (solo Forward+), así que "atenuada" se logra oscureciendo el color
	# propio de cada casilla en vez de hacerla transparente.
	var dim: bool = _is_visited and not _is_current
	for index: int in _dim_materials.size():
		var dim_material: StandardMaterial3D = _dim_materials[index]
		var base_color: Color = _dim_base_colors[index]
		var base_emission: float = _dim_base_emission[index]
		dim_material.albedo_color = base_color.lerp(Color("120f11"), 0.62) if dim else base_color
		dim_material.emission_energy_multiplier = base_emission * 0.25 if dim else base_emission
	if _current_glow != null:
		_current_glow.visible = _is_current
		if _is_current and (_glow_tween == null or not _glow_tween.is_valid()):
			_start_glow_pulse()
		elif not _is_current and _glow_tween != null and _glow_tween.is_valid():
			_glow_tween.kill()


## Anillo emisivo propio (material no compartido con otras casillas) que marca
## la posición lógica actual, independiente del marcador del jugador — legible
## incluso en la vista de mapa completo, donde el marcador queda muy chico.
func _build_current_glow() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 1.55
	ring.outer_radius = 1.85
	ring.rings = 16
	ring.ring_segments = 6
	var glow_material := StandardMaterial3D.new()
	glow_material.albedo_color = Color("ffc866")
	glow_material.emission_enabled = true
	glow_material.emission = Color("ffc866")
	glow_material.emission_energy_multiplier = 1.4
	ring.material = glow_material
	_current_glow = MeshInstance3D.new()
	_current_glow.name = "CurrentGlow"
	_current_glow.mesh = ring
	# Por encima de la superficie de cualquier tipo de plataforma (la más alta,
	# BOSS, llega a ~0.41) para que el anillo no quede clipeado dentro del mesh.
	_current_glow.position.y = 0.55
	_current_glow.visible = false
	add_child(_current_glow)


func _start_glow_pulse() -> void:
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(_current_glow, "position:y", 0.62, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glow_tween.tween_property(_current_glow, "position:y", 0.55, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_platform(material: Material) -> void:
	_platform = MeshInstance3D.new()
	_platform.name = "Platform"
	var collider := CollisionShape3D.new()
	collider.name = "TouchTarget"
	var mesh: PrimitiveMesh
	var collision_shape: Shape3D
	match tile_type:
		BoardTileData.TileType.COMBAT:
			var box := BoxMesh.new()
			box.size = Vector3(2.15, 0.42, 2.15)
			mesh = box
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(2.7, 1.1, 2.7)
			collision_shape = box_shape
		BoardTileData.TileType.EVENT:
			var box := BoxMesh.new()
			box.size = Vector3(1.8, 0.5, 1.8)
			mesh = box
			_platform.rotation.y = PI * 0.25
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(2.7, 1.1, 2.7)
			collision_shape = box_shape
		BoardTileData.TileType.ELITE:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 1.35
			cylinder.bottom_radius = 1.5
			cylinder.height = 0.72
			cylinder.radial_segments = 6
			mesh = cylinder
			collision_shape = _cylinder_shape(1.75, 1.25)
		BoardTileData.TileType.BOSS:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 2.0
			cylinder.bottom_radius = 2.25
			cylinder.height = 0.82
			cylinder.radial_segments = 10
			mesh = cylinder
			collision_shape = _cylinder_shape(2.55, 1.4)
		BoardTileData.TileType.FORK:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 1.35
			cylinder.bottom_radius = 1.55
			cylinder.height = 0.5
			cylinder.radial_segments = 8
			mesh = cylinder
			collision_shape = _cylinder_shape(1.8, 1.1)
		BoardTileData.TileType.TREASURE:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 1.15
			cylinder.bottom_radius = 1.35
			cylinder.height = 0.55
			cylinder.radial_segments = 8
			mesh = cylinder
			collision_shape = _cylinder_shape(1.7, 1.1)
		_:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 1.15
			cylinder.bottom_radius = 1.25
			cylinder.height = 0.42 if tile_type == BoardTileData.TileType.EMPTY else 0.55
			cylinder.radial_segments = 16 if tile_type == BoardTileData.TileType.EMPTY else 10
			mesh = cylinder
			collision_shape = _cylinder_shape(1.65, 1.05)
	# El collider táctil es deliberadamente más amplio que la plataforma. Sólo
	# afecta hit-testing de routing; la silueta y las reglas no cambian.
	var touch_shape := BoxShape3D.new()
	touch_shape.size = Vector3(5.0, 1.8, 5.0) if tile_type == BoardTileData.TileType.BOSS else Vector3(3.6, 1.5, 3.6)
	collision_shape = touch_shape
	mesh.material = material
	_platform.mesh = mesh
	add_child(_platform)
	_register_dimmable(_platform)
	collider.shape = collision_shape
	collider.position.y = 0.25
	add_child(collider)
	_add_type_detail(material)
	_add_boss_silhouette(material)


## Le da a `node` un material propio (no compartido con otras casillas del
## mismo tipo) para poder oscurecerlo individualmente cuando queda visitado,
## sin afectar el resto de las casillas que usan el mismo Material base.
func _register_dimmable(node: MeshInstance3D) -> void:
	var base_material: StandardMaterial3D = node.mesh.surface_get_material(0) as StandardMaterial3D
	if base_material == null:
		return
	var owned_material: StandardMaterial3D = base_material.duplicate()
	node.material_override = owned_material
	_dim_materials.append(owned_material)
	_dim_base_colors.append(owned_material.albedo_color)
	_dim_base_emission.append(owned_material.emission_energy_multiplier)


func _add_boss_silhouette(material: Material) -> void:
	if tile_type != BoardTileData.TileType.BOSS:
		return
	var spike_mesh := CylinderMesh.new()
	spike_mesh.top_radius = 0.0
	spike_mesh.bottom_radius = 0.22
	spike_mesh.height = 1.05
	spike_mesh.radial_segments = 6
	spike_mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = spike_mesh
	multimesh.instance_count = 6
	for index: int in multimesh.instance_count:
		var angle: float = TAU * float(index) / float(multimesh.instance_count)
		var position := Vector3(cos(angle) * 1.55, 0.78, sin(angle) * 1.55)
		multimesh.set_instance_transform(index, Transform3D(Basis(Vector3.UP, -angle), position))
	var spikes := MultiMeshInstance3D.new()
	spikes.name = "BossSpikes"
	spikes.multimesh = multimesh
	add_child(spikes)


func _add_type_detail(material: Material) -> void:
	var detail := MeshInstance3D.new()
	detail.name = "TypeDetail"
	detail.position.y = 0.48
	var mesh: PrimitiveMesh
	match tile_type:
		BoardTileData.TileType.HEAL:
			var bar := BoxMesh.new()
			bar.size = Vector3(1.1, 0.16, 0.3)
			mesh = bar
		BoardTileData.TileType.TREASURE:
			var chest := BoxMesh.new()
			chest.size = Vector3(1.0, 0.7, 0.72)
			mesh = chest
			detail.position.y = 0.68
		BoardTileData.TileType.ELITE:
			var crown := CylinderMesh.new()
			crown.top_radius = 0.0
			crown.bottom_radius = 0.55
			crown.height = 0.9
			crown.radial_segments = 6
			mesh = crown
			detail.position.y = 0.85
		BoardTileData.TileType.BOSS:
			var crown := CylinderMesh.new()
			crown.top_radius = 0.18
			crown.bottom_radius = 0.85
			crown.height = 1.35
			crown.radial_segments = 8
			mesh = crown
			detail.position.y = 1.05
		BoardTileData.TileType.COMBAT:
			var blade := BoxMesh.new()
			blade.size = Vector3(1.35, 0.16, 0.24)
			mesh = blade
			detail.rotation.y = PI * 0.25
		BoardTileData.TileType.EVENT:
			var marker := PrismMesh.new()
			marker.size = Vector3(0.7, 0.9, 0.7)
			mesh = marker
			detail.position.y = 0.8
		BoardTileData.TileType.FORK:
			# Cuña simple; una segunda copia rotada (agregada más abajo, igual
			# que HEAL) forma el glifo de "bifurcación" legible desde arriba.
			var wedge := PrismMesh.new()
			wedge.size = Vector3(0.4, 0.55, 1.1)
			mesh = wedge
			detail.position.y = 0.75
		_:
			return
	mesh.material = material
	detail.mesh = mesh
	add_child(detail)
	_register_dimmable(detail)
	if tile_type == BoardTileData.TileType.HEAL or tile_type == BoardTileData.TileType.FORK:
		var second := detail.duplicate() as MeshInstance3D
		second.rotation.y = PI * 0.5
		add_child(second)
		_register_dimmable(second)


func _build_index_label() -> void:
	var label := Label3D.new()
	label.name = "IndexLabel"
	# La identidad lógica sigue siendo 0..29; la etiqueta para el jugador es 1..30.
	label.text = "%02d" % (board_index + 1)
	label.font_size = 36
	label.outline_size = 8
	label.modulate = Color("f0dfc2")
	label.position = Vector3(0.0, 1.2 if tile_type != BoardTileData.TileType.BOSS else 1.8, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)
	_route_label = Label3D.new()
	_route_label.name = "RouteLabel"
	_route_label.font_size = 72
	_route_label.outline_size = 14
	_route_label.modulate = Color("ffc866")
	_route_label.position = label.position + Vector3(0.0, 0.85, 0.0)
	_route_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_route_label.no_depth_test = true
	_route_label.visible = false
	add_child(_route_label)


func _cylinder_shape(radius: float, height: float) -> CylinderShape3D:
	var result := CylinderShape3D.new()
	result.radius = radius
	result.height = height
	return result

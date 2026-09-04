extends Control

signal back_requested

var _list: VBoxContainer
var _detail: Label
var _refine_button: Button
var _selected_id := ""


func _ready() -> void:
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("0b090d")
	add_child(background)
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -360
	frame.offset_top = -640
	frame.offset_right = 360
	frame.offset_bottom = 640
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		frame.add_theme_constant_override(side, 32)
	add_child(frame)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	frame.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var back := Button.new()
	back.text = "VOLVER"
	back.custom_minimum_size = Vector2(120, 58)
	back.pressed.connect(back_requested.emit)
	top.add_child(back)
	var title := Label.new()
	title.text = "FORJA · REFINAMIENTO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", VisualTheme.FONT_SECTION)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var resources := Label.new()
	resources.text = "CENIZA %d  ·  FRAG %d  ·  SIGILOS %d" % [SaveManager.profile.total_ash, SaveManager.profile.forge_shards, SaveManager.profile.guardian_sigils]
	resources.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resources.modulate = VisualTheme.EMBER_BRIGHT
	root.add_child(resources)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 610)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(0, 230)
	detail_panel.add_theme_stylebox_override("panel", VisualTheme.elevated_panel_style(VisualTheme.CARD, VisualTheme.EMBER, 2, 12))
	root.add_child(detail_panel)
	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_panel.add_child(_detail)
	_refine_button = Button.new()
	_refine_button.custom_minimum_size = Vector2(0, 82)
	_refine_button.theme_type_variation = &"PrimaryButton"
	_refine_button.pressed.connect(_on_refine)
	root.add_child(_refine_button)


func _refresh() -> void:
	for child: Node in _list.get_children():
		child.free()
	var owned_ids: Array[String] = []
	for equipment_id: Variant in SaveManager.profile.owned_equipment:
		if int(SaveManager.profile.owned_equipment[equipment_id]) > 0:
			owned_ids.append(String(equipment_id))
	owned_ids.sort()
	if _selected_id.is_empty() and not owned_ids.is_empty():
		_selected_id = owned_ids[0]
	for id: String in owned_ids:
		var item := EquipmentCatalog.get_by_id(id)
		var level: int = int(SaveManager.profile.equipment_refinement.get(id, 0))
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 68)
		button.text = "%s  ·  %s  ·  +%d" % [EquipmentCatalog.get_slot_label(item.slot), item.display_name.to_upper(), level]
		button.disabled = id == _selected_id
		button.pressed.connect(_select.bind(id))
		_list.add_child(button)
	_update_detail()


func _select(id: String) -> void:
	_selected_id = id
	_refresh()


func _update_detail() -> void:
	var item := EquipmentCatalog.get_by_id(_selected_id)
	if item == null:
		_detail.text = "No hay equipo para refinar."
		_refine_button.disabled = true
		return
	var current: int = int(SaveManager.profile.equipment_refinement.get(_selected_id, 0))
	var cost: Dictionary = RefinementConfig.get_cost(item, current)
	if cost.is_empty():
		_detail.text = "%s\nREFINAMIENTO MÁXIMO +%d" % [item.display_name.to_upper(), current]
		_refine_button.text = "MÁXIMO ALCANZADO"
		_refine_button.disabled = true
		return
	var before: int = RefinementConfig.get_primary_bonus(current)
	var after: int = RefinementConfig.get_primary_bonus(int(cost["target_level"]))
	var material_cost: int = int(cost.get("biome_material", 0))
	var material_line: String = ""
	if material_cost > 0:
		var material_key: String = RefinementConfig.get_biome_material_key(item)
		var material_name: String = "MATERIAL DE BIOMA"
		if not material_key.is_empty():
			var biome: BiomeData = BiomeCatalog.get_by_id(StringName(material_key))
			if biome != null and not biome.material_name.is_empty():
				material_name = biome.material_name.to_upper()
		material_line = "\n%d %s" % [material_cost, material_name]
	_detail.text = "%s  [%s]\nACTUAL +%d  →  SIGUIENTE +%d\nBONUS PRINCIPAL +%d  →  +%d\nCOSTO  %d CENIZA  ·  %d FRAG  ·  %d SIGILOS%s\nGarantizado · el ítem nunca se destruye" % [item.display_name.to_upper(), EquipmentCatalog.get_rarity_name(item.rarity).to_upper(), current, int(cost["target_level"]), before, after, int(cost["ash"]), int(cost["forge_shards"]), int(cost["guardian_sigils"]), material_line]
	_refine_button.text = "REFINAR A +%d" % int(cost["target_level"])
	_refine_button.disabled = (
		SaveManager.profile.total_ash < int(cost["ash"])
		or SaveManager.profile.forge_shards < int(cost["forge_shards"])
		or SaveManager.profile.guardian_sigils < int(cost["guardian_sigils"])
		or not RefinementConfig.has_enough_biome_material(SaveManager.profile, item, material_cost)
	)


func _on_refine() -> void:
	if SaveManager.refine_equipment(_selected_id):
		_refresh()
	else:
		_refine_button.text = "RECURSOS INSUFICIENTES"

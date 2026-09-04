extends Control

signal back_requested

@onready var ash_label: Label = %AshLabel
@onready var wastes_button: Button = %AshenWastesButton
@onready var marsh_button: Button = %EmberMarshButton
@onready var wastes_preview: PanelContainer = %AshenWastesPreview
@onready var wastes_thumbnail: TextureRect = %AshenWastesThumbnail
@onready var marsh_preview: PanelContainer = %EmberMarshPreview
@onready var marsh_thumbnail: TextureRect = %EmberMarshThumbnail
@onready var description_label: Label = %DescriptionLabel
@onready var back_button: Button = %BackButton


func _ready() -> void:
	wastes_button.pressed.connect(_on_biome_selected.bind(BiomeCatalog.ASHEN_WASTES.id))
	marsh_button.pressed.connect(_on_biome_selected.bind(BiomeCatalog.EMBER_MARSH.id))
	back_button.pressed.connect(_on_back_pressed)
	SaveManager.profile_changed.connect(_refresh)
	_refresh()
	_get_selected_button().grab_focus()
	TutorialManager.request(TutorialCatalog.BIOME_RULES, TutorialManager.CONTEXT_REGION, self)


func _refresh() -> void:
	ash_label.text = "CENIZA  ·  %d" % SaveManager.profile.total_ash
	var completed: Array[String] = SaveManager.profile.completed_milestone_ids
	var selected: BiomeData = BiomeCatalog.get_available_or_default(SaveManager.profile.selected_biome_id, completed)
	var wastes_unlocked: bool = BiomeCatalog.is_unlocked(BiomeCatalog.ASHEN_WASTES, completed)
	var marsh_unlocked: bool = BiomeCatalog.is_unlocked(BiomeCatalog.EMBER_MARSH, completed)
	wastes_button.disabled = not wastes_unlocked
	marsh_button.disabled = not marsh_unlocked
	wastes_button.text = _button_text(BiomeCatalog.ASHEN_WASTES, selected.id == BiomeCatalog.ASHEN_WASTES.id, wastes_unlocked)
	marsh_button.text = _button_text(BiomeCatalog.EMBER_MARSH, selected.id == BiomeCatalog.EMBER_MARSH.id, marsh_unlocked)
	description_label.tooltip_text = _description_text(selected)
	description_label.text = _compact_description_text(selected)
	_decorate_biome_button(wastes_button, BiomeCatalog.ASHEN_WASTES, selected.id == BiomeCatalog.ASHEN_WASTES.id, wastes_unlocked)
	_decorate_biome_button(marsh_button, BiomeCatalog.EMBER_MARSH, selected.id == BiomeCatalog.EMBER_MARSH.id, marsh_unlocked)
	_update_preview(wastes_preview, wastes_thumbnail, BiomeCatalog.ASHEN_WASTES)
	_update_preview(marsh_preview, marsh_thumbnail, BiomeCatalog.EMBER_MARSH)


func _update_preview(panel: PanelContainer, thumbnail: TextureRect, biome: BiomeData) -> void:
	var texture: Texture2D = biome.get_board_thumbnail()
	thumbnail.texture = texture
	panel.visible = texture != null
	panel.add_theme_stylebox_override("panel", VisualTheme.elevated_panel_style(biome.panel_color, biome.accent_color, 2, 12))


func _button_text(biome: BiomeData, selected: bool, unlocked: bool) -> String:
	var status: String = "ACTIVA  ✓" if selected else "EXPLORAR"
	if not unlocked:
		var milestone: MilestoneData = MilestoneCatalog.get_by_id(biome.required_milestone_id)
		status = "LOCK  ·  %s" % (milestone.display_name.to_upper() if milestone != null else "HITO")
	return "%s\n%s  ·  NIV REC %d\n%s" % [
		biome.display_name.to_upper(), _theme_label(biome), biome.recommended_level, status,
	]


func _compact_description_text(biome: BiomeData) -> String:
	var boss_name: String = biome.boss.display_name.to_upper() if biome.boss != null else "SIN DEFINIR"
	return "%s\n%s\nJEFE FINAL  ·  %s  ·  30 CASILLAS" % [
		biome.subtitle,
		BiomeModifierResolver.get_labeled_compact_summary(biome),
		boss_name,
	]


func _theme_label(biome: BiomeData) -> String:
	match biome.theme_family:
		&"dark_wetland": return "HUMEDAL OSCURO"
		&"ashen_badlands": return "RUINAS DE CENIZA"
		_: return String(biome.theme_family).replace("_", " ").to_upper()


func _description_text(biome: BiomeData) -> String:
	var boss_data: BossEncounterData = biome.boss.boss_encounter if biome.boss != null else null
	var boss_summary: String = "JEFE FINAL · %s" % biome.boss.display_name.to_upper() if biome.boss != null else "JEFE FINAL · SIN DEFINIR"
	if boss_data != null:
		boss_summary = "%s · %s · %s · %d FASES\n%s" % [
			boss_data.get_role_label(), boss_data.display_name.to_upper(), boss_data.get_threat_label(),
			boss_data.phases.size(), boss_data.mechanic_description,
		]
	return "%s\n\nDIFICULTAD %s · %s · PELIGRO %d/5\n%s\n\n%s\n\n%s\nENCUENTROS INTERMEDIOS · %d ÉLITES ALEATORIOS" % [
		biome.subtitle, biome.get_difficulty_label(), biome.difficulty_summary,
		biome.danger_rating, BiomeModifierResolver.get_detailed_summary(biome), boss_summary,
		"La expedición termina siempre en su jefe final.", biome.elite_enemy_pool.size(),
	]


func _decorate_biome_button(button: Button, biome: BiomeData, selected: bool, unlocked: bool) -> void:
	for state: String in ["normal", "hover", "focus", "pressed", "disabled"]:
		var background := biome.panel_color
		var border := biome.accent_color if unlocked else VisualTheme.LOCKED
		var width := 4 if selected else 2
		if state == "hover" or state == "focus":
			background = background.lightened(0.08)
			width = maxi(width, 3)
		elif state == "pressed":
			background = background.darkened(0.08)
		elif state == "disabled":
			background = Color("17151a")
		var style := VisualTheme.elevated_panel_style(background, border, width, 14)
		style.content_margin_left = 192.0
		style.content_margin_right = 18.0
		style.content_margin_top = 18.0
		style.content_margin_bottom = 18.0
		button.add_theme_stylebox_override(state, style)
	var decoration := button.get_node_or_null("RegionDecoration") as RegionCardDecoration
	if decoration == null:
		decoration = RegionCardDecoration.new()
		decoration.name = "RegionDecoration"
		button.add_child(decoration)
		decoration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	decoration.configure(biome, selected, unlocked)


func _get_selected_button() -> Button:
	var selected: BiomeData = BiomeCatalog.get_available_or_default(
		SaveManager.profile.selected_biome_id,
		SaveManager.profile.completed_milestone_ids,
	)
	return marsh_button if selected.id == BiomeCatalog.EMBER_MARSH.id else wastes_button


func _on_biome_selected(biome_id: StringName) -> void:
	SaveManager.select_biome(biome_id)


func _on_back_pressed() -> void:
	back_button.disabled = true
	wastes_button.disabled = true
	marsh_button.disabled = true
	back_requested.emit()

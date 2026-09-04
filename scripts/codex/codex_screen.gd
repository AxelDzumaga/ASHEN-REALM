extends Control

signal back_requested

enum ViewMode { MAIN, CATEGORY, DETAIL }

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var progress_label: Label = %ProgressLabel
@onready var content: VBoxContainer = %DynamicContent
@onready var back_button: Button = %BackButton
@onready var discover_all_button: Button = %DiscoverAllButton

var _mode: ViewMode = ViewMode.MAIN
var _category: StringName = &""
var _entry_id: StringName = &""


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	discover_all_button.pressed.connect(_on_discover_all_pressed)
	discover_all_button.visible = DebugConfig.DEBUG_TOOLS_ENABLED
	_show_main()
	TutorialManager.request(TutorialCatalog.ARCHIVE_INTRO, TutorialManager.CONTEXT_CODEX, self)


func _show_main() -> void:
	_mode = ViewMode.MAIN
	_category = &""
	_entry_id = &""
	title_label.text = "ARCHIVO DE CENIZA"
	subtitle_label.text = "Conocimiento reunido a lo largo del Reino."
	_update_global_progress()
	_clear_content()
	for category: StringName in CodexCatalog.get_categories():
		var group_title: String = _group_title_for(category)
		if not group_title.is_empty():
			var header := Label.new()
			header.text = "—  %s  —" % group_title
			header.modulate = VisualTheme.EMBER
			header.add_theme_font_size_override("font_size", 19)
			header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			content.add_child(header)
		var discovered: int = DiscoveryTracker.get_discovered_count(category)
		var total: int = CodexCatalog.get_entries(category).size()
		var button: Button = _create_button("%s%s\n%d / %d" % [
		CodexCatalog.get_category_name(category), "  ·  NUEVO" if DiscoveryTracker.category_has_unseen(category) else "",
			discovered, total,
		])
		_attach_button_icon(button, _category_icon(category), VisualTheme.EMBER)
		button.pressed.connect(_show_category.bind(category))
	back_button.text = "VOLVER AL REFUGIO"
	_focus_first_button()


func _show_category(category: StringName) -> void:
	_mode = ViewMode.CATEGORY
	_category = category
	_entry_id = &""
	title_label.text = "ARCHIVO > %s" % CodexCatalog.get_category_name(category)
	subtitle_label.text = "Seleccioná una entrada descubierta para consultarla."
	progress_label.text = "%d / %d DESCUBIERTAS" % [
		DiscoveryTracker.get_discovered_count(category), CodexCatalog.get_entries(category).size(),
	]
	_clear_content()
	for entry: CodexEntry in CodexCatalog.get_entries(category):
		var discovered: bool = DiscoveryTracker.is_discovered(category, entry.id)
		var is_new: bool = discovered and not DiscoveryTracker.is_seen(category, entry.id)
		var text: String = "%s%s" % [entry.display_name.to_upper(), "  ·  NUEVO" if is_new else ""] if discovered else "???\n%s" % CodexCatalog.get_unknown_title(category)
		var button: Button = _create_button(text)
		if discovered:
			_attach_button_icon(button, _entry_icon(category, entry.id), VisualTheme.TEXT_SECONDARY)
		button.disabled = not discovered
		if discovered:
			button.pressed.connect(_show_detail.bind(entry.id))
	back_button.text = "VOLVER AL ARCHIVO"
	if content.get_child_count() > 0:
		(content.get_child(0) as Control).grab_focus()


func _show_detail(entry_id: StringName) -> void:
	var entry: CodexEntry = CodexCatalog.get_entry(_category, entry_id)
	if entry == null or not DiscoveryTracker.is_discovered(_category, entry_id):
		return
	_mode = ViewMode.DETAIL
	_entry_id = entry_id
	DiscoveryTracker.mark_seen(_category, entry_id)
	title_label.text = entry.display_name.to_upper()
	subtitle_label.text = CodexCatalog.get_category_name(_category)
	progress_label.text = "DESCUBIERTA"
	_clear_content()
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"ArchivePanel"
	panel.custom_minimum_size = Vector2(0, 440)
	var detail_content: VBoxContainer = VBoxContainer.new()
	detail_content.add_theme_constant_override("separation", 18)
	if _category == CodexCatalog.REGIONS:
		_add_biome_preview(detail_content, BiomeCatalog.get_by_id(entry_id))
	elif _category == CodexCatalog.ENEMIES or _category == CodexCatalog.ELITES or _category == CodexCatalog.BOSSES:
		_add_character_portrait(detail_content, CodexCatalog.get_enemy(_category, entry_id))
	var detail: Label = Label.new()
	detail.text = CodexCatalog.get_detail(_category, entry_id, SaveManager.profile)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail.add_theme_font_size_override("font_size", 20)
	detail_content.add_child(detail)
	panel.add_child(detail_content)
	content.add_child(panel)
	back_button.text = "VOLVER A %s" % CodexCatalog.get_category_name(_category)
	back_button.grab_focus()


func debug_show_entry(category: StringName, entry_id: StringName) -> void:
	if not DebugConfig.is_visual_slice_enabled():
		return
	DiscoveryTracker.discover(category, entry_id, false)
	_category = category
	_show_detail(entry_id)


func _add_biome_preview(parent: VBoxContainer, biome: BiomeData) -> void:
	if biome == null:
		return
	var texture: Texture2D = biome.get_board_thumbnail()
	if texture == null:
		return
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(0, 220)
	preview.texture = texture
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = biome.ambient_tint
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(preview)


func _add_character_portrait(parent: VBoxContainer, enemy: EnemyData) -> void:
	var texture: Texture2D = null
	if enemy != null and enemy.visual != null:
		texture = enemy.visual.get_portrait()
	if texture != null:
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(0, 250)
		portrait.texture = texture
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(portrait)
		return
	var fallback := Label.new()
	fallback.custom_minimum_size = Vector2(0, 180)
	fallback.text = "ENEMIGO"
	match _category:
		CodexCatalog.ELITES:
			fallback.text = "ÉLITE"
		CodexCatalog.BOSSES:
			fallback.text = "JEFE"
	fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback.add_theme_font_size_override("font_size", 28)
	fallback.add_theme_stylebox_override("normal", VisualTheme.elevated_panel_style(VisualTheme.CARD, VisualTheme.BORDER, 2, 28))
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fallback)


func _create_button(text: String) -> Button:
	var button: Button = Button.new()
	button.theme_type_variation = &"SecondaryButton"
	button.custom_minimum_size = Vector2(0, 76)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 20)
	button.text = text
	button.add_theme_stylebox_override("normal", VisualTheme.button_style(Color("1c181e"), Color("675846"), 2))
	content.add_child(button)
	return button


func _attach_button_icon(button: Button, icon_id: StringName, color: Color) -> void:
	var icon: AshenIcon = AshenIcon.new()
	icon.configure(icon_id, color, AshenIcon.DisplaySize.MEDIUM)
	icon.position = Vector2(14.0, 18.0)
	button.add_child(icon)


func _category_icon(category: StringName) -> StringName:
	match category:
		CodexCatalog.ENEMIES:
			return &"combat"
		CodexCatalog.ELITES:
			return &"elite"
		CodexCatalog.BOSSES:
			return &"boss"
		CodexCatalog.BOONS:
			return &"boon"
		CodexCatalog.SYNERGIES:
			return &"synergy"
		CodexCatalog.SKILL_AUGMENTS:
			return &"augment"
		CodexCatalog.EQUIPMENT:
			return &"weapon"
		CodexCatalog.ACTIVE_SKILLS:
			return &"skill"
		CodexCatalog.COMPANIONS:
			return &"ember"
		_:
			return &"ash"


func _entry_icon(category: StringName, entry_id: StringName) -> StringName:
	if category == CodexCatalog.BOONS or category == CodexCatalog.SYNERGIES or category == CodexCatalog.SKILL_AUGMENTS or category == CodexCatalog.ACTIVE_SKILLS:
		return entry_id
	return _category_icon(category)


func _group_title_for(category: StringName) -> String:
	match category:
		CodexCatalog.REGIONS:
			return "MUNDO"
		CodexCatalog.ENEMIES:
			return "ENCUENTROS"
		CodexCatalog.BOONS:
			return "CONFIGURACIONES"
		CodexCatalog.EQUIPMENT:
			return "COLECCIÓN"
		CodexCatalog.COMPANIONS:
			return "ALIADOS"
		_:
			return ""


func _focus_first_button() -> void:
	for child: Node in content.get_children():
		if child is Button:
			(child as Button).grab_focus()
			return


func _clear_content() -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()


func _update_global_progress() -> void:
	var discovered: int = DiscoveryTracker.get_total_discovered_count()
	var total: int = CodexCatalog.get_total_count()
	var percentage: int = 0 if total <= 0 else roundi(float(discovered) * 100.0 / float(total))
	progress_label.text = "PROGRESO DEL ARCHIVO\n%d / %d  ·  %d%%" % [discovered, total, percentage]


func _on_back_pressed() -> void:
	match _mode:
		ViewMode.DETAIL:
			_show_category(_category)
		ViewMode.CATEGORY:
			_show_main()
		_:
			back_button.disabled = true
			back_requested.emit()


func _on_discover_all_pressed() -> void:
	if DiscoveryTracker.discover_all_debug():
		_show_main()

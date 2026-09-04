extends Control

signal back_requested

enum SlotFilter { NONE, WEAPON, ARMOR, HEAD, CAPE, RELIC }

## Fórmula de Resonancia (Combat Power), primera pasada — ajustable en
## balance final. HP pesa menos por punto que ATQ/DEF porque su magnitud
## típica es mucho mayor; el bonus por hito de refinamiento se suma aparte,
## además de estar ya reflejado indirectamente en ATQ/DEF (ver
## RunState._apply_equipped_item) — es deliberado: celebra el progreso de
## refinamiento con un salto de Resonancia visible, no solo el punto de
## stat que ya aporta.
const RESONANCE_HP_WEIGHT: float = 0.5
const RESONANCE_STAT_WEIGHT: float = 3.0
const RESONANCE_MILESTONE_WEIGHT: int = 4

@onready var weapon_equipped_label: Label = %WeaponEquippedLabel
@onready var armor_equipped_label: Label = %ArmorEquippedLabel
@onready var weapon_slot_button: Button = %WeaponSlotButton
@onready var armor_slot_button: Button = %ArmorSlotButton
@onready var head_slot_button: Button = %HeadSlotButton
@onready var head_equipped_label: Label = %HeadEquippedLabel
@onready var cape_slot_button: Button = %CapeSlotButton
@onready var cape_equipped_label: Label = %CapeEquippedLabel
@onready var relic_slot_button: Button = %RelicSlotButton
@onready var relic_equipped_label: Label = %RelicEquippedLabel
@onready var advanced_stats_toggle: Button = %AdvancedStatsToggle
@onready var advanced_stats_panel: VBoxContainer = %AdvancedStatsPanel
@onready var advanced_stats_row: HFlowContainer = %AdvancedStatsRow
@onready var items_list: VBoxContainer = %ItemsList
@onready var empty_collection_label: Label = %EmptyCollectionLabel
@onready var equipment_preview: CombatCharacterView = %EquipmentPreview
@onready var debug_grant_button: Button = %DebugGrantButton
@onready var back_button: Button = %BackButton
@onready var filter_label: Label = %FilterLabel
@onready var show_all_button: Button = %ShowAllButton
@onready var equip_level_label: Label = %EquipLevelLabel
@onready var resonance_label: Label = %ResonanceLabel
@onready var equip_health_badge: AshenBadge = %EquipHealthBadge
@onready var equip_attack_badge: AshenBadge = %EquipAttackBadge
@onready var equip_defense_badge: AshenBadge = %EquipDefenseBadge
@onready var filters_container: VBoxContainer = %FiltersContainer

var _filter: SlotFilter = SlotFilter.NONE
var _rarity_filter: int = -1
var _element_filter: StringName = &""
var _only_new: bool = false
var _only_set: bool = false
var _only_refined: bool = false
var _only_equippable: bool = false
var _only_favorite: bool = false
var _advanced_stats_expanded: bool = false

const _SLOT_FILTER_TO_SLOT: Dictionary[int, EquipmentData.Slot] = {
	SlotFilter.WEAPON: EquipmentData.Slot.WEAPON,
	SlotFilter.ARMOR: EquipmentData.Slot.CHEST,
	SlotFilter.HEAD: EquipmentData.Slot.HEAD,
	SlotFilter.CAPE: EquipmentData.Slot.CAPE,
	SlotFilter.RELIC: EquipmentData.Slot.RELIC,
}

var _rarity_chip_row: HFlowContainer
var _element_chip_row: HFlowContainer
var _toggle_chip_row: HFlowContainer

var _confirm_overlay: Control
var _confirm_label: Label
var _pending_salvage_id: String = ""


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	weapon_slot_button.pressed.connect(_on_slot_pressed.bind(SlotFilter.WEAPON))
	armor_slot_button.pressed.connect(_on_slot_pressed.bind(SlotFilter.ARMOR))
	head_slot_button.pressed.connect(_on_slot_pressed.bind(SlotFilter.HEAD))
	cape_slot_button.pressed.connect(_on_slot_pressed.bind(SlotFilter.CAPE))
	relic_slot_button.pressed.connect(_on_slot_pressed.bind(SlotFilter.RELIC))
	advanced_stats_toggle.pressed.connect(_on_advanced_stats_toggle_pressed)
	show_all_button.pressed.connect(_on_show_all_pressed)
	SaveManager.profile_changed.connect(_refresh)
	equipment_preview.setup_visual(PlayerVisualCatalog.ASHEN_WANDERER, "ASH")
	equipment_preview.configure_fallback_presence(&"player", VisualTheme.EMBER, VisualTheme.EMBER_DARK)
	debug_grant_button.visible = DebugConfig.DEBUG_TOOLS_ENABLED
	if DebugConfig.DEBUG_TOOLS_ENABLED:
		debug_grant_button.pressed.connect(_on_debug_grant_pressed)
	_build_filters()
	_build_confirm_overlay()
	_refresh()
	back_button.grab_focus()
	if not SaveManager.profile.owned_equipment.is_empty():
		TutorialManager.request(TutorialCatalog.EQUIPMENT_SCREEN, TutorialManager.CONTEXT_EQUIPMENT, self)


func _refresh() -> void:
	_refresh_header_stats()
	weapon_equipped_label.text = _equipped_text("Arma", SaveManager.profile.equipped_weapon_id)
	armor_equipped_label.text = _equipped_text("Pechera", SaveManager.profile.equipped_armor_id)
	head_equipped_label.text = _equipped_text("Cabeza", _equipped_id_for_slot(EquipmentData.Slot.HEAD))
	cape_equipped_label.text = _equipped_text("Capa", _equipped_id_for_slot(EquipmentData.Slot.CAPE))
	relic_equipped_label.text = _equipped_text("Reliquia", _equipped_id_for_slot(EquipmentData.Slot.RELIC))
	_style_equipped_slot(weapon_slot_button, SaveManager.profile.equipped_weapon_id, VisualTheme.ATTACK)
	_style_equipped_slot(armor_slot_button, SaveManager.profile.equipped_armor_id, VisualTheme.DEFENSE)
	_style_equipped_slot(head_slot_button, _equipped_id_for_slot(EquipmentData.Slot.HEAD), VisualTheme.DEFENSE)
	_style_equipped_slot(cape_slot_button, _equipped_id_for_slot(EquipmentData.Slot.CAPE), VisualTheme.DEFENSE)
	_style_equipped_slot(relic_slot_button, _equipped_id_for_slot(EquipmentData.Slot.RELIC), VisualTheme.ENERGY)
	# La preview del personaje sigue mostrando solo WEAPON+CHEST (los 2 slots
	# con capa visual real) — HEAD/CAPE/RELIC son gameplay-only en esta fase,
	# ver EquipmentData.slot_is_visual y non-goal "no mesh swapping real".
	var equipped_weapon: EquipmentData = EquipmentCatalog.get_by_id(SaveManager.profile.equipped_weapon_id)
	var equipped_armor: EquipmentData = EquipmentCatalog.get_by_id(SaveManager.profile.equipped_armor_id)
	equipment_preview.setup_equipment_visuals(equipped_weapon, equipped_armor)
	_refresh_advanced_stats()
	_refresh_filter_label()
	_refresh_filter_chips()
	_clear_list(items_list)
	var owned_count: int = 0
	var owned_items: Array[EquipmentData] = []
	for item: EquipmentData in EquipmentCatalog.get_all():
		var quantity: int = int(SaveManager.profile.owned_equipment.get(String(item.id), 0))
		if quantity <= 0:
			continue
		owned_count += quantity
		if not _passes_filters(item):
			continue
		owned_items.append(item)
	owned_items.sort_custom(_equipment_precedes)
	for entry: EquipmentData in owned_items:
		items_list.add_child(_create_item_card(entry, int(SaveManager.profile.owned_equipment.get(String(entry.id), 0))))
	empty_collection_label.visible = owned_items.is_empty()
	empty_collection_label.text = (
		"Todavía no reuniste equipamiento." if owned_count == 0 else "Ningún ítem coincide con los filtros activos."
	)


func _passes_filters(item: EquipmentData) -> bool:
	if _filter != SlotFilter.NONE and item.slot != _SLOT_FILTER_TO_SLOT[_filter]:
		return false
	if _rarity_filter >= 0 and int(item.rarity) != _rarity_filter:
		return false
	if not _element_filter.is_empty() and item.element_type != _element_filter:
		return false
	if _only_new and not SaveManager.is_equipment_new(String(item.id)):
		return false
	if _only_set and item.set_id.is_empty():
		return false
	if _only_refined and int(SaveManager.profile.equipment_refinement.get(String(item.id), 0)) <= 0:
		return false
	if _only_equippable and not SaveManager.can_equip_item(item):
		return false
	if _only_favorite and not SaveManager.is_equipment_favorite(String(item.id)):
		return false
	return true


func _has_active_filters() -> bool:
	return (
		_filter != SlotFilter.NONE or _rarity_filter >= 0 or not _element_filter.is_empty()
		or _only_new or _only_set or _only_refined or _only_equippable or _only_favorite
	)


## Equipment 2.0 Fase 1 — Advanced Stats: panel secundario con las 5 stats
## avanzadas agregadas (crit/crit dmg/brasa/curación/skill dmg) de los 5
## slots equipados. Toggle para no saturar la pantalla principal (ver
## UI/UX). Reusa AshenBadge, mismo componente que el resto de la pantalla.
func _refresh_advanced_stats() -> void:
	_clear_list(advanced_stats_row)
	var preview := RunState.new()
	preview.apply_permanent_upgrades(SaveManager.profile)
	_add_advanced_stat_badge(&"augment", "CRIT", preview.equipment_crit_chance)
	_add_advanced_stat_badge(&"augment", "D.CRIT", preview.equipment_crit_damage_bonus)
	_add_advanced_stat_badge(&"ember", "BRASA", preview.equipment_ember_gain_bonus)
	_add_advanced_stat_badge(&"heal", "CURACIÓN", preview.equipment_healing_power_bonus)
	_add_advanced_stat_badge(&"skill", "SKILL", preview.equipment_skill_damage_bonus)
	for affinity_id: StringName in preview.equipment_resistance_bonuses:
		_add_advanced_stat_badge(affinity_id, "RES. %s" % AffinityResolver.get_type_label(affinity_id), float(preview.equipment_resistance_bonuses[affinity_id]))


func _add_advanced_stat_badge(icon_id: StringName, label_text: String, value: float) -> void:
	if value <= 0.0:
		return
	var badge := AshenBadge.new()
	badge.configure(icon_id, label_text, AshenBadge.Variant.UTILITY, AshenIcon.DisplaySize.SMALL, "+%d%%" % roundi(value * 100.0))
	advanced_stats_row.add_child(badge)


func _on_advanced_stats_toggle_pressed() -> void:
	_advanced_stats_expanded = not _advanced_stats_expanded
	advanced_stats_panel.visible = _advanced_stats_expanded
	advanced_stats_toggle.text = "STATS AVANZADAS ▴" if _advanced_stats_expanded else "STATS AVANZADAS ▾"


func _refresh_header_stats() -> void:
	var profile: ProfileData = SaveManager.profile
	var xp_requirement: int = profile.get_player_xp_requirement()
	equip_level_label.text = "NIV %d  ·  %s" % [
		profile.player_level,
		"MÁXIMO" if xp_requirement <= 0 else "EXP %d / %d" % [profile.player_xp, xp_requirement],
	]
	var preview: RunState = RunState.new()
	preview.apply_permanent_upgrades(profile)
	equip_health_badge.configure(&"health", "VIDA %d" % preview.max_health, AshenBadge.Variant.HEAL, AshenIcon.DisplaySize.SMALL)
	equip_attack_badge.configure(&"attack", "ATQ %d" % preview.attack, AshenBadge.Variant.ATTACK, AshenIcon.DisplaySize.SMALL)
	equip_defense_badge.configure(&"defense", "DEF %d" % preview.defense, AshenBadge.Variant.DEFENSE, AshenIcon.DisplaySize.SMALL)
	resonance_label.text = "RESONANCIA %d" % _compute_resonance(preview)


func _compute_resonance(preview: RunState) -> int:
	var milestones: int = 0
	for slot: EquipmentData.Slot in EquipmentData.get_phase1_slots():
		var equipped_id: String = _equipped_id_for_slot(slot)
		if equipped_id.is_empty():
			continue
		milestones += RefinementConfig.get_primary_bonus(int(SaveManager.profile.equipment_refinement.get(equipped_id, 0)))
	var base: float = (
		float(preview.max_health) * RESONANCE_HP_WEIGHT
		+ float(preview.attack) * RESONANCE_STAT_WEIGHT
		+ float(preview.defense) * RESONANCE_STAT_WEIGHT
	)
	return roundi(base) + milestones * RESONANCE_MILESTONE_WEIGHT


func _on_slot_pressed(pressed_filter: SlotFilter) -> void:
	_filter = SlotFilter.NONE if _filter == pressed_filter else pressed_filter
	_refresh()


func _on_show_all_pressed() -> void:
	_filter = SlotFilter.NONE
	_rarity_filter = -1
	_element_filter = &""
	_only_new = false
	_only_set = false
	_only_refined = false
	_only_equippable = false
	_only_favorite = false
	_refresh()


func _refresh_filter_label() -> void:
	match _filter:
		SlotFilter.WEAPON:
			filter_label.text = "MOSTRANDO · ARMAS"
		SlotFilter.ARMOR:
			filter_label.text = "MOSTRANDO · PECHERAS"
		SlotFilter.HEAD:
			filter_label.text = "MOSTRANDO · CABEZA"
		SlotFilter.CAPE:
			filter_label.text = "MOSTRANDO · CAPAS"
		SlotFilter.RELIC:
			filter_label.text = "MOSTRANDO · RELIQUIAS"
		_:
			filter_label.text = "MOSTRANDO · TODO"
	show_all_button.text = "LIMPIAR"
	show_all_button.visible = _has_active_filters()


func _equipped_text(slot_name: String, equipment_id: String) -> String:
	var item: EquipmentData = EquipmentCatalog.get_by_id(equipment_id)
	if item == null:
		return "%s\n◇ VACÍA" % slot_name.to_upper()
	return "%s\n%s\n%s · +%d" % [
		slot_name.to_upper(),
		item.display_name.to_upper(),
		EquipmentCatalog.get_rarity_name(item.rarity).to_upper(),
		int(SaveManager.profile.equipment_refinement.get(String(item.id), 0)),
	]


func _style_equipped_slot(button: Button, equipment_id: String, fallback_accent: Color) -> void:
	var item: EquipmentData = EquipmentCatalog.get_by_id(equipment_id)
	var accent: Color = VisualTheme.rarity_color(item.rarity) if item != null else fallback_accent
	var background := Color(0.045, 0.038, 0.047, 0.92)
	var style := VisualTheme.panel_style(background, Color(accent, 0.72), 1, 8)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	for state: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)


func _clear_list(list: Container) -> void:
	for child in list.get_children():
		child.queue_free()


func _build_filters() -> void:
	filters_container.add_child(_muted_label("RAREZA"))
	_rarity_chip_row = HFlowContainer.new()
	filters_container.add_child(_rarity_chip_row)
	filters_container.add_child(_muted_label("ELEMENTO"))
	_element_chip_row = HFlowContainer.new()
	filters_container.add_child(_element_chip_row)
	_toggle_chip_row = HFlowContainer.new()
	filters_container.add_child(_toggle_chip_row)


func _muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.667, 0.631, 0.698, 1))
	return label


func _refresh_filter_chips() -> void:
	_clear_list(_rarity_chip_row)
	_rarity_chip_row.add_child(_create_chip("TODAS", _rarity_filter < 0, _set_rarity_filter.bind(-1)))
	for rarity: int in [EquipmentData.Rarity.COMMON, EquipmentData.Rarity.RARE, EquipmentData.Rarity.EPIC]:
		_rarity_chip_row.add_child(_create_chip(EquipmentCatalog.get_rarity_name(rarity).to_upper(), _rarity_filter == rarity, _set_rarity_filter.bind(rarity)))

	_clear_list(_element_chip_row)
	_element_chip_row.add_child(_create_chip("TODOS", _element_filter.is_empty(), _set_element_filter.bind(&"")))
	for element: StringName in _distinct_owned_elements():
		_element_chip_row.add_child(_create_chip(AffinityResolver.get_type_label(element), _element_filter == element, _set_element_filter.bind(element)))

	_clear_list(_toggle_chip_row)
	var new_count: int = _count_new_items()
	_toggle_chip_row.add_child(_create_chip("NUEVO" if new_count == 0 else "NUEVO ·%d" % new_count, _only_new, _toggle_new))
	_toggle_chip_row.add_child(_create_chip("SET", _only_set, _toggle_set))
	_toggle_chip_row.add_child(_create_chip("REFINADO", _only_refined, _toggle_refined))
	_toggle_chip_row.add_child(_create_chip("EQUIPABLE", _only_equippable, _toggle_equippable))
	_toggle_chip_row.add_child(_create_chip("FAVORITO", _only_favorite, _toggle_favorite))


func _create_chip(text: String, is_active: bool, callback: Callable) -> Button:
	var chip := Button.new()
	chip.text = text
	chip.custom_minimum_size = Vector2(0, 36)
	chip.theme_type_variation = &"SelectedButton" if is_active else &"SecondaryButton"
	chip.add_theme_font_size_override("font_size", 13)
	chip.focus_mode = Control.FOCUS_NONE
	chip.pressed.connect(callback)
	return chip


func _distinct_owned_elements() -> Array[StringName]:
	var elements: Array[StringName] = []
	for item: EquipmentData in EquipmentCatalog.get_all():
		if int(SaveManager.profile.owned_equipment.get(String(item.id), 0)) <= 0:
			continue
		if item.element_type not in elements:
			elements.append(item.element_type)
	return elements


func _count_new_items() -> int:
	var count: int = 0
	for equipment_id: Variant in SaveManager.profile.owned_equipment.keys():
		if SaveManager.is_equipment_new(String(equipment_id)):
			count += 1
	return count


func _set_rarity_filter(value: int) -> void:
	_rarity_filter = -1 if _rarity_filter == value else value
	_refresh()


func _set_element_filter(value: StringName) -> void:
	_element_filter = &"" if _element_filter == value else value
	_refresh()


func _toggle_new() -> void:
	_only_new = not _only_new
	_refresh()


func _toggle_set() -> void:
	_only_set = not _only_set
	_refresh()


func _toggle_refined() -> void:
	_only_refined = not _only_refined
	_refresh()


func _toggle_equippable() -> void:
	_only_equippable = not _only_equippable
	_refresh()


func _toggle_favorite() -> void:
	_only_favorite = not _only_favorite
	_refresh()


func _create_item_card(item: EquipmentData, quantity: int) -> PanelContainer:
	var card := ItemCardView.new()
	var equipped_item: EquipmentData = _get_equipped_for_slot(item.slot)
	var equipped_id: String = _equipped_id_for_slot(item.slot)
	card.configure(
		item,
		SaveManager.profile.player_level,
		quantity,
		equipped_id == String(item.id),
		equipped_item,
		ItemCardView.Mode.INVENTORY,
	)
	card.equip_requested.connect(_on_equip_pressed)
	card.salvage_requested.connect(_on_salvage_pressed)
	card.preview_requested.connect(_on_preview_requested)
	card.lock_toggle_requested.connect(_on_lock_toggle_pressed)
	card.favorite_toggle_requested.connect(_on_favorite_toggle_pressed)
	return card


func _on_favorite_toggle_pressed(equipment_id: String) -> void:
	SaveManager.toggle_equipment_favorite(equipment_id)


func _on_lock_toggle_pressed(equipment_id: String) -> void:
	SaveManager.toggle_equipment_lock(equipment_id)


func _on_preview_requested(item: EquipmentData) -> void:
	# Solo WEAPON/CHEST tienen capa visual real en esta fase (ver
	# EquipmentData.slot_is_visual) — previsualizar un HEAD/CAPE/RELIC no
	# cambia el personaje, se deja el preview como está.
	if item == null or not EquipmentData.slot_is_visual(item.slot):
		return
	var weapon: EquipmentData = EquipmentCatalog.get_by_id(SaveManager.profile.equipped_weapon_id)
	var armor: EquipmentData = EquipmentCatalog.get_by_id(SaveManager.profile.equipped_armor_id)
	if item.slot == EquipmentData.Slot.WEAPON:
		weapon = item
	elif item.slot == EquipmentData.Slot.CHEST:
		armor = item
	equipment_preview.setup_equipment_visuals(weapon, armor)


func _get_equipped_for_slot(slot: EquipmentData.Slot) -> EquipmentData:
	return EquipmentCatalog.get_by_id(_equipped_id_for_slot(slot))


func _equipped_id_for_slot(slot: EquipmentData.Slot) -> String:
	return EquipmentCatalog.get_equipped_id_for_slot(SaveManager.profile, slot)


func _equipment_precedes(left: EquipmentData, right: EquipmentData) -> bool:
	if left.slot != right.slot:
		return int(left.slot) < int(right.slot)
	var left_equipped: bool = String(left.id) == _equipped_id_for_slot(left.slot)
	var right_equipped: bool = String(right.id) == _equipped_id_for_slot(right.slot)
	if left_equipped != right_equipped:
		return left_equipped
	if left.rarity != right.rarity:
		return left.rarity > right.rarity
	if left.tier != right.tier:
		return left.tier > right.tier
	return left.display_name.naturalnocasecmp_to(right.display_name) < 0


func _on_equip_pressed(equipment_id: String) -> void:
	var item: EquipmentData = EquipmentCatalog.get_by_id(equipment_id)
	if item == null or not SaveManager.equip_item(equipment_id):
		return
	var rarity_pitches: Array[float] = [0.92, 1.05, 1.18]
	var rarity_pitch: float = rarity_pitches[item.rarity]
	AudioManager.play_event(AudioManager.AudioEvent.EQUIP, rarity_pitch)
	if SettingsManager.reduce_motion:
		return
	var slot_button: Button = _slot_button_for(item.slot)
	slot_button.pivot_offset = slot_button.size * 0.5
	slot_button.modulate = VisualTheme.rarity_color(item.rarity)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(slot_button, "modulate", Color.WHITE, 0.35)
	tween.tween_property(slot_button, "scale", Vector2(1.03, 1.03), 0.12)
	tween.chain().tween_property(slot_button, "scale", Vector2.ONE, 0.12)


func _slot_button_for(slot: EquipmentData.Slot) -> Button:
	match slot:
		EquipmentData.Slot.WEAPON:
			return weapon_slot_button
		EquipmentData.Slot.CHEST:
			return armor_slot_button
		EquipmentData.Slot.HEAD:
			return head_slot_button
		EquipmentData.Slot.CAPE:
			return cape_slot_button
		_:
			return relic_slot_button


func _on_debug_grant_pressed() -> void:
	SaveManager.grant_all_debug_equipment()


func _on_salvage_pressed(equipment_id: String) -> void:
	var refinement_level: int = int(SaveManager.profile.equipment_refinement.get(equipment_id, 0))
	if refinement_level > 0:
		_show_salvage_confirmation(equipment_id, refinement_level)
	else:
		_perform_salvage(equipment_id)


func _perform_salvage(equipment_id: String) -> void:
	var ash_awarded: int = SaveManager.salvage_equipment_duplicates(equipment_id)
	if ash_awarded > 0:
		AudioManager.play_event(AudioManager.AudioEvent.LOOT_REVEAL, 0.95)


func _build_confirm_overlay() -> void:
	_confirm_overlay = Control.new()
	_confirm_overlay.name = "SalvageConfirmOverlay"
	_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_overlay.visible = false
	add_child(_confirm_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -260.0
	panel.offset_right = 260.0
	panel.offset_top = -150.0
	panel.offset_bottom = 150.0
	panel.add_theme_stylebox_override("panel", VisualTheme.elevated_panel_style(VisualTheme.CARD, VisualTheme.DANGER, 2, 14))
	_confirm_overlay.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var title := Label.new()
	title.text = "¿RECICLAR ÍTEM REFINADO?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", VisualTheme.DANGER)
	column.add_child(title)
	_confirm_label = Label.new()
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_confirm_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var cancel_button := Button.new()
	cancel_button.text = "CANCELAR"
	cancel_button.custom_minimum_size = Vector2(0, 52)
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.theme_type_variation = &"SecondaryButton"
	cancel_button.pressed.connect(_hide_salvage_confirmation)
	buttons.add_child(cancel_button)
	var confirm_button := Button.new()
	confirm_button.text = "RECICLAR IGUAL"
	confirm_button.custom_minimum_size = Vector2(0, 52)
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.theme_type_variation = &"PrimaryButton"
	confirm_button.pressed.connect(_on_salvage_confirmed)
	buttons.add_child(confirm_button)


func _show_salvage_confirmation(equipment_id: String, refinement_level: int) -> void:
	var item: EquipmentData = EquipmentCatalog.get_by_id(equipment_id)
	if item == null:
		return
	_pending_salvage_id = equipment_id
	_confirm_label.text = (
		"%s está refinado a +%d. El duplicado que se recicla no afecta la pieza que conservás — el refinamiento no se pierde. ¿Confirmás igual?"
		% [item.display_name.to_upper(), refinement_level]
	)
	_confirm_overlay.visible = true


func _hide_salvage_confirmation() -> void:
	_pending_salvage_id = ""
	_confirm_overlay.visible = false


func _on_salvage_confirmed() -> void:
	var equipment_id: String = _pending_salvage_id
	_hide_salvage_confirmation()
	if not equipment_id.is_empty():
		_perform_salvage(equipment_id)


func _on_back_pressed() -> void:
	back_button.disabled = true
	SaveManager.mark_all_equipment_seen()
	back_requested.emit()

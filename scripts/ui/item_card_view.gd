class_name ItemCardView
extends PanelContainer

## Ver comentario equivalente en run_state.gd: preload en vez de class_name
## directo por timing del global class cache en scripts recién creados.
const _EquipmentSetResolver = preload("res://scripts/equipment/equipment_set_resolver.gd")

signal equip_requested(equipment_id: String)
signal salvage_requested(equipment_id: String)
signal preview_requested(item: EquipmentData)
signal lock_toggle_requested(equipment_id: String)
signal favorite_toggle_requested(equipment_id: String)

enum Mode { INVENTORY, REWARD }

var item: EquipmentData
var mode: Mode = Mode.INVENTORY
var _is_equipped: bool = false
var _is_available: bool = true


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_emit_preview)
	focus_entered.connect(_emit_preview)


func configure(
	new_item: EquipmentData,
	player_level: int,
	quantity: int = 1,
	is_equipped: bool = false,
	equipped_item: EquipmentData = null,
	new_mode: Mode = Mode.INVENTORY,
	reward_state: String = "",
	duplicate_ash: int = 0,
) -> void:
	item = new_item
	mode = new_mode
	_is_equipped = is_equipped
	_is_available = item != null and player_level >= item.required_level
	_build(maxi(1, quantity), equipped_item, reward_state, duplicate_ash)


func _build(quantity: int, equipped_item: EquipmentData, reward_state: String, duplicate_ash: int) -> void:
	for child: Node in get_children():
		child.queue_free()
	if item == null:
		_build_empty()
		return
	custom_minimum_size = Vector2(0.0, 214.0 if mode == Mode.INVENTORY else 188.0)
	var rarity_color: Color = VisualTheme.rarity_color(item.rarity)
	add_theme_stylebox_override("panel", VisualTheme.rarity_card_style(item.rarity, _is_equipped))
	tooltip_text = _detail_tooltip()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 9)
	margin.add_child(root)

	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 14)
	root.add_child(identity)
	identity.add_child(_create_icon_well(rarity_color, mode == Mode.INVENTORY and SaveManager.is_equipment_new(String(item.id))))
	var header := VBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 4)
	identity.add_child(header)

	var name_row := HBoxContainer.new()
	header.add_child(name_row)
	var name_label := Label.new()
	name_label.text = item.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", VisualTheme.FONT_ITEM_NAME)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_row.add_child(name_label)
	if quantity > 1:
		name_row.add_child(_label("x%d" % quantity, VisualTheme.TEXT_SECONDARY, VisualTheme.FONT_LABEL))

	var identity_row := HBoxContainer.new()
	identity_row.add_theme_constant_override("separation", 6)
	header.add_child(identity_row)
	identity_row.add_child(_badge(_rarity_icon(), EquipmentCatalog.get_rarity_name(item.rarity).to_upper(), AshenBadge.Variant.RARITY, "", rarity_color))
	identity_row.add_child(_badge(item.icon_id, EquipmentCatalog.get_slot_label(item.slot), AshenBadge.Variant.NEUTRAL))
	var refinement_level: int = int(SaveManager.profile.equipment_refinement.get(String(item.id), 0))
	if refinement_level > 0:
		identity_row.add_child(_badge(&"augment", "+%d" % refinement_level, AshenBadge.Variant.EMBER, "T%d" % RefinementConfig.get_visual_tier(refinement_level), RefinementConfig.get_visual_tier_color(refinement_level)))
	if _is_equipped:
		identity_row.add_child(_badge(&"equipped", "EQUIPADO", AshenBadge.Variant.RARITY, "", VisualTheme.EQUIPPED))
	elif not _is_available:
		identity_row.add_child(_badge(&"locked", "NIV %d" % item.required_level, AshenBadge.Variant.DANGER))
	else:
		identity_row.add_child(_badge(&"level", "NIV %d" % item.required_level, AshenBadge.Variant.UTILITY))
	if mode == Mode.INVENTORY:
		name_row.add_child(_create_favorite_button())
		name_row.add_child(_create_lock_button())

	var element_row := HBoxContainer.new()
	element_row.add_theme_constant_override("separation", 6)
	root.add_child(element_row)
	element_row.add_child(_badge(item.element_type, EquipmentCatalog.get_element_type_label(item), AshenBadge.Variant.UTILITY))
	var matchup := _label(_matchup_summary(item), VisualTheme.MUTED, VisualTheme.FONT_LABEL)
	element_row.add_child(matchup)
	if not item.set_id.is_empty():
		var set_size: int = EquipmentCatalog.get_set_size(item.set_id)
		var equipped_pieces: int = EquipmentCatalog.get_equipped_set_piece_count(SaveManager.profile, item.set_id)
		root.add_child(_label("SET · %s · %d/%d EQUIPADAS" % [_set_display_name(item.set_id), equipped_pieces, set_size], VisualTheme.TEXT_SECONDARY, VisualTheme.FONT_LABEL))

	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 6)
	root.add_child(stats_row)
	_add_stat(stats_row, &"attack", "ATQ", item.attack_bonus, AshenBadge.Variant.ATTACK)
	_add_stat(stats_row, &"defense", "DEF", item.defense_bonus, AshenBadge.Variant.DEFENSE)
	_add_stat(stats_row, &"health", "VIDA", item.max_health_bonus, AshenBadge.Variant.HEAL)
	var secondary: String = EquipmentCatalog.get_secondary_stats_text(item)
	if not secondary.is_empty():
		stats_row.add_child(_badge(&"augment", secondary.to_upper(), AshenBadge.Variant.UTILITY))

	var passive: String = EquipmentCatalog.get_passive_text(item)
	if not passive.is_empty():
		var passive_label := _label(passive, VisualTheme.EMBER_BRIGHT, VisualTheme.FONT_LABEL)
		passive_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		passive_label.tooltip_text = passive
		root.add_child(passive_label)

	if mode == Mode.REWARD:
		_add_reward_state(root, reward_state, duplicate_ash)
	else:
		_add_comparison(root, equipped_item)
		_add_actions(root, quantity)


func _create_icon_well(rarity_color: Color, is_new: bool = false) -> Control:
	var well := PanelContainer.new()
	well.custom_minimum_size = Vector2(104.0, 104.0)
	var style := VisualTheme.elevated_panel_style(VisualTheme.BACKGROUND_DEEP, rarity_color, 2, 14)
	style.content_margin_left = 16.0
	style.content_margin_top = 16.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 16.0
	well.add_theme_stylebox_override("panel", style)
	var icon := AshenIcon.new()
	icon.configure(item.icon_id, rarity_color, AshenIcon.DisplaySize.XLARGE)
	well.add_child(icon)
	if not is_new:
		return well
	var wrapper := Control.new()
	wrapper.custom_minimum_size = well.custom_minimum_size
	wrapper.add_child(well)
	var new_badge := Label.new()
	new_badge.text = "NUEVO"
	new_badge.add_theme_font_size_override("font_size", 11)
	new_badge.add_theme_color_override("font_color", VisualTheme.BACKGROUND_DEEP)
	new_badge.add_theme_stylebox_override("normal", VisualTheme.panel_style(VisualTheme.EMBER_BRIGHT, VisualTheme.EMBER_BRIGHT, 0, 6))
	new_badge.position = Vector2(-6.0, -8.0)
	wrapper.add_child(new_badge)
	return wrapper


func _create_lock_button() -> Button:
	var equipment_id: String = String(item.id)
	var is_locked: bool = SaveManager.is_equipment_locked(equipment_id)
	var is_manual: bool = equipment_id in SaveManager.profile.locked_equipment_ids
	var button := Button.new()
	button.custom_minimum_size = Vector2(32.0, 32.0)
	button.theme_type_variation = &"SecondaryButton"
	button.focus_mode = Control.FOCUS_NONE
	var icon := AshenIcon.new()
	icon.configure(&"locked", VisualTheme.EMBER_BRIGHT if is_locked else VisualTheme.MUTED, AshenIcon.DisplaySize.SMALL, true)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	button.add_child(icon)
	if is_locked and not is_manual:
		button.disabled = true
		button.tooltip_text = "Bloqueado automáticamente: pieza de set equipada."
	else:
		button.tooltip_text = "Bloqueado contra reciclado accidental. Tocá para desbloquear." if is_locked else "Bloquear contra reciclado accidental."
		button.pressed.connect(func() -> void: lock_toggle_requested.emit(equipment_id))
	return button


## Equipment 2.0 Fase 1 — mismo patrón que _create_lock_button pero para
## favoritos (no bloquea salvage, solo prioriza/filtra en Inventory).
func _create_favorite_button() -> Button:
	var equipment_id: String = String(item.id)
	var is_favorite: bool = SaveManager.is_equipment_favorite(equipment_id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(32.0, 32.0)
	button.theme_type_variation = &"SecondaryButton"
	button.focus_mode = Control.FOCUS_NONE
	var icon := AshenIcon.new()
	icon.configure(&"boon", VisualTheme.EMBER_BRIGHT if is_favorite else VisualTheme.MUTED, AshenIcon.DisplaySize.SMALL, true)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	button.add_child(icon)
	button.tooltip_text = "Quitar de favoritos." if is_favorite else "Marcar como favorito."
	button.pressed.connect(func() -> void: favorite_toggle_requested.emit(equipment_id))
	return button


func _add_stat(parent: HBoxContainer, icon_id: StringName, label_text: String, value: int, variant: AshenBadge.Variant) -> void:
	if value <= 0:
		return
	parent.add_child(_badge(icon_id, label_text, variant, "+%d" % value))


func _add_comparison(parent: VBoxContainer, equipped_item: EquipmentData) -> void:
	if equipped_item == null or equipped_item.id == item.id:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	_add_delta(row, &"attack", "ATQ", item.attack_bonus - equipped_item.attack_bonus, AshenBadge.Variant.ATTACK)
	_add_delta(row, &"defense", "DEF", item.defense_bonus - equipped_item.defense_bonus, AshenBadge.Variant.DEFENSE)
	_add_delta(row, &"health", "VIDA", item.max_health_bonus - equipped_item.max_health_bonus, AshenBadge.Variant.HEAL)
	_add_delta_percent(row, &"augment", "CRIT", item.crit_chance - equipped_item.crit_chance)
	_add_delta_percent(row, &"augment", "D.CRIT", item.crit_damage_bonus - equipped_item.crit_damage_bonus)
	_add_delta_percent(row, &"augment", "BRASA", item.ember_gain_bonus - equipped_item.ember_gain_bonus)
	_add_delta_percent(row, &"augment", "CURA", item.healing_power_bonus - equipped_item.healing_power_bonus)
	_add_delta_percent(row, &"augment", "SKILL", item.skill_damage_bonus - equipped_item.skill_damage_bonus)
	if row.get_child_count() == 0:
		row.queue_free()
	for note: String in _comparison_notes(equipped_item):
		var note_label := _label(note, VisualTheme.TEXT_SECONDARY, VisualTheme.FONT_LABEL)
		note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(note_label)


## Cambios que un número solo no comunica: efecto especial ganado/perdido,
## elemento distinto, entrada/salida de un set (sin bonus mecánico todavía
## — ver docs de la Fase 1 de equipamiento).
func _comparison_notes(equipped_item: EquipmentData) -> Array[String]:
	var notes: Array[String] = []
	if item.passive_effect_id != equipped_item.passive_effect_id:
		if item.passive_effect_id.is_empty():
			notes.append("PIERDE PASIVO · %s" % EquipmentEffectResolver.get_passive_name(equipped_item.passive_effect_id))
		elif equipped_item.passive_effect_id.is_empty():
			notes.append("GANA PASIVO · %s" % EquipmentEffectResolver.get_passive_name(item.passive_effect_id))
		else:
			notes.append("CAMBIA PASIVO · %s → %s" % [EquipmentEffectResolver.get_passive_name(equipped_item.passive_effect_id), EquipmentEffectResolver.get_passive_name(item.passive_effect_id)])
	if item.element_type != equipped_item.element_type:
		notes.append("ELEMENTO · %s → %s" % [EquipmentCatalog.get_element_type_label(equipped_item), EquipmentCatalog.get_element_type_label(item)])
	if item.set_id != equipped_item.set_id:
		if not item.set_id.is_empty():
			var has_bonus: bool = _EquipmentSetResolver.SET_BONUS_PASSIVES.has(item.set_id)
			notes.append("ENTRA AL SET %s%s" % [_set_display_name(item.set_id), "" if has_bonus else " · sin bonus mecánico todavía"])
		elif not equipped_item.set_id.is_empty():
			notes.append("SALE DEL SET %s" % _set_display_name(equipped_item.set_id))
	return notes


func _set_display_name(set_id: StringName) -> String:
	return String(set_id).replace("_", " ").to_upper()


func _add_delta(parent: HBoxContainer, icon_id: StringName, label_text: String, value: int, positive_variant: AshenBadge.Variant) -> void:
	if value == 0:
		return
	var arrow: String = "↑" if value > 0 else "↓"
	parent.add_child(_badge(icon_id, "%s %s" % [arrow, label_text], positive_variant if value > 0 else AshenBadge.Variant.DEBUFF, "%+d" % value))


## Equipment 2.0 Fase 1 — delta de stats avanzadas (%), mismo patrón que
## _add_delta pero para los floats de EquipmentData.SecondaryStat.
func _add_delta_percent(parent: HBoxContainer, icon_id: StringName, label_text: String, value: float) -> void:
	if absf(value) < 0.001:
		return
	var arrow: String = "↑" if value > 0.0 else "↓"
	parent.add_child(_badge(icon_id, "%s %s" % [arrow, label_text], AshenBadge.Variant.UTILITY if value > 0.0 else AshenBadge.Variant.DEBUFF, "%+d%%" % roundi(value * 100.0)))


func _add_actions(parent: VBoxContainer, quantity: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var equip_button := Button.new()
	equip_button.custom_minimum_size = Vector2(0.0, 52.0)
	equip_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_button.theme_type_variation = &"SelectedButton" if _is_equipped else &"PrimaryButton"
	equip_button.text = "EQUIPADO" if _is_equipped else ("EQUIPAR" if _is_available else "LOCK  NIV %d" % item.required_level)
	equip_button.disabled = _is_equipped or not _is_available
	equip_button.tooltip_text = "Requiere nivel %d." % item.required_level
	equip_button.focus_entered.connect(_emit_preview)
	if not equip_button.disabled:
		equip_button.pressed.connect(func() -> void: equip_requested.emit(String(item.id)))
	row.add_child(equip_button)
	if quantity > 1:
		var salvage_button := Button.new()
		salvage_button.custom_minimum_size = Vector2(164.0, 52.0)
		salvage_button.theme_type_variation = &"SecondaryButton"
		var ash_value: int = (quantity - 1) * EquipmentCatalog.get_duplicate_salvage_ash(item)
		if SaveManager.is_equipment_locked(String(item.id)):
			salvage_button.text = "BLOQUEADO"
			salvage_button.disabled = true
			salvage_button.tooltip_text = "Desbloqueá este ítem para poder reciclarlo."
		else:
			salvage_button.text = "RECICLAR  +%d" % ash_value
			salvage_button.tooltip_text = "Recicla %d duplicado(s) por %d de Ceniza." % [quantity - 1, ash_value]
			salvage_button.pressed.connect(func() -> void: salvage_requested.emit(String(item.id)))
		row.add_child(salvage_button)


func _add_reward_state(parent: VBoxContainer, reward_state: String, duplicate_ash: int) -> void:
	if reward_state.is_empty():
		return
	var icon_id: StringName = &"loot"
	var variant := AshenBadge.Variant.EMBER
	var text := reward_state.to_upper()
	var counter := ""
	if reward_state == "duplicate":
		icon_id = &"ash"
		text = "RECICLADO"
		counter = "+%d" % duplicate_ash
	elif reward_state == "new":
		text = "NUEVO"
	parent.add_child(_badge(icon_id, text, variant, counter))


func _detail_tooltip() -> String:
	var lines: Array[String] = [item.display_name, item.description, EquipmentCatalog.get_stats_text(item)]
	var passive: String = EquipmentCatalog.get_passive_text(item)
	if not passive.is_empty():
		lines.append(passive)
	lines.append("Requiere nivel %d" % item.required_level)
	lines.append("Refinamiento +%d" % int(SaveManager.profile.equipment_refinement.get(String(item.id), 0)))
	return "\n".join(lines)


func _badge(icon_id: StringName, text: String, variant: AshenBadge.Variant, counter: String = "", accent: Color = Color.TRANSPARENT) -> AshenBadge:
	var result := AshenBadge.new()
	result.configure(icon_id, text, variant, AshenIcon.DisplaySize.SMALL, counter, true, accent)
	return result


func _label(text: String, color: Color, font_size: int) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_color_override("font_color", color)
	result.add_theme_font_size_override("font_size", font_size)
	return result


func _rarity_icon() -> StringName:
	match item.rarity:
		EquipmentData.Rarity.RARE:
			return &"rare"
		EquipmentData.Rarity.EPIC:
			return &"epic"
		_:
			return &"common"


func _build_empty() -> void:
	custom_minimum_size = Vector2(0.0, 120.0)
	add_theme_stylebox_override("panel", VisualTheme.elevated_panel_style(VisualTheme.CARD, VisualTheme.BORDER, 2, 12))
	var label := _label("SIN LOOT", VisualTheme.TEXT_SECONDARY, VisualTheme.FONT_SECTION)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)


## El elemento del arma sí afecta el daño en combate (ver combat.gd
## _attacker_damage_type / _resolve_elemental_damage) — para el resto de los
## slots el elemento sigue siendo cosmético/de set. Equipment 2.0 Fase 1
## agrega resistance_affinity_id, que sí interactúa con combate del lado
## defensivo (ver combat.gd:_player_equipment_resistance_tags) — se refleja
## acá aparte del matchup ofensivo. Resume el matchup real contra el roster
## de enemigos conocido, no un disclaimer estático.
func _matchup_summary(target_item: EquipmentData) -> String:
	if target_item.slot != EquipmentData.Slot.WEAPON:
		if not target_item.resistance_affinity_id.is_empty():
			return "RESISTE %s" % AffinityResolver.get_type_label(target_item.resistance_affinity_id)
		return "SOLO EL ARMA DEFINE EL TIPO DE DAÑO"
	var weak_count: int = 0
	var resist_count: int = 0
	var immune_count: int = 0
	for enemy: EnemyData in _known_enemies():
		if target_item.element_type in enemy.immunity_tags:
			immune_count += 1
		elif target_item.element_type in enemy.weakness_tags:
			weak_count += 1
		elif target_item.element_type in enemy.resistance_tags:
			resist_count += 1
	var parts: Array[String] = []
	if weak_count > 0:
		parts.append("FUERTE VS %d" % weak_count)
	if resist_count > 0:
		parts.append("RESISTIDO POR %d" % resist_count)
	if immune_count > 0:
		parts.append("INMUNE ×%d" % immune_count)
	return " · ".join(parts) if not parts.is_empty() else "SIN VENTAJA CONOCIDA"


func _known_enemies() -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	for biome: BiomeData in BiomeCatalog.get_all():
		for enemy: EnemyData in EnemySpawnResolver.get_pool(biome):
			if enemy != null and enemy not in result:
				result.append(enemy)
		for enemy: EnemyData in biome.elite_enemy_pool:
			if enemy != null and enemy not in result:
				result.append(enemy)
		if biome.boss != null and biome.boss not in result:
			result.append(biome.boss)
	return result


func _emit_preview() -> void:
	if item != null and mode == Mode.INVENTORY:
		preview_requested.emit(item)

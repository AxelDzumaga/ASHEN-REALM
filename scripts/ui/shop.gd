extends Control

signal back_requested

var _currency_label: Label
var _content: VBoxContainer
var _feedback: Label


func _ready() -> void:
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = VisualTheme.BACKGROUND_DEEP
	add_child(background)
	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -360
	frame.offset_top = -640
	frame.offset_right = 360
	frame.offset_bottom = 640
	frame.add_theme_constant_override("margin_left", 32)
	frame.add_theme_constant_override("margin_top", 28)
	frame.add_theme_constant_override("margin_right", 32)
	frame.add_theme_constant_override("margin_bottom", 28)
	add_child(frame)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	frame.add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var back := Button.new()
	back.text = "VOLVER"
	back.custom_minimum_size = Vector2(120, 58)
	back.theme_type_variation = &"SecondaryButton"
	back.pressed.connect(back_requested.emit)
	top.add_child(back)
	var title := Label.new()
	title.text = "TIENDA DEL REFUGIO"
	title.add_theme_font_size_override("font_size", VisualTheme.FONT_SECTION)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_currency_label = Label.new()
	_currency_label.custom_minimum_size = Vector2(170, 58)
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_currency_label)
	var subtitle := Label.new()
	subtitle.text = "COFRES  ·  EQUIPO  ·  FORJA\nRotación por expediciones, sin reloj ni conexión."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = VisualTheme.TEXT_SECONDARY
	root.add_child(subtitle)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)
	_feedback = Label.new()
	_feedback.custom_minimum_size = Vector2(0, 70)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.modulate = VisualTheme.XP_BRIGHT
	root.add_child(_feedback)


func _refresh() -> void:
	_currency_label.text = "CENIZA %d\nSIGILOS %d  ·  FRAG %d" % [SaveManager.profile.total_ash, SaveManager.profile.guardian_sigils, SaveManager.profile.forge_shards]
	for child: Node in _content.get_children():
		child.free()
	for section: StringName in [&"chests", &"equipment", &"materials"]:
		_add_section(section)
	_add_owned_chests()


func _add_section(section: StringName) -> void:
	var title := Label.new()
	title.text = {&"chests": "COFRES", &"equipment": "EQUIPO EN ROTACIÓN", &"materials": "MATERIALES"}.get(section, String(section)).to_upper()
	title.add_theme_font_size_override("font_size", VisualTheme.FONT_ITEM_NAME)
	title.modulate = VisualTheme.EMBER_BRIGHT
	_content.add_child(title)
	for offer: ShopOfferData in ShopCatalog.get_available(SaveManager.profile):
		if offer.section != section:
			continue
		_add_offer(offer)


## L0 (2026-09-08): antes toda oferta usaba el mismo ícono color TREASURE y el
## texto de rareza era plano, sin relación visual con el resto de la UI donde
## la rareza ya tiene un color/ícono/borde canónico (VisualTheme.rarity_color,
## rarity_card_style — ver item_card_view.gd/run_result.gd). Reusa esa misma
## fuente de verdad acá en vez de inventar una paleta nueva para la tienda.
func _add_offer(offer: ShopOfferData) -> void:
	var equipment_item: EquipmentData = (
		EquipmentCatalog.get_by_id(String(offer.reward_id))
		if offer.reward_type == ShopOfferData.RewardType.EQUIPMENT
		else null
	)
	var accent_color: Color = VisualTheme.rarity_color(equipment_item.rarity) if equipment_item != null else VisualTheme.TREASURE
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 92)
	panel.add_theme_stylebox_override(
		"panel",
		VisualTheme.rarity_card_style(equipment_item.rarity, false) if equipment_item != null
		else VisualTheme.elevated_panel_style(VisualTheme.CARD, VisualTheme.BORDER, 2, 10),
	)
	_content.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var icon := AshenIcon.new()
	icon.configure(offer.icon_id, accent_color, AshenIcon.DisplaySize.LARGE)
	row.add_child(icon)
	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.text = "%s\n%s  ·  NIV %d" % [offer.display_name.to_upper(), _reward_hint(offer), offer.required_level]
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if equipment_item != null:
		info.modulate = accent_color.lightened(0.35)
	row.add_child(info)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(154, 64)
	buy.text = "%d %s\nCOMPRAR" % [offer.price, EconomyConfig.currency_name(offer.currency)]
	var key: String = ShopCatalog.purchase_key(offer, SaveManager.profile)
	var sold_out: bool = offer.stock_per_rotation > 0 and int(SaveManager.profile.shop_purchase_counts.get(key, 0)) >= offer.stock_per_rotation
	var affordable: bool = SaveManager.profile.total_ash >= offer.price if offer.currency == EconomyConfig.Currency.ASH else SaveManager.profile.guardian_sigils >= offer.price
	var owned: bool = offer.reward_type == ShopOfferData.RewardType.EQUIPMENT and int(SaveManager.profile.owned_equipment.get(String(offer.reward_id), 0)) > 0
	buy.disabled = sold_out or not affordable or owned
	if sold_out:
		buy.text = "AGOTADO"
	elif owned:
		buy.text = "YA POSEÍDO"
	buy.pressed.connect(_on_buy.bind(offer.offer_id))
	row.add_child(buy)


func _reward_hint(offer: ShopOfferData) -> String:
	if offer.reward_type == ShopOfferData.RewardType.CHEST:
		var chest := ChestCatalog.get_by_id(offer.reward_id)
		return "BOTÍN %d–%d" % [chest.min_rewards, chest.max_rewards]
	if offer.reward_type == ShopOfferData.RewardType.FORGE_SHARD:
		return "+%d FRAGMENTO" % offer.quantity
	var item := EquipmentCatalog.get_by_id(String(offer.reward_id))
	return "%s  ·  %s" % [EquipmentCatalog.get_rarity_name(item.rarity).to_upper(), EquipmentCatalog.get_slot_label(item.slot)]


func _add_owned_chests() -> void:
	var title := Label.new()
	title.text = "COFRES SIN ABRIR"
	title.add_theme_font_size_override("font_size", VisualTheme.FONT_ITEM_NAME)
	title.modulate = VisualTheme.XP_BRIGHT
	_content.add_child(title)
	var any := false
	for chest: ChestData in ChestCatalog.get_all():
		var amount: int = int(SaveManager.profile.unopened_chests.get(String(chest.id), 0))
		if amount <= 0:
			continue
		any = true
		var open := Button.new()
		open.custom_minimum_size = Vector2(0, 64)
		open.text = "%s  ×%d     ABRIR" % [chest.display_name.to_upper(), amount]
		open.theme_type_variation = &"PrimaryButton"
		open.pressed.connect(_on_open.bind(chest.id))
		_content.add_child(open)
	if not any:
		var empty := Label.new()
		empty.text = "Sin cofres pendientes. Los bosses siempre otorgan uno."
		empty.modulate = VisualTheme.TEXT_SECONDARY
		_content.add_child(empty)


func _on_buy(offer_id: StringName) -> void:
	_feedback.text = "COMPRA COMPLETADA" if SaveManager.purchase_shop_offer(offer_id) else "COMPRA RECHAZADA · revisá precio, stock o requisito"
	_refresh()


func _on_open(chest_id: StringName) -> void:
	var reward: Dictionary = SaveManager.open_chest(chest_id)
	if reward.is_empty():
		_feedback.text = "NO SE PUDO ABRIR EL COFRE"
		return
	var item_names: Array[String] = []
	for item_id: String in reward.get("items", []):
		var item := EquipmentCatalog.get_by_id(item_id)
		item_names.append("%s [%s]" % [item.display_name, EquipmentCatalog.get_rarity_name(item.rarity).to_upper()])
	_feedback.text = "REVELADO · %s\n+CENIZA %d  ·  +FRAG %d%s" % [" · ".join(item_names), int(reward.get("ash", 0)), int(reward.get("forge_shards", 0)), "  ·  PITY ACTIVADO" if bool(reward.get("pity_triggered", false)) else ""]
	_refresh()

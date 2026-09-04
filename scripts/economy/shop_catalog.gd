class_name ShopCatalog
extends RefCounted

static var _all: Array[ShopOfferData] = []


static func get_all() -> Array[ShopOfferData]:
	if _all.is_empty():
		_all = [
			_make(&"ash_cache", "Arcón de Ceniza", &"chests", ShopOfferData.RewardType.CHEST, ChestCatalog.ASH_CACHE, EconomyConfig.Currency.ASH, 55),
			_make(&"rare_chest", "Relicario Raro", &"chests", ShopOfferData.RewardType.CHEST, ChestCatalog.RARE_RELIQUARY, EconomyConfig.Currency.ASH, 220, 3, &"", &"", 1),
			_make(&"epic_chest", "Cámara Épica", &"chests", ShopOfferData.RewardType.CHEST, ChestCatalog.EPIC_VAULT, EconomyConfig.Currency.ASH, 620, 7, &"", &"", 1),
			_make(&"warden_chest", "Relicario del Guardián", &"chests", ShopOfferData.RewardType.CHEST, ChestCatalog.WARDEN_RELIQUARY, EconomyConfig.Currency.GUARDIAN_SIGIL, 8, 1, &"ashen_warden", &"", 1),
			_make(&"sunken_chest", "Relicario de la Pira", &"chests", ShopOfferData.RewardType.CHEST, ChestCatalog.SUNKEN_RELIQUARY, EconomyConfig.Currency.GUARDIAN_SIGIL, 10, 1, &"sunken_pyre", &"", 1),
			_make(&"warden_edge_direct", "Filo del Guardián", &"equipment", ShopOfferData.RewardType.EQUIPMENT, &"wardens_edge", EconomyConfig.Currency.GUARDIAN_SIGIL, 18, 9, &"ashen_warden"),
			_make(&"warden_plate_direct", "Placa del Guardián", &"equipment", ShopOfferData.RewardType.EQUIPMENT, &"warden_plate", EconomyConfig.Currency.GUARDIAN_SIGIL, 20, 10, &"ashen_warden"),
			_make(&"forge_shard", "Fragmento de Forja", &"materials", ShopOfferData.RewardType.FORGE_SHARD, &"forge_shard", EconomyConfig.Currency.ASH, 70, 1, &"", &"", 0, 1),
			_make(&"rotating_weapon", "Arma del viaje", &"equipment", ShopOfferData.RewardType.EQUIPMENT, &"", EconomyConfig.Currency.ASH, 0, 1, &"", &"weapons", 1),
			_make(&"rotating_armor", "Armadura del viaje", &"equipment", ShopOfferData.RewardType.EQUIPMENT, &"", EconomyConfig.Currency.ASH, 0, 1, &"", &"armor", 1),
			## Equipment 2.0 Fase 1 — rotación de los 4 slots nuevos. HEAD/CAPE
			## Común/Raro abiertos por rotación (mismo patrón que weapon/armor);
			## RELIC entra con nivel algo más alto ya que no compite por gear
			## slot con nada más. Épico de estos 4 slots vive en los chests
			## (rare/epic/warden), no en la rotación directa — consistente con
			## cómo ya funcionaba weapon/armor. INITIAL TUNING.
			_make(&"rotating_head", "Tocado del viaje", &"equipment", ShopOfferData.RewardType.EQUIPMENT, &"", EconomyConfig.Currency.ASH, 0, 1, &"", &"head", 1),
			_make(&"rotating_cape", "Capa del viaje", &"equipment", ShopOfferData.RewardType.EQUIPMENT, &"", EconomyConfig.Currency.ASH, 0, 1, &"", &"cape", 1),
			_make(&"rotating_relic", "Reliquia del viaje", &"equipment", ShopOfferData.RewardType.EQUIPMENT, &"", EconomyConfig.Currency.ASH, 0, 3, &"", &"relic", 1),
		]
	return _all


static func get_by_id(offer_id: StringName, profile: ProfileData) -> ShopOfferData:
	for offer: ShopOfferData in get_available(profile):
		if offer.offer_id == offer_id:
			return offer
	return null


static func get_available(profile: ProfileData) -> Array[ShopOfferData]:
	var result: Array[ShopOfferData] = []
	for source: ShopOfferData in get_all():
		var offer: ShopOfferData = source.duplicate(true)
		if not offer.rotation_group.is_empty():
			var item := _rotating_item(offer.rotation_group, profile.total_runs)
			if item == null:
				continue
			offer.reward_id = item.id
			offer.display_name = item.display_name
			offer.required_level = item.required_level
			offer.price = get_item_price(item)
			offer.icon_id = item.icon_id
		if _requirements_met(offer, profile):
			result.append(offer)
	return result


static func get_rotation_index(profile: ProfileData) -> int:
	return profile.total_runs / EconomyConfig.SHOP_ROTATION_RUNS


static func purchase_key(offer: ShopOfferData, profile: ProfileData) -> String:
	return "%s:%d" % [offer.offer_id, get_rotation_index(profile)] if offer.stock_per_rotation > 0 else String(offer.offer_id)


static func get_item_price(item: EquipmentData) -> int:
	var bases: Array[int] = [95, 320, 840]
	return bases[item.rarity] + maxi(0, item.tier - 1) * [20, 55, 110][item.rarity]


static func _requirements_met(offer: ShopOfferData, profile: ProfileData) -> bool:
	if profile.player_level < offer.required_level:
		return false
	if not offer.required_boss_id.is_empty() and int(profile.boss_defeat_counts.get(String(offer.required_boss_id), 0)) <= 0:
		return false
	return true


static func _rotating_item(group: StringName, total_runs: int) -> EquipmentData:
	var pool: Array[EquipmentData] = _pool_for_group(group)
	if pool.is_empty():
		return null
	var rotation: int = total_runs / EconomyConfig.SHOP_ROTATION_RUNS
	return pool[posmod(rotation * 5 + _rotation_offset(group), pool.size())]


## Equipment 2.0 Fase 1 — un caso por slot; agregar Fase 2 acá cuando
## corresponda, sin tocar _rotating_item.
static func _pool_for_group(group: StringName) -> Array[EquipmentData]:
	match group:
		&"weapons":
			return EquipmentCatalog.get_weapons()
		&"armor":
			return EquipmentCatalog.get_chests()
		&"head":
			return EquipmentCatalog.get_heads()
		&"cape":
			return EquipmentCatalog.get_capes()
		&"relic":
			return EquipmentCatalog.get_relics()
		_:
			return []


static func _rotation_offset(group: StringName) -> int:
	match group:
		&"weapons":
			return 0
		&"head":
			return 1
		&"cape":
			return 2
		&"armor":
			return 3
		&"relic":
			return 4
		_:
			return 0


static func _make(id: StringName, name: String, section: StringName, reward_type: ShopOfferData.RewardType, reward_id: StringName, currency: EconomyConfig.Currency, price: int, required_level: int = 1, required_boss: StringName = &"", rotation: StringName = &"", stock: int = 0, quantity: int = 1) -> ShopOfferData:
	var offer := ShopOfferData.new()
	offer.offer_id = id
	offer.display_name = name
	offer.section = section
	offer.reward_type = reward_type
	offer.reward_id = reward_id
	offer.currency = currency
	offer.price = price
	offer.required_level = required_level
	offer.required_boss_id = required_boss
	offer.rotation_group = rotation
	offer.stock_per_rotation = stock
	offer.quantity = quantity
	offer.icon_id = &"shop"
	return offer

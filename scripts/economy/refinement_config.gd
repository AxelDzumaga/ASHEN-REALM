class_name RefinementConfig
extends RefCounted

## Tope y costos +1..+10 sin cambios respecto a la economía Stage78 ya
## balanceada. +11..+20 es la extensión de la propuesta de balance v2
## (2026-09-02) — placeholder de primera pasada, ajustable después de una
## implementación de prueba. Ver docs/refinement_extension_and_event_drops_spec.md.
const MAX_REFINEMENT: int = 20
const MILESTONES: Array[int] = [3, 5, 8, 10, 13, 15, 18, 20]

## Costo de Material de Bioma por nivel objetivo, interpolado linealmente
## entre los puntos que dio la propuesta (10→0, 13→3, 15→5, 18→8, 20→12),
## redondeando hacia arriba entre puntos.
const _MATERIAL_CONTROL_POINTS: Array[Vector2i] = [
	Vector2i(10, 0), Vector2i(13, 3), Vector2i(15, 5), Vector2i(18, 8), Vector2i(20, 12),
]
## Sigilos del boss de origen: 0 hasta +17; interpola entre 10 (+18) y 18 (+20).
## Usa el pool global de guardian_sigils (no hay sigilos por-boss en el
## esquema actual — "de origen" es descripción de diseño, no una moneda
## separada; confirmado con el usuario antes de implementar).
const _SIGIL_CONTROL_POINTS: Array[Vector2i] = [Vector2i(18, 10), Vector2i(20, 18)]


static func get_cost(item: EquipmentData, current_level: int) -> Dictionary:
	if item == null or current_level < 0 or current_level >= MAX_REFINEMENT:
		return {}
	var target: int = current_level + 1
	var rarity_multiplier: int = [1, 2, 4][item.rarity]
	var ash: int = (18 + target * target * 4 + item.tier * 6) * rarity_multiplier
	var shards: int = 0 if target <= 3 else ceili(float(target - 2) / 2.0) * rarity_multiplier
	var sigils: int = 0 if target <= 7 else (target - 7) * maxi(1, rarity_multiplier / 2)
	var biome_material: int = 0
	if target > 10:
		sigils = 0 if target <= 17 else _interpolate(_SIGIL_CONTROL_POINTS, target)
		biome_material = _interpolate(_MATERIAL_CONTROL_POINTS, target)
	return {
		"ash": ash, "forge_shards": shards, "guardian_sigils": sigils,
		"biome_material": biome_material, "target_level": target,
	}


static func get_primary_bonus(level: int) -> int:
	var bonus := 0
	for milestone: int in MILESTONES:
		if level >= milestone:
			bonus += 1
	return bonus


## 0-2 preservan exactamente los umbrales +1..+10 ya existentes (<5, 5-9,
## >=10); 3-6 son los hitos nuevos, cada uno con su propio color en la
## propuesta (rojo/ámbar +13, carmesí +15, dorado +18, blanco-plateado +20).
## Ver get_visual_tier_color() — cableado en item_card_view.gd.
static func get_visual_tier(level: int) -> int:
	if level >= 20:
		return 6
	if level >= 18:
		return 5
	if level >= 15:
		return 4
	if level >= 13:
		return 3
	if level >= 10:
		return 2
	if level >= 5:
		return 1
	return 0


## A qué moneda de bioma corresponde el costo de +11..+20 de este ítem.
## La mayoría de las piezas tienen un solo tag de bioma (ver data/equipment/).
## Las piezas "universales" sin tag (gear inicial no atado a una región)
## devuelven "" — significa "cualquier Material de Bioma disponible", no un
## bioma fijo. Ver has_enough_biome_material / spend_biome_material.
static func get_biome_material_key(item: EquipmentData) -> String:
	if item != null and not item.biome_tags.is_empty():
		return String(item.biome_tags[0])
	return ""


static func has_enough_biome_material(profile: ProfileData, item: EquipmentData, amount: int) -> bool:
	if amount <= 0:
		return true
	var key: String = get_biome_material_key(item)
	if not key.is_empty():
		return int(profile.biome_materials.get(key, 0)) >= amount
	var total: int = 0
	for stock: Variant in profile.biome_materials.values():
		total += int(stock)
	return total >= amount


## Para ítems atados a un bioma, descuenta de esa moneda específica. Para
## piezas universales (key == ""), descuenta del stock combinado — el orden
## de deducción entre monedas es un detalle interno (no se muestra desglosado
## en la UI), así que usa el orden estable de BiomeCatalog y después
## cualquier otra clave presente en el perfil, para no dejar remanente si la
## suma total ya alcanzaba (verificado antes por has_enough_biome_material).
static func spend_biome_material(profile: ProfileData, item: EquipmentData, amount: int) -> void:
	if amount <= 0:
		return
	var key: String = get_biome_material_key(item)
	if not key.is_empty():
		profile.biome_materials[key] = int(profile.biome_materials.get(key, 0)) - amount
		return
	var ordered_keys: Array[String] = []
	for biome: BiomeData in BiomeCatalog.get_all():
		ordered_keys.append(String(biome.id))
	for other_key: Variant in profile.biome_materials.keys():
		if String(other_key) not in ordered_keys:
			ordered_keys.append(String(other_key))
	var remaining: int = amount
	for biome_key: String in ordered_keys:
		if remaining <= 0:
			break
		var available: int = int(profile.biome_materials.get(biome_key, 0))
		if available <= 0:
			continue
		var take: int = mini(available, remaining)
		profile.biome_materials[biome_key] = available - take
		remaining -= take


## Color por hito, según la propuesta de balance v2. Transparente por debajo
## de +3 (sin hito alcanzado todavía) — AshenBadge cae a su color de variant
## por defecto en ese caso (ver ashen_badge.gd, accent_override.a <= 0.0).
static func get_visual_tier_color(level: int) -> Color:
	if level >= 20:
		return Color("ece6f7") # blanco-plateado / prismático
	if level >= 18:
		return Color("d5a441") # dorado
	if level >= 15:
		return Color("9c1f30") # carmesí
	if level >= 13:
		return Color("d9683f") # rojo/ámbar
	if level >= 10:
		return Color("a66be0") # violeta
	if level >= 8:
		return Color("589de0") # azul
	if level >= 5:
		return Color("2f9e52") # verde intenso
	if level >= 3:
		return Color("8fd6a8") # verde pálido
	return Color.TRANSPARENT


static func _interpolate(points: Array[Vector2i], target: int) -> int:
	for index: int in points.size() - 1:
		var a: Vector2i = points[index]
		var b: Vector2i = points[index + 1]
		if target <= b.x:
			if target <= a.x:
				return a.y
			var fraction: float = float(target - a.x) / float(b.x - a.x)
			return ceili(float(a.y) + float(b.y - a.y) * fraction)
	return points[points.size() - 1].y


class_name EquipmentData
extends Resource

## Equipment 2.0 Fase 1: WEAPON se mantiene en el índice 0. ARMOR (índice 1)
## se renombra a CHEST conservando el mismo valor ordinal — todo .tres
## existente con slot=1 sigue leyendo CHEST sin tocar el archivo. HEAD/CAPE/
## RELIC son nuevos. Fase 2 (SHOULDERS, HANDS, LEGS, FEET, RING_1, RING_2,
## NO implementados todavía) se agregan al FINAL de este enum cuando
## corresponda — nunca insertados en el medio, para no correr los ordinales
## de los slots ya guardados en saves reales.
enum Slot { WEAPON, CHEST, HEAD, CAPE, RELIC }
enum Rarity { COMMON, RARE, EPIC }
enum SecondaryStat { CRIT_CHANCE, CRIT_DAMAGE, EMBER_GAIN, HEALING_POWER, SKILL_DAMAGE }
enum Affinity { NONE, ASH, EMBER, MIRE, WARDEN }
enum PassiveTrigger { NONE, COMBAT_START, BASIC_ATTACK_HIT, DAMAGE_RECEIVED, LOW_HP }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var slot: Slot = Slot.WEAPON
@export var rarity: Rarity = Rarity.COMMON
@export_range(1, 10, 1) var tier: int = 1
@export_range(1, 50, 1) var required_level: int = 1
@export var icon_id: StringName = &"loot"
@export_range(-999, 999) var attack_bonus: int = 0
@export_range(-999, 999) var defense_bonus: int = 0
@export_range(0, 999) var max_health_bonus: int = 0
@export_range(0.0, 0.5, 0.01) var crit_chance: float = 0.0
@export_range(0.0, 1.0, 0.01) var crit_damage_bonus: float = 0.0
@export_range(0.0, 1.0, 0.01) var ember_gain_bonus: float = 0.0
@export_range(0.0, 1.0, 0.01) var healing_power_bonus: float = 0.0
@export_range(0.0, 1.0, 0.01) var skill_damage_bonus: float = 0.0
@export var passive_effect_id: StringName = &""
@export var passive_trigger: PassiveTrigger = PassiveTrigger.NONE
@export var affinity: Affinity = Affinity.NONE
@export var biome_tags: Array[StringName] = []
@export var tags: Array[StringName] = []
## Elemento de Fase 1 (ver scripts/combat/affinity_resolver.gd). Para armas,
## define el tipo de daño real en combate (combat.gd:_attacker_damage_type /
## _resolve_elemental_damage) — wireado, no solo informativo. Para armadura
## sigue siendo cosmético/de set: no hay mecánica de resistencia elemental
## del lado del jugador todavía. Deliberadamente NO se llama "affinity": ese
## nombre ya lo usa el campo `affinity` de abajo, para sinergias de build, un
## concepto distinto sin relación con elementos de combate.
@export var element_type: StringName = &"physical"
@export var visual_id: StringName = &""
@export var shop_icon_id: StringName = &""
@export var set_id: StringName = &""
@export var boss_source_id: StringName = &""
@export var boss_set_visual_id: StringName = &""
## Equipment 2.0 Fase 1 — resistencia elemental genérica/data-driven (mismo
## catálogo de ids que element_type, ver AffinityResolver), NO hardcodea una
## lista fija de afinidades. Antes de esta feature ningún ítem defensivo
## interactuaba con la resistencia elemental del jugador (ver
## scripts/combat/combat.gd:_resolve_elemental_damage). INITIAL TUNING, sin
## balance final.
@export var resistance_affinity_id: StringName = &""
@export_range(0.0, 0.5, 0.01) var resistance_bonus: float = 0.0


## Slots aprobados para Fase 1. Fase 2 se agrega acá cuando el enum Slot lo
## soporte — este método es el único lugar que necesita tocarse.
static func get_phase1_slots() -> Array[Slot]:
	return [Slot.WEAPON, Slot.CHEST, Slot.HEAD, Slot.CAPE, Slot.RELIC]


## true si este slot típicamente no tiene representación visual en el
## personaje (ver EquipmentVisualData) — RELIC es "no visual" por diseño.
static func slot_is_visual(check_slot: Slot) -> bool:
	return check_slot != Slot.RELIC


static func get_slot_name(check_slot: Slot) -> String:
	return ["WEAPON", "CHEST", "HEAD", "CAPE", "RELIC"][check_slot]


## -1 si el nombre no corresponde a ningún slot conocido (dato malformado de
## un save legacy/corrupto) — el llamador debe tratarlo como "descartar".
static func slot_from_name(name: String) -> int:
	var names: Array[String] = ["WEAPON", "CHEST", "HEAD", "CAPE", "RELIC"]
	return names.find(name.to_upper())

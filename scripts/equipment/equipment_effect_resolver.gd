class_name EquipmentEffectResolver
extends RefCounted

const BASE_CRIT_MULTIPLIER: float = 1.50
const LOW_HEALTH_THRESHOLD_PERCENT: int = 35
const BLOODBOUND_DAMAGE_BONUS: float = 0.20
const WARDEN_PLATE_REDUCTION: float = 0.25

const BURNING_EDGE: StringName = &"burning_edge"
const BLOODBOUND: StringName = &"bloodbound"
const MIRE_REGENERATION: StringName = &"mire_regeneration"
const WARDEN_FIRST_GUARD: StringName = &"warden_first_guard"
const SUNDERING_EDGE: StringName = &"sundering_edge"
const GUARDED_REGROWTH: StringName = &"guarded_regrowth"
## Equipment 2.0 Fase 1 — bonus de 2 piezas de EquipmentSetResolver.ASHEN_WARDEN_SET.
## Mecánico (Regeneración extra en combat start), no solo +stat plano, per
## GAMEPLAY RULES. INITIAL TUNING, sin balance final.
const WARDEN_SET_RESONANCE: StringName = &"warden_set_resonance"


static func apply_combat_start(
	run: RunState,
	player: CombatActor,
	statuses: CombatStatusController,
	runtime: EquipmentRuntimeState,
) -> void:
	if run == null or player == null or statuses == null or runtime == null or runtime.combat_start_applied:
		return
	runtime.combat_start_applied = true
	if run.has_equipment_passive(MIRE_REGENERATION):
		statuses.apply_status(player, &"regen", player, 1, 2)
	if run.has_equipment_passive(WARDEN_SET_RESONANCE):
		statuses.apply_status(player, &"regen", player, 1, 3)


static func roll_critical(run: RunState, rng: RandomNumberGenerator) -> bool:
	var chance: float = clampf(run.equipment_crit_chance, 0.0, 0.75) if run != null else 0.0
	return rng != null and chance > 0.0 and rng.randf() < chance


static func apply_critical_damage(damage: int, run: RunState) -> int:
	if damage <= 0 or run == null:
		return maxi(0, damage)
	return maxi(1, roundi(float(damage) * (BASE_CRIT_MULTIPLIER + run.equipment_crit_damage_bonus)))


static func apply_basic_attack_damage(damage: int, run: RunState) -> int:
	if damage <= 0 or run == null:
		return maxi(0, damage)
	if run.has_equipment_passive(BLOODBOUND) and run.current_health * 100 <= run.max_health * LOW_HEALTH_THRESHOLD_PERCENT:
		return maxi(1, roundi(float(damage) * (1.0 + BLOODBOUND_DAMAGE_BONUS)))
	return damage


static func apply_skill_damage(damage: int, run: RunState) -> int:
	if damage <= 0 or run == null:
		return maxi(0, damage)
	return maxi(1, roundi(float(damage) * (1.0 + run.equipment_skill_damage_bonus)))


static func apply_basic_hit_status(
	run: RunState,
	source: CombatActor,
	target: CombatActor,
	statuses: CombatStatusController,
) -> bool:
	if run == null or source == null or target == null or statuses == null:
		return false
	if not run.has_equipment_passive(BURNING_EDGE) or not target.is_alive():
		return false
	return statuses.apply_status(target, &"burn", source, 1) != null


static func apply_basic_hit_statuses(
	run: RunState,
	source: CombatActor,
	target: CombatActor,
	statuses: CombatStatusController,
	runtime: EquipmentRuntimeState,
) -> Array[StringName]:
	var applied: Array[StringName] = []
	if run == null or source == null or target == null or statuses == null or runtime == null or not target.is_alive():
		return applied
	if run.has_equipment_passive(BURNING_EDGE) and statuses.apply_status(target, &"burn", source, 1) != null:
		applied.append(&"burn")
	if (
		runtime.sundering_edge_available
		and run.has_equipment_passive(SUNDERING_EDGE)
		and statuses.apply_status(target, &"armor_break", source, 1, 2) != null
	):
		runtime.sundering_edge_available = false
		applied.append(&"armor_break")
	return applied


static func apply_guard_consumed_status(
	run: RunState,
	player: CombatActor,
	statuses: CombatStatusController,
	runtime: EquipmentRuntimeState,
	guard_consumed: bool,
) -> bool:
	if (
		not guard_consumed
		or run == null
		or player == null
		or not player.is_alive()
		or statuses == null
		or runtime == null
		or not runtime.guarded_regrowth_available
		or not run.has_equipment_passive(GUARDED_REGROWTH)
	):
		return false
	runtime.guarded_regrowth_available = false
	return statuses.apply_status(player, &"regen", player, 1, 2) != null


static func before_player_takes_damage(damage: int, run: RunState, runtime: EquipmentRuntimeState) -> int:
	if damage <= 0 or run == null or runtime == null:
		return maxi(0, damage)
	if not runtime.first_hit_available or not run.has_equipment_passive(WARDEN_FIRST_GUARD):
		return damage
	runtime.first_hit_available = false
	return maxi(1, ceili(float(damage) * (1.0 - WARDEN_PLATE_REDUCTION)))


static func get_passive_name(passive_id: StringName) -> String:
	match passive_id:
		BURNING_EDGE:
			return "FILO ARDIENTE"
		BLOODBOUND:
			return "PACTO DE SANGRE"
		MIRE_REGENERATION:
			return "RENACER DEL PANTANO"
		WARDEN_FIRST_GUARD:
			return "PLACA DEL GUARDIÁN"
		SUNDERING_EDGE:
			return "PUNTA QUEBRADORA"
		GUARDED_REGROWTH:
			return "REBROTE PROTEGIDO"
		WARDEN_SET_RESONANCE:
			return "RESONANCIA DEL GUARDIÁN"
		_:
			return ""


static func get_passive_description(passive_id: StringName) -> String:
	match passive_id:
		BURNING_EDGE:
			return "Los ataques básicos aplican Quemadura ×1."
		BLOODBOUND:
			return "+20% daño de ataque básico con 35% de Vida o menos."
		MIRE_REGENERATION:
			return "Comenzás cada combate con Regeneración durante 2 turnos."
		WARDEN_FIRST_GUARD:
			return "El primer golpe de cada combate inflige 25% menos daño."
		SUNDERING_EDGE:
			return "El primer ataque básico de cada combate aplica Ruptura de armadura ×1 durante 2 turnos."
		GUARDED_REGROWTH:
			return "La primera Guardia consumida de cada combate aplica Regeneración durante 2 turnos."
		WARDEN_SET_RESONANCE:
			return "Set Warden (2 piezas): comenzás cada combate con Regeneración durante 3 turnos."
		_:
			return ""

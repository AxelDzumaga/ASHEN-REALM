class_name EnemyIntent
extends RefCounted

enum Category {
	ATTACK,
	DEFEND,
	STATUS,
	SUPPORT,
	SUMMON,
	SPECIAL,
}

enum Intensity {
	NONE,
	LOW,
	MEDIUM,
	HIGH,
	VERY_HIGH,
	LETHAL,
}

var plan_id: StringName
var action_id: StringName
var action_type: EnemyAIEnums.ActionType = EnemyAIEnums.ActionType.ATTACK
var action: EnemyActionData
var source_actor: CombatActor
var target_actor: CombatActor
var target_policy: EnemyAIEnums.TargetPolicy = EnemyAIEnums.TargetPolicy.PRIMARY_PLAYER
var category: Category = Category.ATTACK
var intensity: Intensity = Intensity.NONE
var estimated_power: float = 0.0
var estimated_damage: int = -1
var estimate_is_exact: bool = false
var status_effect: StringName
var status_stacks: int = 0
var defense_amount: int = 0
var summon_type: StringName
var summon_count: int = 0
var priority: int = 0
var source_role: EnemyAIEnums.Role = EnemyAIEnums.Role.ASSAULT
var planned_turn: int = 0
var is_valid: bool = true
var invalid_reason: StringName
var debug_reason: String = "planned"


func invalidate(reason: StringName) -> void:
	is_valid = false
	invalid_reason = reason
	debug_reason = "invalidated:%s" % reason


func can_execute() -> bool:
	return is_valid and action != null and source_actor != null and source_actor.is_alive()


func resolve_execution_target(alive_targets: Array[CombatActor]) -> CombatActor:
	if not can_execute():
		return null
	if action_type == EnemyAIEnums.ActionType.SELF_BUFF or action_type == EnemyAIEnums.ActionType.SUMMON:
		return source_actor
	if target_actor != null and target_actor.is_targetable() and target_actor in alive_targets:
		return target_actor
	# La invalidación de target no vuelve a consumir RNG. RANDOM_ALIVE cae al
	# jugador primario de manera determinista; las demás políticas se recalculan.
	match target_policy:
		EnemyAIEnums.TargetPolicy.LOWEST_HP:
			target_actor = _lowest_health_ratio(alive_targets)
		EnemyAIEnums.TargetPolicy.COMPANION_PREFERRED:
			target_actor = _companion_or_primary(alive_targets)
		_:
			target_actor = _primary_player(alive_targets)
	if target_actor != null:
		debug_reason = "retargeted:%s" % target_actor.actor_id
	return target_actor


func update_damage_estimate(value: int, target: CombatActor, exact: bool = false) -> void:
	estimated_damage = maxi(0, value)
	estimate_is_exact = exact
	intensity = _classify_intensity(estimated_damage, target)
	priority = int(intensity)


func get_category_name() -> String:
	match category:
		Category.DEFEND:
			return "DEFENSA"
		Category.STATUS:
			return "ESTADO"
		Category.SUPPORT:
			return "APOYO"
		Category.SUMMON:
			return "INVOCAR"
		Category.SPECIAL:
			return "ESPECIAL"
		_:
			return "ATAQUE"


func category_name_for_telemetry() -> StringName:
	return StringName(get_category_name().to_lower())


func get_intensity_name() -> String:
	match intensity:
		Intensity.LOW:
			return "BAJA"
		Intensity.MEDIUM:
			return "MEDIA"
		Intensity.HIGH:
			return "ALTA"
		Intensity.VERY_HIGH:
			return "MUY ALTA"
		Intensity.LETHAL:
			return "LETAL"
		_:
			return ""


func get_target_name() -> String:
	if action_type == EnemyAIEnums.ActionType.SELF_BUFF:
		return "SÍ MISMO"
	if action_type == EnemyAIEnums.ActionType.SUMMON:
		return "CAMPO"
	if target_actor != null and target_actor.is_targetable():
		return target_actor.display_name.to_upper()
	match target_policy:
		EnemyAIEnums.TargetPolicy.LOWEST_HP:
			return "MENOR VIDA"
		EnemyAIEnums.TargetPolicy.RANDOM_ALIVE:
			return "OBJETIVO FIJADO"
		EnemyAIEnums.TargetPolicy.COMPANION_PREFERRED:
			return "COMPAÑERO / JUGADOR"
		_:
			return "JUGADOR"


func get_icon_id() -> StringName:
	match category:
		Category.DEFEND:
			return &"defense"
		Category.STATUS:
			return status_effect if not status_effect.is_empty() else &"status"
		Category.SUPPORT:
			return &"heal"
		Category.SUMMON:
			return &"ember"
		Category.SPECIAL:
			return &"counter"
		_:
			return &"attack"


func get_status_display_name() -> String:
	var data: StatusEffectData = StatusEffectCatalog.get_by_id(status_effect)
	return data.display_name.to_upper() if data != null else String(status_effect).replace("_", " ").to_upper()


func get_compact_text() -> String:
	var short_category: String = get_category_name()
	match category:
		Category.ATTACK:
			short_category = "ATQ"
		Category.DEFEND:
			short_category = "DEF"
		Category.STATUS:
			short_category = "ESTADO"
		Category.SUMMON:
			short_category = "SUMMON"
		Category.SPECIAL:
			short_category = "ESP."
	return "%s→%s" % [short_category, get_compact_target_name()]


func get_compact_target_name() -> String:
	if action_type == EnemyAIEnums.ActionType.SELF_BUFF:
		return "SÍ MISMO"
	if action_type == EnemyAIEnums.ActionType.SUMMON:
		return "CAMPO"
	if target_actor != null:
		if target_actor.actor_type == CombatActor.ActorType.PLAYER:
			return "JUGADOR"
		if target_actor.actor_type == CombatActor.ActorType.COMPANION:
			return "HOUND"
	return "OBJETIVO"


func get_compact_counter() -> String:
	if category == Category.DEFEND:
		return "+%d DEF" % defense_amount
	if category == Category.SUMMON:
		return "×%d" % maxi(1, summon_count)
	if category == Category.STATUS and not status_effect.is_empty():
		return "×%d" % maxi(1, status_stacks)
	if estimated_damage >= 0:
		return "%s%d" % ["" if estimate_is_exact else "~", estimated_damage]
	return get_intensity_name()


func get_detail_text(role_name: String = "ENEMIGO") -> String:
	var first_line: String = "%s · %s · %s" % [
		source_actor.display_name.to_upper() if source_actor != null else "ENEMIGO",
		role_name,
		action.display_name.to_upper() if action != null else get_category_name(),
	]
	var details: Array[String] = ["OBJETIVO %s" % get_target_name()]
	if estimated_damage >= 0:
		details.append("DAÑO %s%d" % ["" if estimate_is_exact else "APROX. ", estimated_damage])
	if not get_intensity_name().is_empty():
		details.append("POTENCIA %s" % get_intensity_name())
	if category == Category.STATUS and not status_effect.is_empty():
		details.append("%s ×%d" % [get_status_display_name(), maxi(1, status_stacks)])
	if category == Category.DEFEND:
		details.append("DEF +%d" % defense_amount)
	if category == Category.SUMMON and not summon_type.is_empty():
		details.append("%s ×%d" % [String(summon_type).to_upper(), maxi(1, summon_count)])
	return "%s\n%s" % [first_line, " · ".join(details)]


func get_debug_text() -> String:
	return "Enemy=%s Intent=%s Target=%s Expected=%s Plan=%s Valid=%s Reason=%s" % [
		source_actor.display_name if source_actor != null else "none",
		get_category_name(),
		get_target_name(),
		str(estimated_damage) if estimated_damage >= 0 else "unknown",
		plan_id,
		is_valid,
		debug_reason,
	]


func _classify_intensity(damage: int, target: CombatActor) -> Intensity:
	if damage <= 0 or target == null or target.get_max_hp() <= 0:
		return Intensity.NONE
	if damage >= target.get_current_hp():
		return Intensity.LETHAL
	var ratio: float = float(damage) / float(target.get_max_hp())
	if ratio <= 0.1:
		return Intensity.LOW
	if ratio <= 0.25:
		return Intensity.MEDIUM
	if ratio <= 0.45:
		return Intensity.HIGH
	return Intensity.VERY_HIGH


func _primary_player(alive_targets: Array[CombatActor]) -> CombatActor:
	for candidate: CombatActor in alive_targets:
		if candidate.actor_type == CombatActor.ActorType.PLAYER:
			return candidate
	return alive_targets[0] if not alive_targets.is_empty() else null


func _companion_or_primary(alive_targets: Array[CombatActor]) -> CombatActor:
	for candidate: CombatActor in alive_targets:
		if candidate.actor_type == CombatActor.ActorType.COMPANION:
			return candidate
	return _primary_player(alive_targets)


func _lowest_health_ratio(alive_targets: Array[CombatActor]) -> CombatActor:
	if alive_targets.is_empty():
		return null
	var chosen: CombatActor = alive_targets[0]
	var chosen_ratio: float = float(chosen.get_current_hp()) / float(chosen.get_max_hp())
	for candidate: CombatActor in alive_targets:
		var ratio: float = float(candidate.get_current_hp()) / float(candidate.get_max_hp())
		if ratio < chosen_ratio or (is_equal_approx(ratio, chosen_ratio) and candidate.formation_slot < chosen.formation_slot):
			chosen = candidate
			chosen_ratio = ratio
	return chosen

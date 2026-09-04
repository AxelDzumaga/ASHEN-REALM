class_name BoonController
extends RefCounted

const BURNING_STRIKE := &"burning_strike"
const ASHEN_BULWARK := &"ashen_bulwark"
const EMBER_BLOOD := &"ember_blood"
const LAST_EMBER := &"last_ember"
const CINDER_SKIN := &"cinder_skin"
const RELENTLESS_FLAME := &"relentless_flame"
const ASHEN_REPRISAL := &"ashen_reprisal"
const PYRE_HEART := &"pyre_heart"

var _run: RunState
## Opcional — combat.gd lo asigna después de construir el controller (no es
## parámetro del constructor para no romper full_run_simulation.gd, que
## instancia BoonController sin CombatActor). Solo se usa para que DECAY
## reduzca la curación de Ember Blood; null es un no-op seguro.
var player_actor: CombatActor
var _simulation_overrides: Dictionary = {}
var _attack_count: int = 0
var _temporary_defense: int = 0
var _relentless_attack: int = 0
var _pyre_attack: int = 0
var _hits_received: int = 0
var _last_cinder_reduction: int = 0
var _last_inferno_triggered: bool = false
var _last_vengeance_triggered: bool = false
var _last_stand_triggered: bool = false
var _phoenix_empowered_this_combat: bool = false
var _enemy_defeated_handled: bool = false
var _combat_ended: bool = false

const PYRE_HEART_HEALTH_THRESHOLD: int = 80


func _init(run: RunState, simulation_overrides: Dictionary = {}) -> void:
	_run = run
	_simulation_overrides = simulation_overrides.duplicate(true)


func on_combat_started() -> void:
	_attack_count = 0
	_temporary_defense = 0
	_relentless_attack = 0
	_hits_received = 0
	_last_cinder_reduction = 0
	_last_inferno_triggered = false
	_last_vengeance_triggered = false
	_last_stand_triggered = false
	_enemy_defeated_handled = false
	_combat_ended = false
	var phoenix_charge: bool = _run.phoenix_blood_empowered
	_run.phoenix_blood_empowered = false
	_phoenix_empowered_this_combat = false
	_pyre_attack = 0
	if _run.current_health * 100 >= _run.max_health * PYRE_HEART_HEALTH_THRESHOLD and copies(PYRE_HEART) > 0:
		_pyre_attack = _scaled_value(PYRE_HEART, _pyre_heart_bonus())
		if phoenix_charge and SynergyResolver.is_active(&"phoenix_blood", _run):
			_pyre_attack += _scaled_value(&"phoenix_blood", SynergyEffectResolver.phoenix_blood_attack_bonus(_run))
			_phoenix_empowered_this_combat = true


func get_effective_attack() -> int:
	return _run.attack + get_temporary_attack_bonus()


func before_player_attack() -> int:
	return get_effective_attack()


func get_effective_defense() -> int:
	return _run.defense + _temporary_defense


func get_temporary_attack_bonus() -> int:
	return _relentless_attack + _pyre_attack + _last_ember_bonus()


func get_temporary_defense_bonus() -> int:
	return _temporary_defense


func get_relentless_attack_bonus() -> int:
	return _relentless_attack


func get_pyre_attack_bonus() -> int:
	return _pyre_attack


func after_player_attack() -> int:
	_last_inferno_triggered = false
	_attack_count += 1
	var burning_damage: int = 0
	var burning_copies: int = copies(BURNING_STRIKE)
	if burning_copies > 0 and _attack_count % 3 == 0:
		burning_damage = _scaled_value(BURNING_STRIKE, 10 + (burning_copies - 1) * 5)
	var relentless_copies: int = copies(RELENTLESS_FLAME)
	if relentless_copies > 0:
		var maximum: int = _effect_cap(RELENTLESS_FLAME, _scaled_value(RELENTLESS_FLAME, 5 + (relentless_copies - 1) * 2))
		var gain: int = maxi(0, _scaled_value(RELENTLESS_FLAME, 1))
		_relentless_attack = mini(_relentless_attack + gain, maximum)
		if burning_damage > 0 and SynergyResolver.is_active(&"inferno_rhythm", _run):
			_relentless_attack = mini(_relentless_attack + _scaled_value(&"inferno_rhythm", SynergyEffectResolver.inferno_relentless_bonus(_run)), maximum)
			_last_inferno_triggered = true
	return burning_damage


func before_player_takes_damage(raw_damage: int) -> int:
	_last_cinder_reduction = 0
	_last_stand_triggered = false
	_hits_received += 1
	var final_damage: int = maxi(1, raw_damage)
	var cinder_copies: int = copies(CINDER_SKIN)
	if cinder_copies > 0 and _hits_received == 1:
		var reduction_scale: float = _effect_scale(CINDER_SKIN)
		var multiplier: float = 1.0 - 0.5 * reduction_scale
		var halved_damage: int = ceili(float(final_damage) * multiplier)
		final_damage = maxi(1, halved_damage - _scaled_value(CINDER_SKIN, (cinder_copies - 1) * 3))
		_last_cinder_reduction = raw_damage - final_damage
	elif cinder_copies > 0 and _hits_received == 2 and _last_ember_bonus() > 0 and SynergyResolver.is_active(&"last_stand", _run):
		var base_multiplier: float = SynergyEffectResolver.last_stand_damage_multiplier(_run)
		var scaled_multiplier: float = 1.0 - (1.0 - base_multiplier) * _effect_scale(&"last_stand")
		var guarded_damage: int = ceili(float(final_damage) * scaled_multiplier)
		final_damage = maxi(1, guarded_damage - (cinder_copies - 1) * 3)
		_last_cinder_reduction = raw_damage - final_damage
		_last_stand_triggered = true
	return final_damage


func after_player_takes_damage() -> int:
	_last_vengeance_triggered = false
	var bulwark_copies: int = copies(ASHEN_BULWARK)
	if bulwark_copies > 0:
		var gain: int = _scaled_value(ASHEN_BULWARK, 2 + (bulwark_copies - 1))
		var cap: int = _effect_cap(ASHEN_BULWARK, _scaled_value(ASHEN_BULWARK, 6))
		_temporary_defense = mini(cap, _temporary_defense + gain)
	var reprisal_copies: int = copies(ASHEN_REPRISAL)
	if reprisal_copies <= 0:
		return 0
	var reprisal_damage: int = _scaled_value(ASHEN_REPRISAL, 4 + (reprisal_copies - 1) * 3)
	if _temporary_defense >= 4 and SynergyResolver.is_active(&"ashen_vengeance", _run):
		reprisal_damage += _scaled_value(&"ashen_vengeance", SynergyEffectResolver.ashen_vengeance_bonus(_run, _temporary_defense))
		_last_vengeance_triggered = true
	return reprisal_damage


func on_enemy_defeated() -> int:
	if _enemy_defeated_handled:
		return 0
	_enemy_defeated_handled = true
	var ember_blood_copies: int = copies(EMBER_BLOOD)
	if ember_blood_copies <= 0:
		return 0
	var heal_amount: int = CombatStatusController.get_effective_healing(player_actor, _scaled_value(EMBER_BLOOD, 6 + (ember_blood_copies - 1) * 3))
	var recovered: int = _run.heal(heal_amount)
	if recovered > 0 and _run.current_health * 100 >= _run.max_health * PYRE_HEART_HEALTH_THRESHOLD and SynergyResolver.is_active(&"phoenix_blood", _run):
		_run.phoenix_blood_empowered = true
	return recovered


func on_combat_ended() -> void:
	if _combat_ended:
		return
	_combat_ended = true
	_attack_count = 0
	_temporary_defense = 0
	_relentless_attack = 0
	_pyre_attack = 0
	_hits_received = 0


func copies(boon_id: StringName) -> int:
	if _effect_scale(boon_id) <= 0.0:
		return 0
	var result: int = _run.get_boon_count(boon_id)
	var stack_caps: Dictionary = _simulation_overrides.get("max_effect_stacks", {})
	return mini(result, int(stack_caps.get(String(boon_id), result)))


func get_last_cinder_reduction() -> int:
	return _last_cinder_reduction


func was_inferno_triggered() -> bool:
	return _last_inferno_triggered


func was_vengeance_triggered() -> bool:
	return _last_vengeance_triggered


func was_last_stand_triggered() -> bool:
	return _last_stand_triggered


func is_phoenix_empowered() -> bool:
	return _phoenix_empowered_this_combat


func has_pyre_heart_active() -> bool:
	return _pyre_attack > 0


func is_last_ember_active() -> bool:
	return _last_ember_bonus() > 0


func get_active_effects_text() -> String:
	var effects: Array[String] = []
	if _last_ember_bonus() > 0:
		effects.append("LAST EMBER")
	if _pyre_attack > 0:
		effects.append("PYRE HEART + PHOENIX" if _phoenix_empowered_this_combat else "PYRE HEART")
	if _relentless_attack > 0:
		effects.append("RELENTLESS +%d ATQ" % _relentless_attack)
	if _temporary_defense > 0:
		effects.append("BULWARK +%d DEF" % _temporary_defense)
	return "EFECTOS ACTIVOS: NINGUNO" if effects.is_empty() else "EFECTOS ACTIVOS: " + "  ·  ".join(effects)


func _last_ember_bonus() -> int:
	var boon_copies: int = copies(LAST_EMBER)
	if boon_copies <= 0 or _run.current_health * 100 > _run.max_health * 30:
		return 0
	return _scaled_value(LAST_EMBER, 8 + (boon_copies - 1) * 4)


func _pyre_heart_bonus() -> int:
	var boon_copies: int = copies(PYRE_HEART)
	return 0 if boon_copies <= 0 else 5 + (boon_copies - 1) * 3


func _effect_scale(effect_id: StringName) -> float:
	var scales: Dictionary = _simulation_overrides.get("effect_scales", {})
	return maxf(0.0, float(scales.get(String(effect_id), 1.0)))


func _scaled_value(effect_id: StringName, value: int) -> int:
	return maxi(0, roundi(float(value) * _effect_scale(effect_id)))


func _effect_cap(effect_id: StringName, fallback: int) -> int:
	var caps: Dictionary = _simulation_overrides.get("effect_caps", {})
	return maxi(0, int(caps.get(String(effect_id), fallback)))


static func describe_next_copy(boon_id: StringName, owned: int) -> String:
	var next: int = owned + 1
	match boon_id:
		BURNING_STRIKE:
			return "Cada 3.er ataque: +%d → +%d de daño adicional" % [_burning_value(owned), _burning_value(next)] if owned > 0 else "Cada 3.er ataque inflige +10 de daño adicional"
		ASHEN_BULWARK:
			return "Defensa por golpe: +%d → +%d (máximo +6)" % [_bulwark_value(owned), _bulwark_value(next)] if owned > 0 else "Tras recibir daño, ganás +2 de Defensa (máximo +6)"
		EMBER_BLOOD:
			return "Curación al vencer: %d → %d de Vida" % [_ember_blood_value(owned), _ember_blood_value(next)] if owned > 0 else "Recuperás 6 de Vida al derrotar a un enemigo"
		LAST_EMBER:
			return "Ataque con 30%% de Vida: +%d → +%d" % [_last_ember_value(owned), _last_ember_value(next)] if owned > 0 else "Ganás +8 de Ataque con 30% de Vida o menos"
		CINDER_SKIN:
			return "Primer golpe: 50%% de daño; reducción plana %d → %d" % [_cinder_flat(owned), _cinder_flat(next)] if owned > 0 else "El primer golpe de cada combate inflige 50% de daño"
		RELENTLESS_FLAME:
			return "Máximo de Ataque acumulado: +%d → +%d" % [_relentless_cap(owned), _relentless_cap(next)] if owned > 0 else "Ganás +1 de Ataque tras cada ataque, hasta +5"
		ASHEN_REPRISAL:
			return "Daño de represalia: %d → %d" % [_reprisal_value(owned), _reprisal_value(next)] if owned > 0 else "Infligís 4 de daño tras recibir daño"
		PYRE_HEART:
			return "Ataque al entrar con 80%% de Vida: +%d → +%d" % [_pyre_value(owned), _pyre_value(next)] if owned > 0 else "Entrá al combate con 80% de Vida o más para ganar +5 de Ataque"
		_:
			return "Efecto pasivo desconocido"


static func _burning_value(count: int) -> int:
	return 0 if count <= 0 else 10 + (count - 1) * 5


static func _bulwark_value(count: int) -> int:
	return 0 if count <= 0 else 2 + (count - 1)


static func _ember_blood_value(count: int) -> int:
	return 0 if count <= 0 else 6 + (count - 1) * 3


static func _last_ember_value(count: int) -> int:
	return 0 if count <= 0 else 8 + (count - 1) * 4


static func _cinder_flat(count: int) -> int:
	return maxi(0, count - 1) * 3


static func _relentless_cap(count: int) -> int:
	return 0 if count <= 0 else 5 + (count - 1) * 2


static func _reprisal_value(count: int) -> int:
	return 0 if count <= 0 else 4 + (count - 1) * 3


static func _pyre_value(count: int) -> int:
	return 0 if count <= 0 else 5 + (count - 1) * 3

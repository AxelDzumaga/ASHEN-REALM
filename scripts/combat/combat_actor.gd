class_name CombatActor
extends RefCounted

enum Team {
	PLAYER,
	ENEMY,
}

enum ActorType {
	PLAYER,
	COMPANION,
	NORMAL_ENEMY,
	ELITE,
	BOSS,
	MINION,
}

## Combat Domain M2 — QUIÉN decide la acción de este actor, separado de
## ActorType (QUÉ es el actor) y de Team (de qué lado pelea). Antes de M2,
## combat.gd inferís esto comparando identidad de objeto contra los
## escalares player_actor/companion_actor; ahora es un dato propio del
## actor, asignado una sola vez en construcción (from_player/from_companion/
## from_enemy), igual que team/actor_type. SCRIPTED existe como semilla de
## enum aprobada para contenido futuro — ningún actor actual lo usa.
enum ControllerType {
	PLAYER_CONTROLLED,
	AI_ALLY,
	AI_ENEMY,
	SCRIPTED,
}

var actor_id: StringName
var display_name: String
var team: Team
var actor_type: ActorType
var controller_type: ControllerType = ControllerType.AI_ENEMY
var source_data: RefCounted
var visual_data: CharacterVisualData
var visual_view: CombatCharacterView
var targetable: bool = true
var formation_slot: int = 0
var death_presented: bool = false
var status_effects: Array[StatusEffectInstance] = []

var _max_hp: int
var _current_hp: int
var _attack: int
var _defense: int
var _run_state: RunState


func _init(
	runtime_id: StringName,
	actor_name: String,
	actor_team: Team,
	kind: ActorType,
	maximum_hp: int,
	starting_hp: int,
	attack_value: int,
	defense_value: int,
	origin: RefCounted = null,
	visual: CharacterVisualData = null,
	control: ControllerType = ControllerType.AI_ENEMY,
) -> void:
	actor_id = runtime_id
	display_name = actor_name
	team = actor_team
	actor_type = kind
	controller_type = control
	source_data = origin
	visual_data = visual
	_max_hp = maxi(1, maximum_hp)
	_current_hp = clampi(starting_hp, 0, _max_hp)
	_attack = maxi(0, attack_value)
	_defense = maxi(0, defense_value)
	targetable = _current_hp > 0


static func from_player(runtime_id: StringName, run: RunState, visual: CharacterVisualData) -> CombatActor:
	var actor: CombatActor = CombatActor.new(
		runtime_id,
		run.player_name,
		Team.PLAYER,
		ActorType.PLAYER,
		run.max_health,
		run.current_health,
		run.attack,
		run.defense,
		run,
		visual,
		ControllerType.PLAYER_CONTROLLED,
	)
	actor._run_state = run
	return actor


static func from_enemy(runtime_id: StringName, enemy: EnemyData, kind: ActorType) -> CombatActor:
	return CombatActor.new(
		runtime_id,
		enemy.display_name,
		Team.ENEMY,
		kind,
		enemy.max_health,
		enemy.max_health,
		enemy.attack,
		enemy.defense,
		enemy,
		enemy.visual,
		ControllerType.AI_ENEMY,
	)


static func from_companion(runtime_id: StringName, companion: CompanionData) -> CombatActor:
	return CombatActor.new(
		runtime_id,
		companion.display_name,
		Team.PLAYER,
		ActorType.COMPANION,
		companion.max_hp,
		companion.max_hp,
		companion.attack,
		companion.defense,
		companion,
		companion.visual_data,
		ControllerType.AI_ALLY,
	)


func set_visual_view(view: CombatCharacterView) -> void:
	visual_view = view


func get_current_hp() -> int:
	if _run_state != null:
		return _run_state.current_health
	return _current_hp


func get_max_hp() -> int:
	if _run_state != null:
		return _run_state.max_health
	return _max_hp


func get_attack() -> int:
	if _run_state != null:
		return _run_state.attack
	return _attack


func get_defense() -> int:
	if _run_state != null:
		return _run_state.defense
	return _defense


func set_current_hp(value: int) -> void:
	var clamped_hp: int = clampi(value, 0, get_max_hp())
	_current_hp = clamped_hp
	if _run_state != null:
		_run_state.current_health = clamped_hp
	if clamped_hp <= 0:
		targetable = false


func apply_damage(amount: int) -> int:
	var safe_amount: int = maxi(0, amount)
	var previous_hp: int = get_current_hp()
	set_current_hp(previous_hp - safe_amount)
	return previous_hp - get_current_hp()


func heal(amount: int) -> int:
	if amount <= 0 or not is_alive():
		return 0
	if _run_state != null:
		return _run_state.heal(amount)
	var previous_hp: int = get_current_hp()
	set_current_hp(previous_hp + amount)
	return get_current_hp() - previous_hp


func is_alive() -> bool:
	return get_current_hp() > 0


func is_targetable() -> bool:
	return targetable and is_alive()


func has_status(status_id: StringName) -> bool:
	return get_status(status_id) != null


func get_status(status_id: StringName) -> StatusEffectInstance:
	for instance: StatusEffectInstance in status_effects:
		if instance.active and instance.data.status_id == status_id:
			return instance
	return null


func get_statuses() -> Array[StatusEffectInstance]:
	var active_statuses: Array[StatusEffectInstance] = []
	for instance: StatusEffectInstance in status_effects:
		if instance.active:
			active_statuses.append(instance)
	return active_statuses


func add_status_instance(instance: StatusEffectInstance) -> void:
	if instance != null and instance.active and get_status(instance.data.status_id) == null:
		status_effects.append(instance)


func remove_status_instance(status_id: StringName) -> bool:
	for index: int in range(status_effects.size() - 1, -1, -1):
		if status_effects[index].data.status_id == status_id:
			status_effects[index].active = false
			status_effects.remove_at(index)
			return true
	return false


func clear_expired_statuses() -> void:
	for index: int in range(status_effects.size() - 1, -1, -1):
		if not status_effects[index].active:
			status_effects.remove_at(index)


func clear_all_statuses() -> void:
	for instance: StatusEffectInstance in status_effects:
		instance.active = false
	status_effects.clear()

class_name CombatChoreographyController
extends Node

enum MotionStyle {
	MELEE,
	AGGRESSIVE,
	STATIC,
	RANGED,
}

const NORMAL_KNOCKBACK: float = 18.0
const ELITE_KNOCKBACK: float = 12.0
const BOSS_KNOCKBACK: float = 7.0
const PLAYER_KNOCKBACK: float = 15.0
const HIT_STOP_DURATION: float = 0.06
const EMPHASIZED_HIT_STOP_DURATION: float = 0.078
const HEAVY_HIT_STOP_DURATION: float = 0.082
const MELEE_DURATION: float = 0.44
const AGGRESSIVE_DURATION: float = 0.38

var _attacker: CombatCharacterView
var _target: CombatCharacterView
var _attacker_home: Vector2
var _target_home: Vector2
var _attacker_scale: Vector2
var _attacker_rotation: float
var _attacker_z_index: int
var _direction_global: Vector2 = Vector2.RIGHT
var _actor_type: CombatActor.ActorType = CombatActor.ActorType.NORMAL_ENEMY
var _style: MotionStyle = MotionStyle.MELEE


func approach(
	attacker: CombatCharacterView,
	target: CombatCharacterView,
	actor_type: CombatActor.ActorType,
	style: MotionStyle = MotionStyle.MELEE,
) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return
	_capture_action(attacker, target, actor_type, style)
	if style == MotionStyle.STATIC or style == MotionStyle.RANGED:
		return
	if SettingsManager.reduce_motion:
		return
	var attacker_center: Vector2 = attacker.get_global_rect().get_center()
	var target_center: Vector2 = target.get_global_rect().get_center()
	_direction_global = target_center - attacker_center
	if _direction_global.length_squared() <= 0.001:
		_direction_global = Vector2.RIGHT
	_direction_global = _direction_global.normalized()
	var anticipation_distance: float = 14.0 if style == MotionStyle.MELEE else 10.0
	if actor_type == CombatActor.ActorType.BOSS:
		anticipation_distance = 6.0
	var anticipation_offset: Vector2 = _global_vector_to_parent(attacker, -_direction_global * anticipation_distance)
	var anticipation_duration: float = 0.075 if style == MotionStyle.MELEE else 0.05
	if actor_type == CombatActor.ActorType.BOSS:
		anticipation_duration = 0.1
	var anticipation: Tween = create_tween().set_parallel(true)
	anticipation.tween_property(attacker, "position", _attacker_home + anticipation_offset, anticipation_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	anticipation.tween_property(attacker, "scale", _attacker_scale * Vector2(0.96, 1.04), anticipation_duration)
	anticipation.tween_property(attacker, "rotation", _attacker_rotation - signf(_direction_global.x) * 0.025, anticipation_duration)
	await anticipation.finished
	if not _action_views_valid():
		return
	var contact_ratio: float = 0.57
	if style == MotionStyle.AGGRESSIVE:
		contact_ratio = 0.64
	if actor_type == CombatActor.ActorType.ELITE:
		contact_ratio *= 0.9
	elif actor_type == CombatActor.ActorType.BOSS:
		contact_ratio *= 0.78
	var contact_center_global: Vector2 = attacker_center.lerp(target_center, contact_ratio)
	var contact_position: Vector2 = _global_center_to_local_position(attacker, contact_center_global)
	var impact_timing_ratio: float = clampf(attacker.get_animation_contact_ratio(), 0.25, 0.8)
	if style == MotionStyle.AGGRESSIVE:
		impact_timing_ratio = maxf(0.4, impact_timing_ratio - 0.08)
	var action_duration: float = MELEE_DURATION if style == MotionStyle.MELEE else AGGRESSIVE_DURATION
	var approach_duration: float = maxf(0.12, action_duration * impact_timing_ratio - anticipation_duration)
	if actor_type == CombatActor.ActorType.ELITE:
		approach_duration += 0.025
	elif actor_type == CombatActor.ActorType.BOSS:
		approach_duration += 0.04
	attacker.z_index = maxi(_attacker_z_index + 3, 3)
	var advance: Tween = create_tween().set_parallel(true)
	advance.tween_property(attacker, "position", contact_position, approach_duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	var contact_scale: float = 1.025 if actor_type == CombatActor.ActorType.BOSS else (1.075 if style == MotionStyle.AGGRESSIVE else 1.055)
	advance.tween_property(attacker, "scale", _attacker_scale * contact_scale, approach_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	advance.tween_property(attacker, "rotation", _attacker_rotation + signf(_direction_global.x) * 0.035, approach_duration)
	await advance.finished


func impact_and_return(hit_stop_duration: float = HIT_STOP_DURATION) -> void:
	if not _action_views_valid():
		return
	if SettingsManager.reduce_motion:
		_restore_attacker()
		return
	await get_tree().create_timer(clampf(hit_stop_duration, 0.0, 0.08), false).timeout
	if not _action_views_valid():
		return
	var knockback_distance: float = _knockback_distance()
	var knockback_offset: Vector2 = _global_vector_to_parent(_target, _direction_global * knockback_distance)
	var target_scale: Vector2 = _target.scale
	var knockback: Tween = create_tween().set_parallel(true)
	knockback.tween_property(_target, "position", _target_home + knockback_offset, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	knockback.tween_property(_target, "scale", target_scale * Vector2(1.06, 0.92), 0.07)
	knockback.chain().tween_property(_target, "position", _target_home, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	knockback.tween_property(_target, "scale", target_scale, 0.11)
	var return_duration: float = 0.18 if _style == MotionStyle.MELEE else 0.17
	if _actor_type == CombatActor.ActorType.ELITE:
		return_duration = 0.23
	elif _actor_type == CombatActor.ActorType.BOSS:
		return_duration = 0.24
	var retreat: Tween = create_tween().set_parallel(true)
	retreat.tween_property(_attacker, "position", _attacker_home, return_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	retreat.tween_property(_attacker, "scale", _attacker_scale, return_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	retreat.tween_property(_attacker, "rotation", _attacker_rotation, return_duration)
	await retreat.finished
	if is_instance_valid(_target):
		_target.position = _target_home
	_restore_attacker()


func begin_static(actor_view: CombatCharacterView) -> void:
	if not is_instance_valid(actor_view):
		return
	_attacker = actor_view
	_attacker_home = actor_view.position
	_attacker_scale = actor_view.scale
	_attacker_rotation = actor_view.rotation
	_attacker_z_index = actor_view.z_index
	if SettingsManager.reduce_motion:
		return
	var brace: Tween = create_tween()
	brace.tween_property(actor_view, "position", _attacker_home + Vector2(0.0, 6.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await brace.finished


func finish_static() -> void:
	if not is_instance_valid(_attacker):
		return
	if SettingsManager.reduce_motion:
		_restore_attacker()
		return
	var release: Tween = create_tween()
	release.tween_property(_attacker, "position", _attacker_home, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await release.finished
	_restore_attacker()


func _capture_action(
	attacker: CombatCharacterView,
	target: CombatCharacterView,
	actor_type: CombatActor.ActorType,
	style: MotionStyle,
) -> void:
	_attacker = attacker
	_target = target
	_actor_type = actor_type
	_style = style
	_attacker_home = attacker.position
	_target_home = target.position
	_attacker_scale = attacker.scale
	_attacker_rotation = attacker.rotation
	_attacker_z_index = attacker.z_index


func _global_center_to_local_position(view: CombatCharacterView, global_center: Vector2) -> Vector2:
	var parent_control: Control = view.get_parent() as Control
	if parent_control == null:
		return view.position
	var local_center: Vector2 = parent_control.get_global_transform().affine_inverse() * global_center
	return local_center - view.size * 0.5


func _global_vector_to_parent(view: CombatCharacterView, global_vector: Vector2) -> Vector2:
	var parent_control: Control = view.get_parent() as Control
	if parent_control == null:
		return global_vector
	var inverse: Transform2D = parent_control.get_global_transform().affine_inverse()
	var origin_local: Vector2 = inverse * Vector2.ZERO
	return (inverse * global_vector) - origin_local


func _knockback_distance() -> float:
	match _actor_type:
		CombatActor.ActorType.ELITE:
			return ELITE_KNOCKBACK
		CombatActor.ActorType.BOSS:
			return BOSS_KNOCKBACK
		CombatActor.ActorType.PLAYER, CombatActor.ActorType.COMPANION:
			return NORMAL_KNOCKBACK
		_:
			return PLAYER_KNOCKBACK


func _restore_attacker() -> void:
	if not is_instance_valid(_attacker):
		return
	_attacker.position = _attacker_home
	_attacker.scale = _attacker_scale
	_attacker.rotation = _attacker_rotation
	_attacker.z_index = _attacker_z_index


func _action_views_valid() -> bool:
	return is_instance_valid(_attacker) and is_instance_valid(_target) and is_inside_tree()

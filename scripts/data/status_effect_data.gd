class_name StatusEffectData
extends Resource

enum Category { BUFF, DEBUFF, UTILITY, DOT, DEFENSE }
enum DurationType { TURNS, HITS, PERMANENT_COMBAT }
enum Trigger { ON_APPLY, TURN_START, TURN_END, ON_HIT_RECEIVED, ON_BASIC_ATTACK, ON_REMOVE }
enum StackMode { NONE, REFRESH_DURATION, ADD_STACK, ADD_DURATION }

@export var status_id: StringName
@export var display_name: String = "Estado"
@export_multiline var description: String = ""
@export var icon_id: StringName = &"unknown"
@export var category: Category = Category.UTILITY
@export var stack_mode: StackMode = StackMode.NONE
@export_range(1, 99, 1) var max_stacks: int = 1
@export var duration_type: DurationType = DurationType.TURNS
@export_range(0, 99, 1) var base_duration: int = 1
@export var trigger: Trigger = Trigger.TURN_START
@export var magnitude_per_stack: int = 0
## Segunda magnitud opcional, para statuses con un efecto adicional además del
## principal — ej. DECAY: magnitude_per_stack es el daño de DoT por stack,
## secondary_magnitude_per_stack es el % de reducción de curación recibida
## por stack. 0 por defecto; el resto de los statuses no lo usa.
@export var secondary_magnitude_per_stack: int = 0
@export var tags: Array[StringName] = []

class_name BossPhaseData
extends Resource

@export var phase_id: StringName
@export var display_name: String = "Fase"
@export_range(1, 100) var hp_threshold_percent: int = 100
@export var ai_profile_override: EnemyAIData
@export_range(0.5, 3.0, 0.05) var attack_multiplier: float = 1.0
@export_range(-99, 99) var defense_bonus: int = 0
@export var summon_data: EnemyData
@export_range(0, 2) var summon_count: int = 0
@export var visual_accent: Color = Color("c45f36")
@export var transition_message: String
@export var tags: Array[StringName] = []


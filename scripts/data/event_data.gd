class_name EventData
extends Resource

enum OptionReward { NONE, BUILD_BOON, BUILD_AUGMENT }
enum DifficultyTier { EASY, MEDIUM, HARD }

@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var required_flag_ids: Array[StringName] = []
@export var excluded_flag_ids: Array[StringName] = []
@export var selection_priority: int = 0
@export var repeatable: bool = false
@export var difficulty_tier: DifficultyTier = DifficultyTier.MEDIUM
@export_multiline var risk_summary: String

@export_group("Option A")
@export var option_a_text: String
@export var option_a_effect_text: String
@export var option_a_health_delta: int = 0
@export var option_a_max_health_delta: int = 0
@export var option_a_attack_delta: int = 0
@export var option_a_defense_delta: int = 0
@export var option_a_run_ash_delta: int = 0
@export var option_a_required_flag_ids: Array[StringName] = []
@export var option_a_set_flag_ids: Array[StringName] = []
@export var option_a_reward: OptionReward = OptionReward.NONE
@export var option_a_tags: Array[StringName] = []

@export_group("Option B")
@export var option_b_text: String
@export var option_b_effect_text: String
@export var option_b_health_delta: int = 0
@export var option_b_max_health_delta: int = 0
@export var option_b_attack_delta: int = 0
@export var option_b_defense_delta: int = 0
@export var option_b_run_ash_delta: int = 0
@export var option_b_required_flag_ids: Array[StringName] = []
@export var option_b_set_flag_ids: Array[StringName] = []
@export var option_b_reward: OptionReward = OptionReward.NONE
@export var option_b_tags: Array[StringName] = []


func option_id(option_a: bool) -> StringName:
	return StringName("%s:%s" % [id, "a" if option_a else "b"])


func get_difficulty_label() -> String:
	match difficulty_tier:
		DifficultyTier.EASY:
			return "FÁCIL"
		DifficultyTier.HARD:
			return "DIFÍCIL"
		_:
			return "MEDIO"

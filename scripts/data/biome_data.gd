class_name BiomeData
extends Resource

enum DifficultyTier { EASY, MEDIUM, HARD }

@export var id: StringName
@export var display_name: String
@export var subtitle: String
@export_multiline var description: String
## Moneda visible de refinamiento/drops de Evento propia de este bioma — un
## objeto físico distinto por región, sin reciclar vocabulario entre biomas.
@export var material_name: String = ""
@export_range(2, 100) var board_length: int = 30

@export_group("Progression")
@export_range(1, 99) var progression_order: int = 1
@export var difficulty_tier: DifficultyTier = DifficultyTier.EASY
@export var required_milestone_id: StringName
@export_multiline var difficulty_summary: String
@export_range(1, 50, 1) var recommended_level: int = 1
@export_range(1, 5, 1) var danger_rating: int = 1

@export_group("Presentation")
@export var background_color: Color = Color("100d16")
@export var panel_color: Color = Color("211c29")
@export var accent_color: Color = Color("e6a23c")
@export var theme_family: StringName = &"dark_fantasy"
@export var environment_profile: StringName = &""
@export var map_style: StringName = &""
@export var ambient_profile: StringName = &""
@export var background_hook: StringName = &""
@export_range(0.5, 2.0, 0.01) var entry_audio_pitch: float = 1.0
@export var board_thumbnail: Texture2D
@export var environment_texture: Texture2D
@export var combat_background: Texture2D
@export var foreground_texture: Texture2D
@export_file("*.png", "*.webp") var board_thumbnail_path: String
@export_file("*.png", "*.webp") var environment_texture_path: String
@export_file("*.png", "*.webp") var combat_background_path: String
@export_file("*.png", "*.webp") var foreground_texture_path: String
@export var ambient_tint: Color = Color.WHITE
@export var board_overlay_color: Color = Color(0.03, 0.025, 0.03, 0.58)
@export var combat_overlay_color: Color = Color(0.03, 0.02, 0.025, 0.34)
@export var boss_overlay_color: Color = Color(0.12, 0.015, 0.025, 0.48)

@export_group("Gameplay Rules")
@export var modifiers: Array[BiomeModifierData] = []
@export var build_affinity_tag: StringName = &""

var _board_thumbnail_cache: Texture2D
var _environment_cache: Texture2D
var _combat_background_cache: Texture2D
var _foreground_cache: Texture2D

@export_group("Encounters")
@export var normal_enemy_pool: Array[EnemyData] = []
@export var normal_spawn_entries: Array[EnemySpawnEntryData] = []
@export var elite_enemy_pool: Array[EnemyData] = []
@export var boss: EnemyData
@export var future_final_boss_candidates: Array[EnemyData] = []
@export var event_pool: Array[EventData] = []

@export_group("Tile Count Ranges")
@export var empty_min: int = 6
@export var empty_max: int = 9
@export var combat_min: int = 7
@export var combat_max: int = 9
@export var event_min: int = 3
@export var event_max: int = 5
@export var treasure_min: int = 2
@export var treasure_max: int = 3
@export var heal_min: int = 2
@export var heal_max: int = 3
@export var elite_min: int = 1
@export var elite_max: int = 2

@export_group("Placement Weights")
@export var empty_weight: int = 6
@export var combat_weight: int = 4
@export var event_weight: int = 3
@export var treasure_weight: int = 2
@export var heal_weight: int = 2
@export var elite_weight: int = 1


func get_board_thumbnail() -> Texture2D:
	if board_thumbnail != null:
		return board_thumbnail
	if _board_thumbnail_cache == null:
		_board_thumbnail_cache = _load_optional_texture(board_thumbnail_path)
	return _board_thumbnail_cache


func get_environment_texture() -> Texture2D:
	if environment_texture != null:
		return environment_texture
	if _environment_cache == null:
		_environment_cache = _load_optional_texture(environment_texture_path)
	return _environment_cache


func get_combat_background() -> Texture2D:
	if combat_background != null:
		return combat_background
	if _combat_background_cache == null:
		_combat_background_cache = _load_optional_texture(combat_background_path)
	if _combat_background_cache != null:
		return _combat_background_cache
	return get_environment_texture()


func get_foreground_texture() -> Texture2D:
	if foreground_texture != null:
		return foreground_texture
	if _foreground_cache == null:
		_foreground_cache = _load_optional_texture(foreground_texture_path)
	return _foreground_cache


func get_overlay_color(context: StringName, is_boss: bool = false) -> Color:
	if is_boss:
		return boss_overlay_color
	if context == &"combat":
		return combat_overlay_color
	return board_overlay_color


func get_difficulty_label() -> String:
	match difficulty_tier:
		DifficultyTier.MEDIUM:
			return "MEDIA"
		DifficultyTier.HARD:
			return "DIFÍCIL"
		_:
			return "FÁCIL"


func get_final_boss_candidates() -> Array[EnemyData]:
	var candidates: Array[EnemyData] = []
	if boss != null:
		candidates.append(boss)
	for candidate: EnemyData in future_final_boss_candidates:
		if candidate != null and candidate not in candidates:
			candidates.append(candidate)
	return candidates


func get_recommended_level_label() -> String:
	return "NIVEL RECOMENDADO %d" % recommended_level


func _load_optional_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
		return null
	var loaded: Resource = ResourceLoader.load(path, "Texture2D")
	return loaded as Texture2D

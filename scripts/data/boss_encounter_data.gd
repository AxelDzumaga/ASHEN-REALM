class_name BossEncounterData
extends Resource

enum EncounterRole { INTERMEDIATE, FINAL }
enum BossTier { MINOR, GUARDIAN, FINAL }

@export var boss_id: StringName
@export var display_name: String = "Encuentro de jefe"
@export var mechanic_description: String
@export var encounter_role: EncounterRole = EncounterRole.FINAL
@export_range(1, 5) var threat_level: int = 4
@export var phases: Array[BossPhaseData] = []
@export var summon_action: EnemyActionData
@export var counter_action_id: StringName
@export_range(0.1, 2.0, 0.05) var counter_damage_multiplier: float = 0.75
## Combat Domain M5 — el techo 5 acá espeja CombatRules.MAX_TEAM_SIZE
## (@export_range no puede referenciarlo directamente). El default 3 se
## mantiene sin cambios para no alterar el comportamiento de bosses ya
## autorados — solo el techo permitido sube, para que un futuro/test boss
## pueda pedir hasta 5. La validación real de capacidad de equipo en
## tiempo de ejecución usa CombatRules.MAX_TEAM_SIZE (ver combat.gd).
@export_range(1, 5) var max_active_enemies: int = 3
@export var tags: Array[StringName] = []
@export var native_biomes: Array[StringName] = []
@export var possible_biomes: Array[StringName] = []
@export var roaming_role: StringName = &"biome_locked"
@export var boss_tier: BossTier = BossTier.GUARDIAN
@export var boss_chest_id: StringName = &""
@export_range(0, 999, 1) var guardian_sigils_reward: int = 0


func get_phase(index: int) -> BossPhaseData:
	if index < 0 or index >= phases.size():
		return null
	return phases[index]


func get_role_label() -> String:
	return "JEFE FINAL" if encounter_role == EncounterRole.FINAL else "JEFE INTERMEDIO"


func get_threat_label() -> String:
	return "AMENAZA %d/5" % threat_level

class_name TutorialCatalog
extends RefCounted

const LOBBY_INTRO := &"lobby_intro"
const BOARD_INTRO := &"board_intro"
const ROLL_DIE := &"roll_die"
const TILE_COMBAT := &"tile_combat"
const TILE_ELITE := &"tile_elite"
const TILE_EVENT := &"tile_event"
const TILE_TREASURE := &"tile_treasure"
const TILE_HEAL := &"tile_heal"
const TILE_BOSS := &"tile_boss"
const COMBAT_AUTO := &"combat_auto"
const COMBAT_ACTIVE_SKILL := &"combat_active_skill"
const ENERGY_GAIN := &"energy_gain"
const SKILL_READY := &"skill_ready"
const SKILL_COOLDOWN := &"skill_cooldown"
const UPGRADE_SELECTION := &"upgrade_selection"
const REROLL := &"reroll"
const PASSIVE_BOON := &"passive_boon"
const SYNERGY_HINT := &"synergy_hint"
const SYNERGY_ACTIVATED := &"synergy_activated"
const SKILL_AUGMENT := &"skill_augment"
const EQUIPMENT_FOUND := &"equipment_found"
const ASH_CURRENCY := &"ash_currency"
const PERMANENT_UPGRADES := &"permanent_upgrades"
const EQUIPMENT_SCREEN := &"equipment_screen"
const ARCHIVE_INTRO := &"archive_intro"
const ARCHIVE_NEW := &"archive_new"
const BOSS_REWARD := &"boss_reward"
const FIRST_DEFEAT := &"first_defeat"
const FIRST_VICTORY := &"first_victory"
const RUN_XP := &"run_xp"
const RUN_LEVEL_UP := &"run_level_up"
const BIOME_RULES := &"biome_rules"
const COMPANION_COMBAT := &"companion_combat"
const ENEMY_AI := &"enemy_ai"
const BOSS_PHASE := &"boss_phase"
const BOSS_SUMMON := &"boss_summon"
const TARGET_SELECTION := &"target_selection"
const STATUS_EFFECTS := &"status_effects"
const COMPANION_SELECTION := &"companion_selection"
const RUN_RESULTS := &"run_results"

const ALL_IDS: Array[StringName] = [
	LOBBY_INTRO, BOARD_INTRO, ROLL_DIE, TILE_COMBAT, TILE_ELITE, TILE_EVENT,
	TILE_TREASURE, TILE_HEAL, TILE_BOSS, COMBAT_AUTO, COMBAT_ACTIVE_SKILL,
	ENERGY_GAIN, SKILL_READY, SKILL_COOLDOWN, UPGRADE_SELECTION, REROLL,
	PASSIVE_BOON, SYNERGY_HINT, SYNERGY_ACTIVATED, SKILL_AUGMENT,
	EQUIPMENT_FOUND, ASH_CURRENCY, PERMANENT_UPGRADES, EQUIPMENT_SCREEN,
	ARCHIVE_INTRO, ARCHIVE_NEW, BOSS_REWARD, FIRST_DEFEAT, FIRST_VICTORY,
	RUN_XP, RUN_LEVEL_UP, BIOME_RULES, COMPANION_COMBAT, ENEMY_AI,
	BOSS_PHASE, BOSS_SUMMON,
	TARGET_SELECTION, STATUS_EFFECTS, COMPANION_SELECTION, RUN_RESULTS,
]

const MIGRATED_V5_COMPLETED: Array[StringName] = [
	LOBBY_INTRO, BOARD_INTRO, ROLL_DIE, COMBAT_AUTO, COMBAT_ACTIVE_SKILL,
	ENERGY_GAIN, SKILL_READY, SKILL_COOLDOWN, UPGRADE_SELECTION, REROLL,
	PASSIVE_BOON, SKILL_AUGMENT, EQUIPMENT_FOUND, ASH_CURRENCY,
	PERMANENT_UPGRADES, EQUIPMENT_SCREEN, ARCHIVE_INTRO, ARCHIVE_NEW,
]

static var _entries: Dictionary[StringName, TutorialData] = _build_entries()


static func get_by_id(id: StringName) -> TutorialData:
	return _entries.get(id) as TutorialData


static func is_valid_id(id: StringName) -> bool:
	return _entries.has(id)


static func _build_entries() -> Dictionary[StringName, TutorialData]:
	var entries: Dictionary[StringName, TutorialData] = {}
	_add(entries, LOBBY_INTRO, "REFUGIO", "Desde acá preparás tu próxima expedición. Cuando estés listo, elegí INICIAR RUN.", TutorialData.Priority.CORE)
	_add(entries, BOARD_INTRO, "TABLERO", "Tirá el dado y avanzarás automáticamente. La casilla donde caigas determina qué ocurre.", TutorialData.Priority.CORE)
	_add(entries, ROLL_DIE, "TIRÁ EL DADO", "Tocá TIRAR. El resultado mueve al Wanderer.")
	_add(entries, TILE_COMBAT, "COMBATE", "Esta casilla inicia un encuentro. Elegirás cada acción del Wanderer.")
	_add(entries, TILE_ELITE, "ÉLITE", "Un encuentro más exigente, con mejores recompensas.")
	_add(entries, TILE_EVENT, "EVENTO", "Elegí cómo responder. La decisión puede ayudarte o perjudicarte.")
	_add(entries, TILE_TREASURE, "TESORO", "Otorga una recompensa para esta run.")
	_add(entries, TILE_HEAL, "CURACIÓN", "Restaura Vida sin superar tu máximo.")
	_add(entries, TILE_BOSS, "JEFE", "Es el encuentro final. Los Jefes cambian de fase durante el combate.", TutorialData.Priority.HIGH)
	_add(entries, COMBAT_AUTO, "TU TURNO", "Elegí ATAQUE. Es gratuito y genera Brasa; después responderán los enemigos.", TutorialData.Priority.CORE)
	_add(entries, COMBAT_ACTIVE_SKILL, "HABILIDADES", "La Brasa alimenta tus habilidades. Cada una tiene un costo y puede tener recarga.", TutorialData.Priority.HIGH)
	_add(entries, ENERGY_GAIN, "BRASA", "Ganaste Brasa. La barra de combate alimenta tus habilidades.", TutorialData.Priority.HIGH)
	_add(entries, SKILL_READY, "HABILIDAD LISTA", "Ya tenés Brasa suficiente para usar una habilidad.")
	_add(entries, SKILL_COOLDOWN, "RECARGA", "Algunas habilidades deben recargarse antes de volver a usarse.")
	_add(entries, UPGRADE_SELECTION, "RECOMPENSA DE RUN", "Elegí una opción para fortalecer esta expedición.")
	_add(entries, REROLL, "VOLVER A TIRAR", "Las repeticiones disponibles pertenecen a toda la run.")
	_add(entries, PASSIVE_BOON, "BOON", "Los Boons modifican tu build durante esta run. Elegí uno o usá VOLVER A TIRAR.", TutorialData.Priority.HIGH)
	_add(entries, SYNERGY_HINT, "SINERGIA", "Equipo, habilidades, Augments, Boons y Companion pueden aportar a una build.")
	_add(entries, SYNERGY_ACTIVATED, "SINERGIA ACTIVADA", "Apareció al combinar elementos compatibles de tu build. Su efecto es pasivo.", TutorialData.Priority.HIGH)
	_add(entries, SKILL_AUGMENT, "AUGMENT", "Mejora una habilidad equipada durante esta run. Se reinicia al terminar.", TutorialData.Priority.HIGH)
	_add(entries, EQUIPMENT_FOUND, "EQUIPO ENCONTRADO", "El equipo obtenido se conserva al volver al Refugio.")
	_add(entries, ASH_CURRENCY, "PROGRESO PERMANENTE", "La Ceniza depositada en Results compra mejoras permanentes. Los hitos registran objetivos entre runs. No es Brasa.", TutorialData.Priority.HIGH)
	_add(entries, PERMANENT_UPGRADES, "MEJORAS PERMANENTES", "Gastá Ceniza para fortalecer futuras runs.")
	_add(entries, EQUIPMENT_SCREEN, "EQUIPO", "Compará arma y armadura. Lo equipado queda fijo durante la run y el loot nunca lo reemplaza solo.")
	_add(entries, ARCHIVE_INTRO, "ARCHIVO DE CENIZA", "Consultá acá tus descubrimientos. NUEVO marca entradas que todavía no revisaste.")
	_add(entries, ARCHIVE_NEW, "NUEVAS ENTRADAS", "La etiqueta NUEVO señala descubrimientos pendientes de revisar.")
	_add(entries, BOSS_REWARD, "RECOMPENSA DE JEFE", "Elegí una recompensa final. Su efecto se aplica antes de mostrar el resultado.")
	_add(entries, FIRST_DEFEAT, "DERROTA", "La run terminó. Results deposita las recompensas mostradas de forma segura.")
	_add(entries, FIRST_VICTORY, "VICTORIA", "La run terminó. Results deposita las recompensas mostradas de forma segura.")
	_add(entries, RUN_XP, "XP DE RUN", "Superar encuentros otorga XP. El nivel y sus mejoras se reinician al terminar la run.")
	_add(entries, RUN_LEVEL_UP, "SUBISTE DE NIVEL", "Elegí una mejora válida para esta run. No es una mejora permanente.", TutorialData.Priority.HIGH)
	_add(entries, BIOME_RULES, "REGIONES", "Cada región cambia la run: Wastes favorece Brasa; Marsh favorece curación.", TutorialData.Priority.CORE)
	_add(entries, COMPANION_COMBAT, "COMPAÑERO", "Actúa automáticamente después de vos y suele seguir tu objetivo. No consume Brasa.", TutorialData.Priority.HIGH)
	_add(entries, ENEMY_AI, "ROLES ENEMIGOS", "Los enemigos cumplen roles distintos. Algunos atacan, protegen o aplican estados.")
	_add(entries, BOSS_PHASE, "NUEVA FASE", "El Jefe cambió su comportamiento. Leé el telegraph antes de actuar.", TutorialData.Priority.HIGH)
	_add(entries, BOSS_SUMMON, "REFUERZOS", "El Jefe invocó enemigos. Podés elegirlos como objetivo; no dan recompensas individuales.", TutorialData.Priority.HIGH)
	_add(entries, TARGET_SELECTION, "ELEGÍ OBJETIVO", "Tocá un enemigo para seleccionarlo. Después elegí ATAQUE o una habilidad.", TutorialData.Priority.CORE)
	_add(entries, STATUS_EFFECTS, "ESTADOS", "Los efectos pueden durar varios turnos. Revisá sus badges para ver duración y acumulaciones.", TutorialData.Priority.HIGH)
	_add(entries, COMPANION_SELECTION, "COMPAÑERO", "Equipalo en el Refugio antes de iniciar una run. También podés dejar el espacio vacío.")
	_add(entries, RUN_RESULTS, "FIN DE LA RUN", "Se reinician nivel, XP, mejoras temporales, Boons, Augments y sinergias. Se conservan Ceniza depositada, mejoras permanentes, equipo, Companion y descubrimientos.", TutorialData.Priority.CORE)
	return entries


static func _add(
	entries: Dictionary[StringName, TutorialData],
	id: StringName,
	title: String,
	body: String,
	priority: TutorialData.Priority = TutorialData.Priority.NORMAL,
) -> void:
	entries[id] = TutorialData.new(id, title, body, priority)

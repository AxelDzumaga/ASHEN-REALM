class_name BoardGenerator
extends RefCounted

## preload (no class_name directo): mismo motivo documentado en RunState —
## este proyecto corre siempre headless por CLI, y BoardGenerator se usa
## desde el arranque de una run, antes de que el editor haya escaneado el
## global class cache para scripts class_name nuevos.
const _RouteBranchData = preload("res://scripts/board/route_branch_data.gd")

const MAX_GENERATION_ATTEMPTS := 16
const NO_SEED := -1
const BRANCH_LENGTH := 4
## Cantidad de forks por run. INITIAL TUNING — un solo fork por run para el
## MVP de MAP3D-HUMAN-004; validar en el próximo Human Playtest antes de
## considerar más de uno.
const FORK_COUNT := 1
## Tipos permitidos dentro de una rama. ELITE y BOSS quedan excluidos del
## contenido de rama en este MVP (alcance aprobado explícitamente).
const BRANCH_ALLOWED_TYPES: Array[int] = [
	BoardTileData.TileType.EMPTY,
	BoardTileData.TileType.COMBAT,
	BoardTileData.TileType.EVENT,
	BoardTileData.TileType.TREASURE,
	BoardTileData.TileType.HEAL,
]
## Tendencias de ruta: pesos relativos por tipo dentro de las 4 casillas de
## la rama. Son tendencias, no plantillas rígidas — el D4 sigue siendo la
## autoridad sobre cuáles de estas casillas realmente se resuelven.
## Números: INITIAL TUNING.
const ROUTE_ARCHETYPES: Dictionary = {
	&"combat": {
		BoardTileData.TileType.COMBAT: 5, BoardTileData.TileType.EVENT: 1,
		BoardTileData.TileType.TREASURE: 2, BoardTileData.TileType.HEAL: 1, BoardTileData.TileType.EMPTY: 1,
	},
	&"recovery": {
		BoardTileData.TileType.COMBAT: 1, BoardTileData.TileType.EVENT: 3,
		BoardTileData.TileType.TREASURE: 1, BoardTileData.TileType.HEAL: 3, BoardTileData.TileType.EMPTY: 2,
	},
	&"treasure": {
		BoardTileData.TileType.COMBAT: 2, BoardTileData.TileType.EVENT: 2,
		BoardTileData.TileType.TREASURE: 4, BoardTileData.TileType.HEAL: 1, BoardTileData.TileType.EMPTY: 1,
	},
	&"balanced": {
		BoardTileData.TileType.COMBAT: 2, BoardTileData.TileType.EVENT: 2,
		BoardTileData.TileType.TREASURE: 2, BoardTileData.TileType.HEAL: 2, BoardTileData.TileType.EMPTY: 2,
	},
}
const ARCHETYPE_IDS: Array[StringName] = [&"combat", &"recovery", &"treasure", &"balanced"]
const FALLBACK_PATTERN: Array[int] = [
	BoardTileData.TileType.COMBAT,
	BoardTileData.TileType.EVENT,
	BoardTileData.TileType.EMPTY,
	BoardTileData.TileType.HEAL,
	BoardTileData.TileType.COMBAT,
	BoardTileData.TileType.TREASURE,
	BoardTileData.TileType.EMPTY,
	BoardTileData.TileType.COMBAT,
	BoardTileData.TileType.EVENT,
	BoardTileData.TileType.EMPTY,
]
const SAFE_FALLBACK_30: Array[int] = [
	BoardTileData.TileType.EMPTY,
	BoardTileData.TileType.COMBAT,
	BoardTileData.TileType.EVENT,
	BoardTileData.TileType.EMPTY,
	BoardTileData.TileType.HEAL,
	BoardTileData.TileType.COMBAT,
	BoardTileData.TileType.TREASURE,
	BoardTileData.TileType.ELITE,
	BoardTileData.TileType.EMPTY,
	BoardTileData.TileType.COMBAT,
	BoardTileData.TileType.EVENT,
	BoardTileData.TileType.EMPTY,
	BoardTileData.TileType.HEAL,
	BoardTileData.TileType.COMBAT,
	BoardTileData.TileType.TREASURE,
	BoardTileData.TileType.EMPTY,
	BoardTileData.TileType.COMBAT,
	BoardTileData.TileType.EVENT,
	BoardTileData.TileType.ELITE,
	BoardTileData.TileType.EMPTY,
	BoardTileData.TileType.COMBAT,
	BoardTileData.TileType.TREASURE,
	BoardTileData.TileType.HEAL,
	BoardTileData.TileType.COMBAT,
	BoardTileData.TileType.EMPTY,
	BoardTileData.TileType.EVENT,
	BoardTileData.TileType.COMBAT,
	BoardTileData.TileType.EMPTY,
	BoardTileData.TileType.COMBAT,
	BoardTileData.TileType.BOSS,
]


static func generate_for_run(run: RunState, biome: BiomeData, requested_seed: int = NO_SEED) -> void:
	var actual_seed: int = requested_seed
	if actual_seed < 0:
		actual_seed = absi(int(Time.get_unix_time_from_system() * 1_000_000.0) ^ int(Time.get_ticks_usec()))
	var rng := RandomNumberGenerator.new()
	rng.seed = actual_seed

	# El fork se decide una sola vez por seed, antes de los reintentos de
	# contenido: su posición no depende del contenido generado, y mantenerlo
	# fijo entre reintentos preserva "mismo seed -> mismos forks".
	var fork_index: int = _choose_fork_index(biome, rng)

	for _attempt in MAX_GENERATION_ATTEMPTS:
		var counts: Dictionary = _choose_counts(biome, rng, fork_index)
		if counts.is_empty():
			continue
		var generated: Array[int] = _build_sequence(biome, counts, rng, fork_index)
		if not generated.is_empty() and validate(generated, biome, fork_index):
			run.board_seed = actual_seed
			run.board_tile_sequence = generated
			run.route_branches = _generate_branches(fork_index, rng)
			return

	push_warning("Board generation used the safe fallback for biome %s." % biome.id)
	run.board_seed = actual_seed
	run.board_tile_sequence = get_fallback(biome.board_length)
	run.route_branches = {}


static func validate(tiles: Array[int], biome: BiomeData, fork_index: int = -1) -> bool:
	if tiles.size() != biome.board_length or tiles.size() < 2:
		return false
	if tiles[0] != BoardTileData.TileType.EMPTY or tiles[-1] != BoardTileData.TileType.BOSS:
		return false
	if fork_index >= 0 and tiles[fork_index] != BoardTileData.TileType.FORK:
		return false

	var counts: Dictionary = {}
	var combat_streak := 0
	var danger_streak := 0
	var previous_type: BoardTileData.TileType = BoardTileData.TileType.EMPTY
	for index in tiles.size():
		var type: BoardTileData.TileType = tiles[index] as BoardTileData.TileType
		# La ventana reservada de un fork (el tile FORK y sus 4 casillas de
		# rama) no representa contenido jugable del spine: su contenido real
		# vive en los overlays de RouteBranchData, así que queda fuera de
		# los cupos/streaks del bioma para no contar contenido fantasma.
		if _is_reserved(index, fork_index):
			previous_type = BoardTileData.TileType.EMPTY
			combat_streak = 0
			danger_streak = 0
			continue
		counts[type] = int(counts.get(type, 0)) + 1
		combat_streak = combat_streak + 1 if type == BoardTileData.TileType.COMBAT else 0
		danger_streak = danger_streak + 1 if _is_dangerous(type) else 0
		if combat_streak > 2 or danger_streak > 2:
			return false
		if type == BoardTileData.TileType.ELITE:
			if index < _elite_start_index(tiles.size()) or index == tiles.size() - 2 or previous_type == BoardTileData.TileType.ELITE:
				return false
		previous_type = type

	return (
		_count_is_valid(counts, BoardTileData.TileType.EMPTY, biome.empty_min, biome.empty_max)
		and _count_is_valid(counts, BoardTileData.TileType.COMBAT, biome.combat_min, biome.combat_max)
		and _count_is_valid(counts, BoardTileData.TileType.EVENT, biome.event_min, biome.event_max)
		and _count_is_valid(counts, BoardTileData.TileType.TREASURE, biome.treasure_min, biome.treasure_max)
		and _count_is_valid(counts, BoardTileData.TileType.HEAL, biome.heal_min, biome.heal_max)
		and _count_is_valid(counts, BoardTileData.TileType.ELITE, biome.elite_min, biome.elite_max)
		and int(counts.get(BoardTileData.TileType.BOSS, 0)) == 1
	)


## Rango de índices "consumidos" por un fork: el propio tile FORK más sus
## BRANCH_LENGTH casillas de rama reservadas.
static func _is_reserved(index: int, fork_index: int) -> bool:
	return fork_index >= 0 and index >= fork_index and index <= fork_index + BRANCH_LENGTH


## Elige, de forma determinística, en qué índice del spine va el fork (o -1
## si el bioma es demasiado corto para alojar uno). Reutiliza el mismo
## criterio de "no demasiado pronto" que ya usa ELITE (_elite_start_index) y
## exige separación suficiente antes del boss para que el MERGE nunca quede
## pegado a él (mismo espíritu que la exclusión de ELITE en el índice
## tiles.size()-2).
static func _choose_fork_index(biome: BiomeData, rng: RandomNumberGenerator) -> int:
	if FORK_COUNT <= 0:
		return -1
	var lower_bound: int = _elite_start_index(biome.board_length)
	var upper_bound: int = biome.board_length - 1 - BRANCH_LENGTH - 3
	if upper_bound < lower_bound:
		return -1
	return rng.randi_range(lower_bound, upper_bound)


static func _generate_branches(fork_index: int, rng: RandomNumberGenerator) -> Dictionary:
	if fork_index < 0:
		return {}
	var archetype_a: StringName = ARCHETYPE_IDS[rng.randi_range(0, ARCHETYPE_IDS.size() - 1)]
	var archetype_b: StringName = ARCHETYPE_IDS[rng.randi_range(0, ARCHETYPE_IDS.size() - 1)]
	if archetype_b == archetype_a:
		archetype_b = ARCHETYPE_IDS[(ARCHETYPE_IDS.find(archetype_a) + 1) % ARCHETYPE_IDS.size()]
	var route_a: Array[int] = _build_branch_content(archetype_a, rng)
	var route_b: Array[int] = _build_branch_content(archetype_b, rng)
	var data := _RouteBranchData.new(fork_index, route_a, route_b, archetype_a, archetype_b)
	return {fork_index: data}


## Genera las BRANCH_LENGTH casillas de una ruta según la tendencia del
## arquetipo, con la misma regla de racha peligrosa (<=2 seguidas) que ya usa
## el spine principal. ELITE/BOSS quedan fuera del pool permitido (MVP).
static func _build_branch_content(archetype: StringName, rng: RandomNumberGenerator) -> Array[int]:
	var weights: Dictionary = ROUTE_ARCHETYPES.get(archetype, ROUTE_ARCHETYPES[&"balanced"])
	var tiles: Array[int] = []
	var danger_streak := 0
	for _index: int in BRANCH_LENGTH:
		var candidates: Array[int] = []
		for type: int in BRANCH_ALLOWED_TYPES:
			if danger_streak >= 2 and _is_dangerous(type):
				continue
			candidates.append(type)
		var chosen: int = _weighted_pick_from_weights(candidates, weights, rng)
		tiles.append(chosen)
		danger_streak = danger_streak + 1 if _is_dangerous(chosen) else 0
	return tiles


static func _weighted_pick_from_weights(candidates: Array[int], weights: Dictionary, rng: RandomNumberGenerator) -> int:
	var total_weight := 0
	for type: int in candidates:
		total_weight += maxi(1, int(weights.get(type, 1)))
	var roll: int = rng.randi_range(1, total_weight)
	for type: int in candidates:
		roll -= maxi(1, int(weights.get(type, 1)))
		if roll <= 0:
			return type
	return candidates[-1]


static func get_fallback(board_length: int) -> Array[int]:
	var safe_length: int = maxi(2, board_length)
	if safe_length == SAFE_FALLBACK_30.size():
		return SAFE_FALLBACK_30.duplicate()
	var fallback: Array[int] = []
	fallback.resize(safe_length)
	fallback[0] = BoardTileData.TileType.EMPTY
	for index: int in range(1, safe_length - 1):
		fallback[index] = FALLBACK_PATTERN[(index - 1) % FALLBACK_PATTERN.size()]
	if safe_length >= 12:
		_place_fallback_elite(fallback, floori(float(safe_length - 1) / 3.0))
	if safe_length >= 20:
		_place_fallback_elite(fallback, floori(float(safe_length - 1) * 2.0 / 3.0))
	fallback[safe_length - 1] = BoardTileData.TileType.BOSS
	return fallback


static func _place_fallback_elite(tiles: Array[int], preferred_index: int) -> void:
	var minimum_index: int = _elite_start_index(tiles.size())
	var maximum_index: int = tiles.size() - 3
	for distance: int in range(0, tiles.size()):
		var candidates: Array[int] = [preferred_index + distance]
		if distance > 0:
			candidates.append(preferred_index - distance)
		for index: int in candidates:
			if index < minimum_index or index > maximum_index:
				continue
			if tiles[index] != BoardTileData.TileType.EMPTY:
				continue
			if tiles[index - 1] == BoardTileData.TileType.ELITE or tiles[index + 1] == BoardTileData.TileType.ELITE:
				continue
			tiles[index] = BoardTileData.TileType.ELITE
			return


static func _choose_counts(biome: BiomeData, rng: RandomNumberGenerator, fork_index: int = -1) -> Dictionary:
	var reserved: int = BRANCH_LENGTH + 1 if fork_index >= 0 else 0
	for _attempt in MAX_GENERATION_ATTEMPTS:
		var counts: Dictionary = {
			BoardTileData.TileType.COMBAT: rng.randi_range(biome.combat_min, biome.combat_max),
			BoardTileData.TileType.EVENT: rng.randi_range(biome.event_min, biome.event_max),
			BoardTileData.TileType.TREASURE: rng.randi_range(biome.treasure_min, biome.treasure_max),
			BoardTileData.TileType.HEAL: rng.randi_range(biome.heal_min, biome.heal_max),
			BoardTileData.TileType.ELITE: rng.randi_range(biome.elite_min, biome.elite_max),
		}
		var occupied: int = 1 + reserved
		for value: int in counts.values():
			occupied += value
		var empty_count: int = biome.board_length - occupied
		if empty_count >= biome.empty_min and empty_count <= biome.empty_max:
			counts[BoardTileData.TileType.EMPTY] = empty_count - 1
			return counts
	return {}


static func _build_sequence(biome: BiomeData, requested_counts: Dictionary, rng: RandomNumberGenerator, fork_index: int = -1) -> Array[int]:
	var tiles: Array[int] = [BoardTileData.TileType.EMPTY]
	var remaining: Dictionary = requested_counts.duplicate()
	for index in range(1, biome.board_length - 1):
		if _is_reserved(index, fork_index):
			# La ventana del fork no consume cupos del bioma: su contenido
			# real vive en los overlays de RouteBranchData (_generate_branches).
			tiles.append(BoardTileData.TileType.FORK if index == fork_index else BoardTileData.TileType.EMPTY)
			continue
		var candidates: Array[int] = []
		for type: int in remaining:
			if int(remaining[type]) > 0 and _is_allowed(type, index, biome.board_length, tiles):
				candidates.append(type)
		if candidates.is_empty():
			return []
		var chosen: int = _weighted_pick(candidates, remaining, biome, rng)
		tiles.append(chosen)
		remaining[chosen] = int(remaining[chosen]) - 1

	for value: int in remaining.values():
		if value != 0:
			return []
	tiles.append(BoardTileData.TileType.BOSS)
	return tiles


static func _is_allowed(type: int, index: int, board_length: int, tiles: Array[int]) -> bool:
	var previous: int = tiles[-1]
	var previous_two: int = tiles[-2] if tiles.size() >= 2 else BoardTileData.TileType.EMPTY
	if type == BoardTileData.TileType.ELITE:
		if index < _elite_start_index(board_length) or index == board_length - 2 or previous == BoardTileData.TileType.ELITE:
			return false
	if type == BoardTileData.TileType.COMBAT and previous == type and previous_two == type:
		return false
	if _is_dangerous(type) and _is_dangerous(previous) and _is_dangerous(previous_two):
		return false
	return true


static func _weighted_pick(candidates: Array[int], remaining: Dictionary, biome: BiomeData, rng: RandomNumberGenerator) -> int:
	var total_weight := 0
	for type in candidates:
		total_weight += maxi(1, _get_weight(type, biome)) * int(remaining[type])
	var roll: int = rng.randi_range(1, total_weight)
	for type in candidates:
		roll -= maxi(1, _get_weight(type, biome)) * int(remaining[type])
		if roll <= 0:
			return type
	return candidates[-1]


static func _get_weight(type: int, biome: BiomeData) -> int:
	match type:
		BoardTileData.TileType.COMBAT:
			return biome.combat_weight
		BoardTileData.TileType.EVENT:
			return biome.event_weight
		BoardTileData.TileType.TREASURE:
			return biome.treasure_weight
		BoardTileData.TileType.HEAL:
			return biome.heal_weight
		BoardTileData.TileType.ELITE:
			return biome.elite_weight
		_:
			return biome.empty_weight


static func _is_dangerous(type: int) -> bool:
	return type == BoardTileData.TileType.COMBAT or type == BoardTileData.TileType.ELITE


static func _elite_start_index(board_length: int) -> int:
	return maxi(1, ceili(float(board_length - 1) * 0.20))


static func _count_is_valid(counts: Dictionary, type: int, minimum: int, maximum: int) -> bool:
	var count: int = int(counts.get(type, 0))
	return count >= minimum and count <= maximum

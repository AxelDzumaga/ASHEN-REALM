class_name RouteBranchData
extends RefCounted

## Contenido determinístico de una bifurcación pre-generada. Ambas rutas son
## overlays explícitos e independientes para el mismo rango de índices del
## spine (fork_index+1 .. fork_index+BRANCH_LENGTH); ninguna es "la spine por
## defecto". Vive en RunState.route_branches y persiste como parte de
## Active Run Persistence (ver to_dictionary()/from_dictionary()) — ya no es
## puramente run-transient-en-memoria como decía el comentario original.

const NONE := 0
const ROUTE_A := 1
const ROUTE_B := 2

## L0 (2026-09-08): 4 -> 6. Con D4 como techo de movimiento, una rama de 4
## casillas se podía cruzar entera en un solo roll (4 exacto) - "true routing"
## era real pero se sentía instantáneo, exactamente el feedback del playtest
## humano ("la ruta B es de pocas casillas"). Con 6, ningún roll único puede
## atravesar la rama completa (max roll 4 < 6): el jugador queda dentro de la
## ruta elegida durante al menos 2 rolls, normalmente ~2-3. Ver BoardGenerator
## (mismo valor, ahora referenciado desde acá) y biome_min/max de EMPTY en
## ashen_wastes.tres/ember_marsh.tres, ajustados -2 para no romper la
## generación (ver comentario en BoardGenerator._choose_counts).
const BRANCH_LENGTH := 6

var fork_index: int = -1
var route_a: Array[int] = []
var route_b: Array[int] = []
var archetype_a: StringName = &""
var archetype_b: StringName = &""


func _init(index: int = -1, tiles_a: Array[int] = [], tiles_b: Array[int] = [], id_a: StringName = &"", id_b: StringName = &"") -> void:
	fork_index = index
	route_a = tiles_a
	route_b = tiles_b
	archetype_a = id_a
	archetype_b = id_b


func merge_index() -> int:
	return fork_index + BRANCH_LENGTH + 1


func to_dictionary() -> Dictionary:
	return {
		"fork_index": fork_index,
		"route_a": route_a.duplicate(),
		"route_b": route_b.duplicate(),
		"archetype_a": String(archetype_a),
		"archetype_b": String(archetype_b),
	}


## Strict, defensive load: any structurally invalid input returns null
## rather than a half-valid branch that could later crash
## BoardTurnController/_effective_tile_type() (out-of-range tile_type
## enum, wrong-length route arrays, etc). Callers (RunState.from_dictionary)
## must drop the whole fork entry when this returns null, never substitute
## a guessed default.
static func from_dictionary(data: Dictionary) -> RouteBranchData:
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var raw_fork_index: Variant = data.get("fork_index", -1)
	if typeof(raw_fork_index) != TYPE_INT and typeof(raw_fork_index) != TYPE_FLOAT:
		return null
	var fork_index_value: int = int(raw_fork_index)
	if fork_index_value < 0:
		return null
	if not _is_valid_route(data.get("route_a", null)) or not _is_valid_route(data.get("route_b", null)):
		return null
	var route_a_value: Array[int] = _read_route(data["route_a"])
	var route_b_value: Array[int] = _read_route(data["route_b"])
	var archetype_a_value: StringName = StringName(String(data.get("archetype_a", "")))
	var archetype_b_value: StringName = StringName(String(data.get("archetype_b", "")))
	return RouteBranchData.new(fork_index_value, route_a_value, route_b_value, archetype_a_value, archetype_b_value)


## True only for an Array of exactly BRANCH_LENGTH entries, each a valid
## BoardTileData.TileType value. _read_route() below must only be called
## once this has already returned true.
static func _is_valid_route(raw: Variant) -> bool:
	if typeof(raw) != TYPE_ARRAY:
		return false
	var array_value: Array = raw
	if array_value.size() != BRANCH_LENGTH:
		return false
	for entry: Variant in array_value:
		if typeof(entry) != TYPE_INT and typeof(entry) != TYPE_FLOAT:
			return false
		var tile_type: int = int(entry)
		if tile_type < BoardTileData.TileType.EMPTY or tile_type > BoardTileData.TileType.FORK:
			return false
	return true


static func _read_route(raw: Array) -> Array[int]:
	var result: Array[int] = []
	for entry: Variant in raw:
		result.append(int(entry))
	return result


## `index` debe caer dentro de (fork_index, fork_index + BRANCH_LENGTH].
func tile_type_for(branch: int, index: int) -> int:
	var local_position: int = index - fork_index - 1
	if local_position < 0 or local_position >= BRANCH_LENGTH:
		return BoardTileData.TileType.EMPTY
	var route: Array[int] = route_a if branch == ROUTE_A else route_b
	return route[local_position]


func archetype_for(branch: int) -> StringName:
	return archetype_a if branch == ROUTE_A else archetype_b


func first_tile_for(branch: int) -> int:
	var route: Array[int] = route_a if branch == ROUTE_A else route_b
	return route[0]


## Partial Information aprobada: identidad + peligro + enfoque + primer nodo.
## Nunca revela las 4 casillas completas.
static func danger_label(archetype: StringName) -> String:
	match archetype:
		&"combat": return "ALTO"
		&"treasure": return "MEDIO"
		&"recovery": return "BAJO"
		_: return "MEDIO"


static func focus_label(archetype: StringName) -> String:
	match archetype:
		&"combat": return "COMBATE"
		&"recovery": return "RECUPERACIÓN"
		&"treasure": return "TESORO"
		_: return "EQUILIBRADA"


static func display_name(archetype: StringName) -> String:
	match archetype:
		&"combat": return "RUTA DE COMBATE"
		&"recovery": return "RUTA DE RECUPERACIÓN"
		&"treasure": return "RUTA DEL TESORO"
		_: return "RUTA EQUILIBRADA"


## L0 (2026-09-08): tier 0/1/2 = EASY/MEDIUM/HARD, mismo mapeo que danger_label()
## pero como índice para VisualTheme.difficulty_color() — antes el panel de
## elección A/B sólo mostraba texto plano, sin ninguna distinción visual entre
## rutas más allá de la letra (feedback humano: "cada cosa debería tener su
## color, su distinción").
static func danger_tier(archetype: StringName) -> int:
	match archetype:
		&"combat": return 2
		&"treasure": return 1
		&"recovery": return 0
		_: return 1


## Ícono ya existente en AshenIcon (ver ashen_icon.gd) por arquetipo — ninguno
## nuevo: reusa los mismos ids que ya se usan para combate/curación/tesoro en
## el resto de la UI. "balanced" no tiene un foco dominante, así que usa el
## ícono neutro de ruta (mismo id que el botón de "Comenzar" del menú principal).
static func icon_id(archetype: StringName) -> StringName:
	match archetype:
		&"combat": return &"combat"
		&"recovery": return &"heal"
		&"treasure": return &"treasure"
		_: return &"route"

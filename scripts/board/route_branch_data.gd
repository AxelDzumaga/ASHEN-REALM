class_name RouteBranchData
extends RefCounted

## Contenido determinístico de una bifurcación pre-generada. Ambas rutas son
## overlays explícitos e independientes para el mismo rango de índices del
## spine (fork_index+1 .. fork_index+BRANCH_LENGTH); ninguna es "la spine por
## defecto". Vive únicamente en RunState (run-transient, no persiste).

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

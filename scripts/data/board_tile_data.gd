class_name BoardTileData
extends Resource

enum TileType {
	EMPTY,
	HEAL,
	BOSS,
	COMBAT,
	EVENT,
	TREASURE,
	ELITE,
	FORK,
}

@export var type: TileType = TileType.EMPTY

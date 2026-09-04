class_name BoardTileResolutionAdapter
extends RefCounted

## Traduce IDs de BoardTileData a intenciones compartidas. Sólo EMPTY y HEAL
## son inline; las demás intenciones conservan las escenas y controladores
## existentes mediante las señales de cada presentación.

const HEAL_AMOUNT := 20

enum Intent {
	EMPTY,
	HEAL,
	COMBAT,
	ELITE,
	EVENT,
	TREASURE,
	BOSS,
}


static func get_intent(tile_type: int) -> Intent:
	match tile_type:
		BoardTileData.TileType.HEAL:
			return Intent.HEAL
		BoardTileData.TileType.COMBAT:
			return Intent.COMBAT
		BoardTileData.TileType.ELITE:
			return Intent.ELITE
		BoardTileData.TileType.EVENT:
			return Intent.EVENT
		BoardTileData.TileType.TREASURE:
			return Intent.TREASURE
		BoardTileData.TileType.BOSS:
			return Intent.BOSS
		_:
			return Intent.EMPTY


static func resolve_inline(intent: Intent, run: RunState) -> Dictionary:
	if run == null:
		return {"resolved": false}
	match intent:
		Intent.EMPTY:
			return {"resolved": true, "intent": intent, "message": "El camino está despejado"}
		Intent.HEAL:
			var recovered: int = run.heal(HEAL_AMOUNT)
			return {"resolved": true, "intent": intent, "recovered": recovered}
		_:
			return {"resolved": false, "intent": intent}

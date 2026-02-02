# ============================================================================
# RoomTemplateInfo
# ============================================================================
## Metadati tipizzati derivati da un RoomTemplateMeta.[br]
## Usati per filtri veloci e per evitare Dictionary runtime.[br]
# ============================================================================

extends RefCounted
class_name RoomTemplateInfo

var key: String

var kind: String
var size_tiles: Vector2i

var requires: Array[Abilities.Ability] = []
var difficulty: int = 1

var connectors: Dictionary[String, bool] = {"N": false, "E": false, "S": false, "W": false}
var tags: Array[String] = []

var base_weight: float = 1.0

static func from_room(key_: String, room: RoomTemplateMeta) -> RoomTemplateInfo:
	var info := RoomTemplateInfo.new()
	info.key = key_

	info.kind = String(room.kind)
	info.size_tiles = room.size_tiles
	info.requires = room.requires.duplicate()
	info.difficulty = int(room.difficulty)
	info.connectors = room.connectors
	info.tags = room.tags
	info.base_weight = room.base_weight

	return info

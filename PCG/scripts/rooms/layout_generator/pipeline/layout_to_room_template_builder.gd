class_name LayoutToRoomTemplateBuilder
extends RefCounted

const SOURCE_ID: int = 0
const ATLAS_COORD: Vector2i = Vector2i(20, 4)
const TILE_SET: TileSet = preload("res://PCG/data/tiles/TileGen.tres")

static func build_from_layout(layout: LayoutValidatorContext) -> RoomTemplateMeta:

	if layout == null:
		return null

	var mask := layout.mask
	var plan := layout.plan

	var room := RoomTemplateMeta.new()

	# -----------------------------------------
	# 1) Dimensione stanza
	# -----------------------------------------
	room.size_tiles = mask.size

	# -----------------------------------------
	# 2) Crea TileMapLayer collisione
	# -----------------------------------------
	var collision := TileMapLayer.new()
	collision.name = "Collision"
	
	collision.tile_set = TILE_SET

	room.add_child(collision)
	room.collision = collision

	# -----------------------------------------
	# 3) Scrittura tile solidi
	# -----------------------------------------
	_write_mask_to_tilemap(mask, collision)

	# -----------------------------------------
	# 4) Connettori
	# -----------------------------------------
	_setup_connectors(room, plan, mask.size)

	return room


static func _write_mask_to_tilemap(
	mask: RoomLayoutMask,
	tilemap: TileMapLayer,
) -> void:

	for y in range(mask.size.y):
		for x in range(mask.size.x):

			if mask.is_empty(x, y):
				continue
				
			tilemap.set_cell(
				Vector2i(x, y),
				SOURCE_ID,
				ATLAS_COORD
			)


static func _setup_connectors(
	room: RoomTemplateMeta,
	plan: ConnectorPlan,
	size: Vector2i
) -> void:

	for dir in Dir4.ORDER:

		if not plan.is_enabled(dir):
			continue

		var connector := RoomConnector.new()
		
		connector.name = "conn_%s" % Dir4.to_label(dir)

		var coord := plan.get_coord(dir)
		var width := plan.get_width(dir)
		
		_set_opening(connector, width, dir)

		var cell_pos := _connector_cell_position(dir, coord, size)

		connector.position = Vector2(cell_pos) * RoomTemplateMeta.TILE_SIZE_PX

		room.add_child(connector)

		room.connectors[Dir4.to_label(dir)] = true


static func _connector_cell_position(
	dir: int,
	coord: int,
	size: Vector2i
) -> Vector2i:

	match dir:
		Dir4.D.N:
			return Vector2i(coord, 0)

		Dir4.D.S:
			return Vector2i(coord, size.y)

		Dir4.D.W:
			return Vector2i(0, coord)

		Dir4.D.E:
			return Vector2i(size.x, coord)

	return Vector2i.ZERO


static func _set_opening(connector: RoomConnector, width: int, dir: int) -> void:
		var half_a: int = width / 2
		var half_b: int = width - half_a
		match dir:
			Dir4.D.N, Dir4.D.S:
				connector.offset_left = half_a
				connector.offset_right = half_b
			Dir4.D.W, Dir4.D.E:
				connector.offset_up = half_a
				connector.offset_down = half_b
				

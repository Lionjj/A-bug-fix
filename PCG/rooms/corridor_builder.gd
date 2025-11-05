extends Node
class_name CorridorBuilder

const AT = {
	"STRAIGHT_H": Vector2i(20, 2),
	"STRAIGHT_V": Vector2i(5, 7),
	"CORNER_NE":  Vector2i(3, 6),
	"CORNER_NW":  Vector2i(1, 6),
	"CORNER_SE":  Vector2i(3, 8),
	"CORNER_SW":  Vector2i(1, 8),
	"EDGE_NE":  Vector2i(7, 6),
	"EDGE_NW":  Vector2i(5, 6),
	"EDGE_SE":  Vector2i(7, 8),
	"EDGE_SW":  Vector2i(5, 8),
	"END_E":      Vector2i(26, 2),
	"END_W":      Vector2i(27, 2),
	"END_S":      Vector2i(28, 2),
	"END_N":      Vector2i(29, 2),
}

const TM_COLLISION := "Collision"   # se usi Map/Collision gli helper lo gestiscono
const TM_CORRIDOR  := "Corridor"
const TILE_SIZE: Vector2i = Vector2i(16, 16)
const TILE_SOURCE_ID := 0
const ALIGN_EPS: int = 1

enum RoundPolicy { ROUND, FLOOR, CEIL }

# ================== API ==================

static func connect_adjacent(
	level: Node2D,
	grid_pos: Dictionary,
	room_tiles: Vector2i,
	tile_size: Vector2i = TILE_SIZE
) -> void:
	var rooms_by_cell: Dictionary = _index_rooms_by_grid(level, room_tiles, tile_size)
	var corridor_l: TileMapLayer = _get_or_create_corridor_layer(level)
	_align_adjacent(corridor_l, rooms_by_cell)
	
	for cell_v in rooms_by_cell.keys():
		var cell: Vector2i = cell_v
		var room: Node2D = rooms_by_cell[cell]
		if room == null: continue
		

		var right_cell := cell + Vector2i(1, 0)
		if rooms_by_cell.has(right_cell):
			_connect_pair_H(level, corridor_l, room, rooms_by_cell[right_cell])

		var down_cell := cell + Vector2i(0, 1)
		if rooms_by_cell.has(down_cell):
			_connect_pair_V(level, corridor_l, room, rooms_by_cell[down_cell])
		

# =============== helpers base ===============

static func _midpoint_cell(a: Vector2i, b: Vector2i, policy: int = RoundPolicy.ROUND) -> Vector2i:
	var mx := (a.x + b.x) * 0.5
	var my := (a.y + b.y) * 0.5
	match policy:
		RoundPolicy.FLOOR: return Vector2i(floori(mx), floori(my))
		RoundPolicy.CEIL: return Vector2i(ceili(mx),  ceili(my))
	
	return Vector2i(roundi(mx), roundi(my))

static func _get_floor(conn: RoomConnector, marker_pos: Vector2i) -> Vector2i:
	return marker_pos + Vector2i(0, conn.offset_down)

static func _get_ceil(conn: RoomConnector, marker_pos: Vector2i) -> Vector2i:
	return marker_pos - Vector2i(0, conn.offset_up + 1)

static func _get_wallL(conn: RoomConnector, marker_pos: Vector2i) -> Vector2i:
	return marker_pos - Vector2i(conn.offset_left + 1, 0)
	
static func _get_wallR(conn: RoomConnector, marker_pos: Vector2i) -> Vector2i:
	return marker_pos + Vector2i(conn.offset_right, 0)

static func _snap_world_to_tile_grid(layer: TileMapLayer, world_pos: Vector2) -> Vector2:
	var ts := layer.tile_set.tile_size
	return Vector2(
		int(round(world_pos.x / ts.x)) * ts.x,
		int(round(world_pos.y / ts.y)) * ts.y
	)

static func _are_adjacent_h(connA:RoomConnector, connB:RoomConnector) -> bool:
	return abs(connA.global_position.x - connB.global_position.x) < 1 

static func _are_adjacent_v(connA:RoomConnector, connB:RoomConnector) -> bool:
	return abs(connA.global_position.y - connB.global_position.y) < 1 

static func _index_rooms_by_grid(level: Node2D, room_tiles: Vector2i, tile_size: Vector2i) -> Dictionary[Vector2i, RoomTemplateMeta]:
	var idx: Dictionary[Vector2i, RoomTemplateMeta] = {}
	var room_px := Vector2(room_tiles.x * tile_size.x, room_tiles.y * tile_size.y)
	for c in level.get_children():
		var n2d :RoomTemplateMeta= c as RoomTemplateMeta
		if n2d == null: continue
		var gp := Vector2i(
			int(floor(n2d.position.x / room_px.x)),
			int(floor(n2d.position.y / room_px.y))
		)
		idx[gp] = n2d
	return idx

static func _find_first_collision_layer(level: Node2D) -> TileMapLayer:
	for c in level.get_children():
		var n2d := c as Node2D
		if n2d == null: continue
		# path diretto
		var coll := n2d.get_node_or_null(NodePath(TM_COLLISION)) as TileMapLayer
		if coll != null: return coll
		# path Map/Collision
		var map := n2d.get_node_or_null(NodePath("Map"))
		if map:
			var coll2 := map.get_node_or_null(NodePath(TM_COLLISION)) as TileMapLayer
			if coll2 != null: return coll2
	return null
	
static func _get_or_create_corridor_layer(level: Node2D) -> TileMapLayer:
	var l :TileMapLayer= level.get_node_or_null(NodePath(TM_CORRIDOR)) as TileMapLayer
	if l != null: return l
	
	l = TileMapLayer.new()
	l.name = TM_CORRIDOR
	var first_collision := _find_first_collision_layer(level)
	if first_collision:
		l.tile_set = first_collision.tile_set  # riusa lo stesso TileSet
	level.add_child(l)
	l.owner = level
	return l

static func _get_connector(room: RoomTemplateMeta, conn: String) -> RoomConnector:
	if not room.connectors[conn]: return
	
	return room.get_node_or_null(room.CONNECTOR_NAMES[conn])

static func _world_to_cell_layer(layer: TileMapLayer, world: Vector2, tile_size: Vector2i) -> Vector2i:
	var local := layer.to_local(world)
	return Vector2i(int(floor(local.x / tile_size.x)), int(floor(local.y / tile_size.y)))

static func _world_to_cell_in(layer: TileMapLayer, world: Vector2) -> Vector2i:
	var ts := layer.tile_set.tile_size
	var local := layer.to_local(world)
	return Vector2i(int(floor(local.x / ts.x)), int(floor(local.y / ts.y)))

static func _collision_layer(room: Node2D) -> TileMapLayer:
	var coll := room.get_node_or_null("Collision") as TileMapLayer
	if coll: return coll
	var map := room.get_node_or_null("Map")
	if map:
		var coll2 := map.get_node_or_null("Collision") as TileMapLayer
		if coll2: return coll2
	# ricerca profonda per sicurezza
	for c in room.get_children():
		var t := c as TileMapLayer
		if t and t.name == "Collision":
			return t
	return null

# centro mondo della colonna 'col' nel layer (usiamo la riga 0, ci serve solo la X)
static func _col_world_center(layer: TileMapLayer, col: int) -> Vector2:
	var ts := layer.tile_set.tile_size
	var local := layer.map_to_local(Vector2i(col, 0)) + Vector2(ts.x * 0.5, ts.y * 0.5)
	return layer.to_global(local)

static func _marker_cell(layer: TileMapLayer, node: Node2D) -> Vector2i:
	return layer.local_to_map(layer.to_local(node.global_position))
# delta in celle (locali al layer) → delta in world
static func _cells_to_world_delta(layer: TileMapLayer, delta_cells: Vector2i) -> Vector2:
	var a := layer.to_global(layer.map_to_local(Vector2i.ZERO))
	var b := layer.to_global(layer.map_to_local(delta_cells))
	return b - a

# =============== collegamenti ===============
static func _connect_pair_H(level: Node2D, corridor_l: TileMapLayer, roomL: RoomTemplateMeta, roomR: RoomTemplateMeta) -> void:
	# stop se i template non hanno connettori E/W
	if not (roomL.connectors["E"] and roomR.connectors["W"]): return
	
	var mL: RoomConnector = _get_connector(roomL, "E")
	var mR: RoomConnector = _get_connector(roomR, "W")
	
	
	if mL == null or mR == null: return

	# Celle corridoio dei marker (per X estremi)
	var mL_pos : Vector2i = _world_to_cell_layer(corridor_l, mL.global_position, corridor_l.tile_set.tile_size)
	var mR_pos : Vector2i = _world_to_cell_layer(corridor_l, mR.global_position, corridor_l.tile_set.tile_size)
	
	var floor_mL : Vector2i = _get_floor(mL, mL_pos)
	var ceil_mL : Vector2i = _get_ceil(mL, mL_pos)
	
	var floor_mR : Vector2i = _get_floor(mR, mR_pos)
	var ceil_mR : Vector2i = _get_ceil(mR, mR_pos)

	# Collision locali (per Y dei varchi)
	var collL :TileMapLayer= _collision_layer(roomL)
	var collR :TileMapLayer= _collision_layer(roomR)
	if collL == null or collR == null: return

	var a_local := _world_to_cell_in(collL, mL.global_position) # usa .y
	var b_local := _world_to_cell_in(collR, mR.global_position) # usa .y
	var yL := a_local.y
	var yR := b_local.y
	
	var is_ceil_mL_above: bool = ceil_mL.y <= ceil_mR.y
	var is_floor_mL_above: bool = floor_mL.y <= floor_mR.y
	
	var mid_cell: Vector2i = _midpoint_cell(mL_pos, mR_pos, RoundPolicy.CEIL)
	var y_dist_floor: int = abs(floor_mL.y - floor_mR.y)
	var y_dist_ceil: int = abs(ceil_mL.y - ceil_mR.y)
		
	# Scava i varchi ai due bordi
	
	_carve_opening_edge_layer(roomL, collL, "E", yL)
	_carve_opening_edge_layer(roomR, collR, "W", yR)
	
	if _are_adjacent_h(mL, mR):
		 
		#_align_adjacent_H(corridor_l, roomL, roomR, mL, mR) if is_ceil_mL_above else _align_adjacent_H(corridor_l, roomR, roomL, mR, mL)
		return
	
	#corridor_l.set_cell(mid_cell, TILE_SOURCE_ID, AT["STRAIGHT_H"])
	
	var end_points_mL: Dictionary[String, int]
	var end_points_mR: Dictionary[String, int]
	
	if y_dist_floor <= ALIGN_EPS && y_dist_ceil <= ALIGN_EPS:
		_draw_horizzontal_S_corridor(corridor_l, mR, mid_cell, y_dist_floor)
		_draw_horizzontal_S_corridor(corridor_l, mL, mid_cell, y_dist_ceil)
		## pavimento
		#var temp1 = range(min(floor_mL.y, floor_mR.y), max(floor_mL.y, floor_mR.y))
		##soffitto
		#var temp2 = range(min(ceil_mL.y, ceil_mR.y), max(ceil_mL.y, ceil_mR.y))
		#_fill_v_straigth_layer(corridor_l, temp1, temp2, mid_cell.x, mid_cell.x)
		return
	else:

		end_points_mL = _draw_horizzontal_L_corridor(corridor_l, mL, mL_pos, floor_mL, ceil_mL, is_floor_mL_above, is_ceil_mL_above, mid_cell, mR.offset_down, mR.offset_up)
		end_points_mR = _draw_horizzontal_L_corridor(corridor_l, mR, mR_pos, floor_mR, ceil_mR, !is_floor_mL_above, !is_ceil_mL_above, mid_cell, mL.offset_down, mL.offset_up)
		
		
	var rangeWL: Array
	var rangeWR: Array
	var x0: int
	var x1: int
	
	if is_floor_mL_above:
		rangeWL = range(floor_mL.y + 1, floor_mR.y)
		x0 = end_points_mL["END_FLOOR"]
	else:
		rangeWR = range(floor_mR.y + 1, floor_mL.y)
		x1 = end_points_mR["END_FLOOR"]
	
	_fill_v_straigth_layer(corridor_l, rangeWL, rangeWR, x0, x1, TileSetAtlasSource.TRANSFORM_FLIP_H)
	
	if is_ceil_mL_above:
		rangeWR = range(ceil_mL.y + 1, ceil_mR.y)
		x1 = end_points_mL["END_CEIL"]
	else:
		rangeWL = range(ceil_mR.y + 1, ceil_mL.y)
		x0 = end_points_mR["END_CEIL"]
	
	_fill_v_straigth_layer(corridor_l, rangeWL, rangeWR, x0, x1, TileSetAtlasSource.TRANSFORM_FLIP_H)

# Disegna V con eventuale gomito se le X non coincidono
static func _connect_pair_V(level: Node2D, corridor_l: TileMapLayer, roomTop: RoomTemplateMeta, roomBottom: RoomTemplateMeta) -> void:
	# stop se i template non hanno connettori N/S
	if not (roomTop.connectors["S"] and roomBottom.connectors["N"]): return
	
	var mT: RoomConnector = _get_connector(roomTop, "S")
	var mB: RoomConnector = _get_connector(roomBottom, "N")
	
	
	if mT == null or mB == null: return
	
	var mT_pos : Vector2i = _world_to_cell_layer(corridor_l, mT.global_position, corridor_l.tile_set.tile_size)
	var mB_pos : Vector2i = _world_to_cell_layer(corridor_l, mB.global_position, corridor_l.tile_set.tile_size)
	
	var wallL_mT : Vector2i = _get_wallL(mT, mT_pos)
	var wallR_mT : Vector2i = _get_wallR(mT, mT_pos)
	
	var wallL_mB : Vector2i = _get_wallL(mB, mB_pos)
	var wallR_mB : Vector2i = _get_wallR(mB, mB_pos)

	# Collision locali (per X dei varchi)
	var collT : TileMapLayer = _collision_layer(roomTop)
	var collB : TileMapLayer = _collision_layer(roomBottom)
	if collT == null or collB == null: return

	var a_local := _world_to_cell_in(collT, mT.global_position) # usa .x
	var b_local := _world_to_cell_in(collB, mB.global_position) # usa .x
	var xT := a_local.x
	var xB := b_local.x
	
	var is_wL_mT_left : bool = wallL_mT.x <= wallL_mB.x
	var is_wR_mT_left : bool = wallR_mT.x <= wallR_mB.x
	
	var mid_cell: Vector2i = _midpoint_cell(Vector2i(mT_pos.x, mT_pos.y), Vector2i(mB_pos.x, mB_pos.y), RoundPolicy.CEIL)
	var x_dist_wL: int = abs(wallL_mT.x - wallL_mB.x)
	var x_dist_wR: int = abs(wallR_mT.x - wallR_mB.x)

	# Scava varchi ai due bordi
	_carve_opening_edge_layer(roomTop, collT, "S", xT)
	_carve_opening_edge_layer(roomBottom, collB ,"N", xB)
	
	if _are_adjacent_v(mT, mB): 
		#_align_adjacent_V(corridor_l, roomTop, roomBottom, mT, mB) if is_wL_mT_left else _align_adjacent_V(corridor_l, roomBottom, roomTop, mB, mT)
		return
	
	var end_points_mT: Dictionary[String, int]
	var end_points_mB: Dictionary[String, int]
	
	if x_dist_wL <= ALIGN_EPS && x_dist_wR <= ALIGN_EPS:
		_draw_vertical_S_corridor(corridor_l, mT, mT_pos, wallL_mT, wallR_mT, is_wL_mT_left, is_wR_mT_left, mid_cell, x_dist_wL)
		_draw_vertical_S_corridor(corridor_l, mB, mB_pos, wallL_mB, wallR_mB, !is_wL_mT_left, !is_wR_mT_left, mid_cell, x_dist_wR)
		
		return
	else:
		end_points_mT = _draw_vertical_L_corridor(corridor_l, mT, mT_pos, wallL_mT, wallR_mT, is_wL_mT_left, is_wR_mT_left, mid_cell, mB.offset_left, mB.offset_right)
		end_points_mB = _draw_vertical_L_corridor(corridor_l, mB, mB_pos, wallL_mB, wallR_mB, !is_wL_mT_left, !is_wR_mT_left, mid_cell, mT.offset_left, mT.offset_right)

	var rangeC: Array
	var rangeF: Array
	var y0: int
	var y1: int
	
	if is_wL_mT_left:
		rangeC = range(wallL_mT.x + 1, wallL_mB.x)
		y0 = end_points_mT["END_WL"]
	else:
		rangeF = range(wallL_mB.x + 1, wallL_mT.x) 
		y1 = end_points_mB["END_WL"]
			
	#_fill_h_straigth_layer(corridor_l, rangeF, rangeC, y0, y1)
	
	if is_wR_mT_left:
		rangeF = range(wallR_mT.x + 1, wallR_mB.x)
		y1 = end_points_mT["END_WR"]
	else:
		rangeC = range(wallR_mB.x + 1, wallR_mT.x)
		y0 = end_points_mB["END_WR"]
	
	_fill_h_straigth_layer(corridor_l, rangeF, rangeC, y0, y1, TileSetAtlasSource.TRANSFORM_FLIP_V)

# =============== carving aperture ===============

static func _carve_opening_edge_layer(room: RoomTemplateMeta, coll: TileMapLayer, dir: String, coord: int) -> void:
	if coll == null: return

	var size_tiles :Vector2i
	var meta :RoomTemplateMeta = room as RoomTemplateMeta
	if not meta: return
	
	size_tiles = meta.size_tiles
	
	match dir:
		"N":  # coord = X del varco
			var conn : RoomConnector = _get_connector(room, "N")
			if not conn: return
			
			var y_edge := 0
			for dx in range(-conn.offset_left, conn.offset_right):
				var xt :int= clamp(coord + dx, 0, size_tiles.x - 1)
				coll.set_cell(Vector2i(xt, y_edge), -1)
				var inner_y :int= clamp(y_edge + 1, 0, size_tiles.y - 1)
				# Finche ci sono celle verticali eliminale (verso giù)
				while coll.get_cell_tile_data(Vector2i(xt, inner_y)) != null:
					coll.set_cell(Vector2i(xt, inner_y), -1)
					inner_y+=1
			
			if coll.get_cell_tile_data(Vector2i((coord - 1) + -conn.offset_left, y_edge + 1)) == null:
				coll.set_cell(Vector2i((coord - 1) + -conn.offset_left, y_edge), TILE_SOURCE_ID, AT["EDGE_SE"])
			else:
				coll.set_cell(Vector2i((coord - 1) + -conn.offset_left, y_edge), TILE_SOURCE_ID, AT["STRAIGHT_V"], TileSetAtlasSource.TRANSFORM_FLIP_H)
			
			if coll.get_cell_tile_data(Vector2i(coord + conn.offset_right, y_edge + 1)) == null:
				coll.set_cell(Vector2i(coord + conn.offset_right, y_edge), TILE_SOURCE_ID, AT["EDGE_SW"])
			else:
				coll.set_cell(Vector2i(coord + conn.offset_right, y_edge), TILE_SOURCE_ID, AT["STRAIGHT_V"])
			
			return

		"S":  # coord = X del varco
			var conn : RoomConnector = _get_connector(room, "S")
			if not conn: return
			
			var y_edge := size_tiles.y - 1
			for dx in range(-conn.offset_left, conn.offset_right):
				var xt :int= clamp(coord + dx, 0, size_tiles.x - 1)
				coll.set_cell(Vector2i(xt, y_edge), -1)
				# Finche ci sono celle verticali eliminale (verso su)
				var inner_y :int= clamp(y_edge - 1, 0, size_tiles.y - 1)
				while coll.get_cell_tile_data(Vector2i(xt, inner_y)) != null:
					coll.set_cell(Vector2i(xt, inner_y), -1)
					inner_y -= 1

			if coll.get_cell_tile_data(Vector2i(coord - conn.offset_left -1, y_edge - 1)) == null:
				coll.set_cell(Vector2i(coord - conn.offset_left - 1, y_edge), TILE_SOURCE_ID, AT["EDGE_NE"])
			else:
				coll.set_cell(Vector2i(coord - conn.offset_left -1, y_edge), TILE_SOURCE_ID, AT["STRAIGHT_V"], TileSetAtlasSource.TRANSFORM_FLIP_H)
			
			if coll.get_cell_tile_data(Vector2i(coord + conn.offset_right, y_edge - 1)) == null:
				coll.set_cell(Vector2i(coord + conn.offset_right, y_edge), TILE_SOURCE_ID, AT["EDGE_NW"])
			else: 
				coll.set_cell(Vector2i(coord + conn.offset_right, y_edge), TILE_SOURCE_ID, AT["STRAIGHT_V"])
			return

		"W": # coord = y del varco
			var conn : RoomConnector = _get_connector(room, "W")
			if not conn: return
			
			var x_edge := 0
			for dy in range(-conn.offset_up, conn.offset_down):
				var yt :int= clamp(coord + dy, 0, size_tiles.y - 1)
				if yt < 0 or yt >= size_tiles.y: continue
				coll.set_cell(Vector2i(x_edge, yt), -1)  # cancella bordo
				
				var inner_x : int = clamp(x_edge + 1, 0, size_tiles.x - 1)
				while coll.get_cell_tile_data(Vector2i(inner_x, yt)) != null:
					coll.set_cell(Vector2i(inner_x, yt), -1) # allarga verso l'interno
					inner_x+=1
			
			if coll.get_cell_tile_data(Vector2i(x_edge + 1, coord - conn.offset_up - 1)) == null:
				coll.set_cell(Vector2i(x_edge, coord - conn.offset_up -1), TILE_SOURCE_ID, AT["EDGE_SE"])
			else:
				coll.set_cell(Vector2i(x_edge, coord - conn.offset_up -1), TILE_SOURCE_ID, AT["STRAIGHT_H"], TileSetAtlasSource.TRANSFORM_FLIP_V)
			
			if coll.get_cell_tile_data(Vector2i(x_edge + 1, coord + conn.offset_down)) == null:
				coll.set_cell(Vector2i(x_edge, coord + conn.offset_down), TILE_SOURCE_ID, AT["EDGE_NE"])
			else:
				coll.set_cell(Vector2i(x_edge, coord + conn.offset_down), TILE_SOURCE_ID, AT["STRAIGHT_H"])
			
		"E":  # coord = y del varco
			var conn : RoomConnector = _get_connector(room, "E")
			if not conn: return
			
			var x_edge := size_tiles.x - 1
			for dy in range(-conn.offset_up, conn.offset_down):
				var yt := coord + dy
				if yt < 0 or yt >= size_tiles.y: continue
				coll.set_cell(Vector2i(x_edge, yt), -1)  # cancella bordo
				var inner_x : int = clamp(x_edge + -1, 0, size_tiles.x - 1)
				while coll.get_cell_tile_data(Vector2i(inner_x, yt)) != null:
					coll.set_cell(Vector2i(inner_x, yt), -1) # allarga verso l'interno
					inner_x-=1
					
			if coll.get_cell_tile_data(Vector2i(x_edge - 1, coord - conn.offset_up - 1)) == null:
				coll.set_cell(Vector2i(x_edge, coord - conn.offset_up - 1), TILE_SOURCE_ID, AT["EDGE_SW"])
			else:
				coll.set_cell(Vector2i(x_edge, coord - conn.offset_up - 1), TILE_SOURCE_ID, AT["STRAIGHT_H"], TileSetAtlasSource.TRANSFORM_FLIP_V )
			
			if coll.get_cell_tile_data(Vector2i(x_edge - 1, coord + conn.offset_down)) == null:
				coll.set_cell(Vector2i(x_edge, coord + conn.offset_down), TILE_SOURCE_ID, AT["EDGE_NW"])
			else:
				coll.set_cell(Vector2i(x_edge, coord + conn.offset_down), TILE_SOURCE_ID, AT["STRAIGHT_H"])

#layer: TileMapLayer, conn: RoomConnector, marker_pos: Vector2i, wL: Vector2i, wR: Vector2i, is_conn_left: bool, mid_cell: Vector2i, x_dist: int

# =============== drawing utils ===============
#static func _draw_horizzontal_L_corridor(layer: TileMapLayer, conn: RoomConnector, marker_pos: Vector2i, floor: Vector2i, ceil: Vector2i, is_conn_above: bool, mid_cell: Vector2i ,sx_lim: int, dx_lim:int) -> Dictionary[String, int]:
	#var out: Dictionary[String, int]
	#
	#var range_floor: Array
	#var range_ceil: Array
	#
	#var angle0: Vector2i
	#var angle1: Vector2i
	#var x0: int
	#var x1: int
#
	#match conn.axis:
		#"W":
			#if is_conn_above:
				#x0 = (mid_cell.x + min(conn.offset_down, dx_lim)) + 1 
				#x1 = (mid_cell.x - min(conn.offset_up, sx_lim)) - 1
				#
				#angle0 = AT["EDGE_NW"]
				#angle1 = AT["CORNER_NW"]
				#
				#range_floor = range(x0 + 1, floor.x)
				#range_ceil = range(x1 + 1, ceil.x)
			#else:
				#x0 = (mid_cell.x - min(conn.offset_down, sx_lim)) - 1
				#x1 = (mid_cell.x + min(conn.offset_up, dx_lim))  + 1
				#
				#angle0 = AT["CORNER_SW"]
				#angle1 = AT["EDGE_SW"]
				#
				#range_floor = range(x0 + 1, floor.x)
				#range_ceil = range(x1 + 1, ceil.x)
				#
		#"E":
			#if is_conn_above:
				#x0 = (mid_cell.x - min(conn.offset_down, sx_lim)) - 1
				#x1 = (mid_cell.x + min(conn.offset_up, dx_lim)) + 1
				#
				#angle0 = AT["EDGE_NE"]
				#angle1 = AT["CORNER_NE"]
				#
				#range_floor = range(floor.x, x0)
				#range_ceil = range(ceil.x, x1)
#
			#else:
				#x0 = (mid_cell.x + min(conn.offset_down, dx_lim)) + 1
				#x1 = (mid_cell.x - min(conn.offset_up, sx_lim)) - 1
				#
				#angle0 = AT["CORNER_SE"]
				#angle1 = AT["EDGE_SE"]
				#
				#range_floor = range(floor.x, x0)
				#range_ceil = range(ceil.x, x1)
	#
	#_fill_h_straigth_layer(layer, range_floor, range_ceil, floor.y, ceil.y)
		#
	#layer.set_cell(Vector2i(x0, floor.y), TILE_SOURCE_ID, angle0)
	#layer.set_cell(Vector2i(x1, ceil.y), TILE_SOURCE_ID, angle1)
	#
	#out["END_CEIL"] = x1
	#out["END_FLOOR"] = x0
	#
	#return out
	##corridor_l.set_cell(Vector2i( mid_cell.x - mL.offset_down, y_floorL.y + mL.offset_down), TILE_SOURCE_ID, AT["CORNER_NE"])

# =============== disegna corridoi ===============

static func _draw_horizzontal_L_corridor(layer: TileMapLayer, conn: RoomConnector, marker_pos: Vector2i, floor: Vector2i, ceil: Vector2i, is_floor_above: bool , is_ceil_above: bool, mid_cell: Vector2i ,sx_lim: int, dx_lim:int) -> Dictionary[String, int]:
	var out: Dictionary[String, int]
	
	var range_floor: Array
	var range_ceil: Array
	
	var angle0: Vector2i
	var angle1: Vector2i
	var x0: int
	var x1: int

	match conn.axis:
		"W":
			if is_floor_above:
				
				x0 = (mid_cell.x + min(conn.offset_down, dx_lim)) + 1 
				angle0 = AT["EDGE_NW"]
				range_floor = range(min(x0 + 1, floor.x), max(x0 + 1, floor.x))
			else:
				x0 = (mid_cell.x - min(conn.offset_down, sx_lim)) - 1
				angle0 = AT["CORNER_SW"]
				range_floor = range(min(x0 + 1, floor.x), max(x0 + 1, floor.x)) 
				
			if is_ceil_above:
				x1 = (mid_cell.x - min(conn.offset_up, sx_lim)) - 1
				angle1 = AT["CORNER_NW"]
				range_ceil = range(min(x1 + 1, ceil.x), max(x1 + 1, ceil.x))
			else:
				x1 = (mid_cell.x + min(conn.offset_up, dx_lim))  + 1
				angle1 = AT["EDGE_SW"]
				range_ceil = range(min(x1 + 1, ceil.x), max(x1 + 1, ceil.x))
				
		"E":
			if is_floor_above:
				x0 = (mid_cell.x - min(conn.offset_down, sx_lim)) - 1
				angle0 = AT["EDGE_NE"]
				range_floor = range(min(floor.x, x0), max(floor.x, x0))
			else:
				x0 = (mid_cell.x + min(conn.offset_down, dx_lim)) + 1
				angle0 = AT["CORNER_SE"]
				range_floor = range(min(floor.x, x0), max(floor.x, x0))
			
			if is_ceil_above:
				x1 = (mid_cell.x + min(conn.offset_up, dx_lim)) + 1
				angle1 = AT["CORNER_NE"]
				range_ceil = range(min(ceil.x, x1), max(ceil.x, x1))
			else:
				x1 = (mid_cell.x - min(conn.offset_up, sx_lim)) - 1
				angle1 = AT["EDGE_SE"]
				range_ceil = range(min(ceil.x, x1), max(ceil.x, x1))
	
	_fill_h_straigth_layer(layer, range_floor, range_ceil, floor.y, ceil.y)
		
	layer.set_cell(Vector2i(x0, floor.y), TILE_SOURCE_ID, angle0)
	layer.set_cell(Vector2i(x1, ceil.y), TILE_SOURCE_ID, angle1)
	
	out["END_CEIL"] = x1
	out["END_FLOOR"] = x0
	
	return out
	#corridor_l.set_cell(Vector2i( mid_cell.x - mL.offset_down, y_floorL.y + mL.offset_down), TILE_SOURCE_ID, AT["CORNER_NE"])

static func _draw_vertical_L_corridor(layer: TileMapLayer, conn: RoomConnector, marker_pos: Vector2i, wL: Vector2i, wR: Vector2i, is_wL_left: bool, is_wR_left: bool, mid_cell: Vector2i, inf_lim: int, sup_lim:int) -> Dictionary[String, int]:
	var out: Dictionary[String, int]
	
	var range_wL: Array
	var range_wR: Array
	
	var angle0: Vector2i
	var angle1: Vector2i
	var y0: int
	var y1: int

	match conn.axis:
		"N":
			if is_wL_left:
				y0 = (mid_cell.y + min(conn.offset_left, sup_lim)) + 1 
				angle0 = AT["EDGE_NW"]
				range_wL = range(min(wL.y, y0), max(wL.y, y0)) 
			else:
				y0 = (mid_cell.y - min(conn.offset_left, inf_lim)) - 1
				angle0 = AT["CORNER_NE"]
				range_wL = range(min(y0 + 1, wL.y), max(y0 + 1, wL.y))
			
			if is_wR_left:
				y1 = (mid_cell.y - min(conn.offset_right, inf_lim)) - 1
				angle1 = AT["CORNER_NW"]
				range_wR = range(min(wR.y, y1), max(wR.y, y1))
			else:
				y1 = (mid_cell.y + min(conn.offset_right, sup_lim))  + 1
				angle1 = AT["EDGE_NE"]
				range_wR = range(min(y1 + 1, wR.y), max(y1 + 1, wR.y))
				
			#if is_conn_left:
				#y0 = (mid_cell.y + min(conn.offset_left, sup_lim)) + 1 
				#y1 = (mid_cell.y - min(conn.offset_right, inf_lim)) - 1
				#
				#angle0 = AT["EDGE_NW"]
				#angle1 = AT["CORNER_NW"]
				#
				#range_wL = range(wL.y - 1, y0)
				#range_wR = range(wR.y - 1, y1)
			#else:
				#y0 = (mid_cell.y - min(conn.offset_left, inf_lim)) - 1
				#y1 = (mid_cell.y + min(conn.offset_right, sup_lim))  + 1
				#
				#angle0 = AT["CORNER_SW"]
				#angle1 = AT["EDGE_SW"]
				#
				#range_wL = range(y0 + 1, wL.y)
				#range_wR = range(y1 + 1, wR.y)
				
		"S":
			if is_wL_left:
				y0 = (mid_cell.y - min(conn.offset_left, inf_lim)) - 1
				angle0 = AT["EDGE_SW"]
				range_wL = range(min(wL.y, y0), max(wL.y, y0))
			else:
				y0 = (mid_cell.y + min(conn.offset_left, sup_lim)) + 1
				angle0 = AT["CORNER_SE"]
				range_wL = range(min(y0, wL.y), max(y0, wL.y))
			
			if is_wR_left:
				y1 = (mid_cell.y + min(conn.offset_right, sup_lim)) + 1
				angle1 = AT["CORNER_SW"]
				range_wR = range(min(wR.y, y1), max(wR.y, y1))
			else:
				y1 = (mid_cell.y - min(conn.offset_right, inf_lim)) - 1
				angle1 = AT["EDGE_SE"]
				range_wR = range(min(y1, wR.y), max(y1, wR.y))
				
			#if is_conn_left:
				#y0 = (mid_cell.y - min(conn.offset_left, inf_lim)) - 1
				#y1 = (mid_cell.y + min(conn.offset_right, sup_lim)) + 1
				#
				#angle0 = AT["EDGE_NE"]
				#angle1 = AT["CORNER_NE"]
				#
				#range_wL = range(wL.y, y0)
				#range_wR = range(wR.y, y1)
#
			#else:
				#y0 = (mid_cell.y + min(conn.offset_left, sup_lim)) + 1
				#y1 = (mid_cell.y - min(conn.offset_right, inf_lim)) - 1
				#
				#angle0 = AT["CORNER_SE"]
				#angle1 = AT["EDGE_SE"]
				#
				#range_wL = range(y0, wL.y)
				#range_wR = range(y1, wR.y)
	
	_fill_v_straigth_layer(layer, range_wL, range_wR, wR.x, wL.x, TileSetAtlasSource.TRANSFORM_FLIP_V)
		
	layer.set_cell(Vector2i(wR.x, y0), TILE_SOURCE_ID, angle0)
	layer.set_cell(Vector2i(wL.x, y1), TILE_SOURCE_ID, angle1)
	
	out["END_WL"] = y0
	out["END_WR"] = y1
	
	return out
	#corridor_l.set_cell(Vector2i( mid_cell.x - mL.offset_down, y_floorL.y + mL.offset_down), TILE_SOURCE_ID, AT["CORNER_NE"])

static func _draw_horizzontal_S_corridor(layer: TileMapLayer, conn: RoomConnector, mid_cell: Vector2i, y_dist: int):
		var marker_pos: Vector2i = _world_to_cell_layer(layer, conn.global_position, layer.tile_set.tile_size)
		
		var floor: Vector2i = marker_pos + Vector2i(0, conn.offset_down)
		var ceil: Vector2i = marker_pos - Vector2i(0, conn.offset_up + 1)
		
		var range: Array
		
		var angle0: Vector2i
		var angle1: Vector2i
		
		match conn.axis:
			"W":
				var add: int = 0
				if y_dist != 0:
					add = 1
					if marker_pos.y <= mid_cell.y:
						angle0 = AT["EDGE_NE"]
						angle1 = AT["CORNER_NE"]
						
						layer.set_cell(Vector2i(mid_cell.x, floor.y), TILE_SOURCE_ID, AT["EDGE_NW"])
						layer.set_cell(Vector2i(mid_cell.x, ceil.y), TILE_SOURCE_ID, AT["CORNER_NW"])
						
					else:
						angle0 = AT["CORNER_SE"]
						angle1 = AT["EDGE_SE"]
						
						layer.set_cell(Vector2i(mid_cell.x, floor.y), TILE_SOURCE_ID, AT["CORNER_NW"])
						layer.set_cell(Vector2i(mid_cell.x, ceil.y), TILE_SOURCE_ID, AT["EDGE_NW"])
				
				range = range(mid_cell.x + add, marker_pos.x) 
				
			"E":
				if y_dist != 0:
				
					if marker_pos.y <= mid_cell.y:
						angle0 = AT["EDGE_SE"]
						angle1 = AT["CORNER_SE"]
						
						layer.set_cell(Vector2i(mid_cell.x, floor.y), TILE_SOURCE_ID, AT["CORNER_SE"])
						layer.set_cell(Vector2i(mid_cell.x, ceil.y), TILE_SOURCE_ID, AT["EDGE_SE"])
					else:
						angle0 = AT["CORNER_NE"	]
						angle1 = AT["EDGE_NE"]
						
						layer.set_cell(Vector2i(mid_cell.x, floor.y), TILE_SOURCE_ID, AT["CORNER_NE"])
						layer.set_cell(Vector2i(mid_cell.x, ceil.y), TILE_SOURCE_ID, AT["EDGE_NE"])
				
				range = range(marker_pos.x, mid_cell.x)
			
		
		_fill_h_straigth_layer(layer, range, range, floor.y, ceil.y)

static func _draw_vertical_S_corridor(layer: TileMapLayer, conn: RoomConnector, marker_pos: Vector2i, wL: Vector2i, wR: Vector2i, is_wL_left: bool, is_wR_left: bool, mid_cell: Vector2i, x_dist: int) -> void:
	var range: Array
		
	var angle0: Vector2i
	var angle1: Vector2i
		
	match conn.axis:
		"N":
			var add: int = 0
			if x_dist != 0:
				add = 1
				angle0 = AT["CORNER_NW"] if is_wL_left else AT["EDGE_NE"]
				angle1 = AT["EDGE_NW"] if is_wR_left else AT["CORNER_NE"]
				
			range = range(mid_cell.y + add, marker_pos.y) 
				
		"S":
			if x_dist != 0:
				angle0 = AT["CORNER_SW"] if is_wL_left else AT["EDGE_SE"]
				angle1 = AT["EDGE_SW"] if is_wR_left else AT["CORNER_SE"]
				
			range = range(marker_pos.y, mid_cell.y)
	
	layer.set_cell(Vector2i(wL.x, mid_cell.y), TILE_SOURCE_ID, angle0)
	layer.set_cell(Vector2i(wR.x, mid_cell.y), TILE_SOURCE_ID, angle1)
			
	_fill_v_straigth_layer(layer, range, range, wL.x, wR.x)
	
static func _fill_v_straigth_layer(layer: TileMapLayer, range_L_wall: Array, range_R_wall: Array, wall_L_x: int, wall_R_x: int, atlas_transform = TileSetAtlasSource.TRANSFORM_FLIP_H, tranform: bool = false) -> void:
	
	var revers = TileSetAtlasSource.TRANSFORM_FLIP_V if atlas_transform == TileSetAtlasSource.TRANSFORM_FLIP_H else TileSetAtlasSource.TRANSFORM_FLIP_H
	
	# muro sinistro: atlas "normale"
	for y in range_L_wall:
		layer.set_cell(Vector2i(wall_L_x, y), TILE_SOURCE_ID, AT["STRAIGHT_H"], TileSetAtlasSource.TRANSFORM_TRANSPOSE | atlas_transform)

	for y in range_R_wall:
		layer.set_cell(Vector2i(wall_R_x, y), TILE_SOURCE_ID, AT["STRAIGHT_H"], TileSetAtlasSource.TRANSFORM_TRANSPOSE | revers )

static func _fill_h_straigth_layer(layer: TileMapLayer, range_floor: Array, range_ceil: Array, floor_y: int, ceil_y: int,  atlas_transform = 0, tranform: bool = false) -> void:
	
	var revers = TileSetAtlasSource.TRANSFORM_FLIP_V if atlas_transform == 0 else 0
	
	# pavimento: atlas "normale"
	for x in range_floor:
		layer.set_cell(Vector2i(x, floor_y), TILE_SOURCE_ID, AT["STRAIGHT_H"], atlas_transform)

	for x in range_ceil:
		layer.set_cell(Vector2i(x, ceil_y), TILE_SOURCE_ID, AT["STRAIGHT_H"], revers)

# =============== gestione adiacenze ===============

# Sposta roomL (destra) alla stessa Y del marker E di roomH, se sono adiacenti.
static func _align_adjacent_H(layer: TileMapLayer, roomH: RoomTemplateMeta, roomL: RoomTemplateMeta, connH: RoomConnector, connL: RoomConnector) -> bool:
	if roomH == null or roomL == null: return false
	if connH == null or connL == null: return false

	# Celle dei marker sul layer dei corridoi
	var cH := _marker_cell(layer, connH)
	var cL := _marker_cell(layer, connL)

	# Differenza verticale in CELLE
	var dy_cells := cH.y - cL.y
	if dy_cells == 0:
		return true  # già allineati

	# Sposta la stanza più bassa (roomL) di dy_cells in world
	var delta_world := _cells_to_world_delta(layer, Vector2i(0, dy_cells))
	roomL.global_position = _snap_world_to_tile_grid(layer, roomL.global_position + delta_world)
	var tile : TileMapLayer = roomL.get_node_or_null("Collision")
	if tile: tile.global_position.y = roomL.global_position.y
	return true
	
# Sposta roomR (destra) alla stessa X del marker E di roomL, se sono adiacenti.
static func _align_adjacent_V(layer: TileMapLayer, roomL: RoomTemplateMeta, roomR: RoomTemplateMeta, connL: RoomConnector, connR: RoomConnector) -> bool:
	if roomR == null or roomL == null: return false
	if connR == null or connL == null: return false

	# Celle dei marker sul layer dei corridoi
	var cR := _marker_cell(layer, connR)
	var cL := _marker_cell(layer, connL)

	# Differenza verticale in CELLE
	var dx_cells := cR.x - cL.x
	if dx_cells == 0:
		return true  # già allineati

	# Sposta la stanza più bassa (roomL) di dy_cells in world
	var delta_world := _cells_to_world_delta(layer, Vector2i(dx_cells, 0))
	roomL.global_position = _snap_world_to_tile_grid(layer, roomL.global_position + delta_world)
	var tile : TileMapLayer = roomL.get_node_or_null("Collision")
	if tile: tile.global_position.x = roomL.global_position.x
	return true

static func _align_adjacent(layer: TileMapLayer, rooms_by_cell: Dictionary) -> bool:
	for cell_v in rooms_by_cell.keys():
		var cell: Vector2i = cell_v
		var room: Node2D = rooms_by_cell[cell]
		if room == null: continue

		var right_cell := cell + Vector2i(1, 0)
	
		var roomR = rooms_by_cell.get(right_cell)
		if roomR == null: continue
	
		var mL: RoomConnector = _get_connector(room, "E")
		var mR: RoomConnector = _get_connector(roomR, "W")
		
		if mL == null or mR == null: return false
	
		var mL_pos : Vector2i = _world_to_cell_layer(layer, mL.global_position, layer.tile_set.tile_size)
		var mR_pos : Vector2i = _world_to_cell_layer(layer, mR.global_position, layer.tile_set.tile_size)
	
		var floor_mL : Vector2i = _get_floor(mL, mL_pos)
		var ceil_mL : Vector2i = _get_ceil(mL, mL_pos)
	
		var floor_mR : Vector2i = _get_floor(mR, mR_pos)
		var ceil_mR : Vector2i = _get_ceil(mR, mR_pos)
	
		var is_ceil_mL_above: bool = ceil_mL.y <= ceil_mR.y
	
		if _are_adjacent_h(mL, mR): 
			_align_adjacent_H(layer, room, roomR, mL, mR) if is_ceil_mL_above else _align_adjacent_H(layer, roomR, room, mR, mL)


		var down_cell := cell + Vector2i(0, 1)
		
		var roomBottom = rooms_by_cell.get(down_cell)
	
		if roomBottom == null: continue
		
		var mT: RoomConnector = _get_connector(room, "S")
		var mB: RoomConnector = _get_connector(roomBottom, "N")
		
		if mT == null or mB == null: return false
		
		var mT_pos : Vector2i = _world_to_cell_layer(layer, mT.global_position, layer.tile_set.tile_size)
		var mB_pos : Vector2i = _world_to_cell_layer(layer, mB.global_position, layer.tile_set.tile_size)
		
		var wallL_mT : Vector2i = _get_wallL(mT, mT_pos)
		var wallR_mT : Vector2i = _get_wallR(mT, mT_pos)
		
		var wallL_mB : Vector2i = _get_wallL(mB, mB_pos)
		var wallR_mB : Vector2i = _get_wallR(mB, mB_pos)

		# Collision locali (per X dei varchi)
		
		var is_wL_mT_left : bool = wallL_mT.x <= wallL_mB.x
		var is_wR_mT_left : bool = wallR_mT.x <= wallR_mB.x
		
		if _are_adjacent_v(mT, mB): 
			_align_adjacent_V(layer, room, roomBottom, mT, mB) if is_wL_mT_left else _align_adjacent_V(layer, roomBottom, room, mB, mT)

	return true

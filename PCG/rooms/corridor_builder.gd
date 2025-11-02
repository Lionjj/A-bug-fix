extends Node
class_name CorridorBuilder

enum direction {E, W, S, N}
	
const DIRS_STR = {
	direction.E:Vector2i(1,0), 
	direction.W:Vector2i(-1,0), 
	direction.S:Vector2i(0,1), 
	direction.N:Vector2i(0,-1)
}

const ALIGN_EPS: int = 1

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


# ================== API ==================
static func connect_adjacent(
	level: Node2D,
	grid_pos: Dictionary,
	room_tiles: Vector2i,
	tile_size: Vector2i = TILE_SIZE
) -> void:
	var rooms_by_cell: Dictionary = _index_rooms_by_grid(level, room_tiles, tile_size)
	var corridor_l: TileMapLayer = _get_or_create_corridor_layer(level)

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
enum RoundPolicy { ROUND, FLOOR, CEIL }

static func _midpoint_cell(a: Vector2i, b: Vector2i, policy: int = RoundPolicy.ROUND) -> Vector2i:
	var mx := (a.x + b.x) * 0.5
	var my := (a.y + b.y) * 0.5
	match policy:
		RoundPolicy.FLOOR: return Vector2i(floori(mx), floori(my))
		RoundPolicy.CEIL: return Vector2i(ceili(mx),  ceili(my))
	
	return Vector2i(roundi(mx), roundi(my))

static func snap_world_to_tile(layer: TileMapLayer, world_pos: Vector2) -> Vector2:
	var local := layer.to_local(world_pos)
	var cell  := layer.local_to_map(local)          # cella intera
	var local_snapped := layer.map_to_local(cell)   # angolo alto-sx della cella
	return layer.to_global(local_snapped)           # world pos allineata 16×16

static func _are_adjacent_h(connA:RoomConnector, connB:RoomConnector) -> bool:
	return abs(connA.global_position.x - connB.global_position.x) < 1 

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

static func _get_connectors(room: RoomTemplateMeta) -> Dictionary[String, RoomConnector]:
	if not room: return {}
	
	var out: Dictionary[String, RoomConnector]
	
	for key in room.connectors.keys():
		if room.connectors[key]:
			var connector: RoomConnector = room.get_node_or_null(room.CONNECTOR_NAMES[key])
			if connector:  out[key] = connector
	
	return out

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

# centro mondo della riga 'row' nel layer (usiamo la colonna 0, ci serve solo la Y)
static func _row_world_center(layer: TileMapLayer, row: int) -> Vector2:
	var ts := layer.tile_set.tile_size
	var local := layer.map_to_local(Vector2i(0, row)) + Vector2(ts.x, ts.y)
	return layer.to_global(local)

# centro mondo della colonna 'col' nel layer (usiamo la riga 0, ci serve solo la X)
static func _col_world_center(layer: TileMapLayer, col: int) -> Vector2:
	var ts := layer.tile_set.tile_size
	var local := layer.map_to_local(Vector2i(col, 0)) + Vector2(ts.x * 0.5, ts.y * 0.5)
	return layer.to_global(local)
# =============== collegamenti ===============

static func _connect_pair_H(level: Node2D, corridor_l: TileMapLayer, roomL: RoomTemplateMeta, roomR: RoomTemplateMeta) -> void:
	# stop se i template non hanno connettori E/W
	if not (roomL.connectors["E"] and roomR.connectors["W"]): return
	
	var mL: RoomConnector = _get_connector(roomL, "E")
	var mR: RoomConnector = _get_connector(roomR, "W")
	
	
	if mL == null or mR == null: return

	# Celle corridoio dei marker (per X estremi)
	var a := _world_to_cell_layer(corridor_l, mL.global_position, corridor_l.tile_set.tile_size)
	var b := _world_to_cell_layer(corridor_l, mR.global_position, corridor_l.tile_set.tile_size)
	var x_left :int= min(a.x, b.x)
	var x_right :int= max(a.x, b.x)

	# Collision locali (per Y dei varchi)
	var collL := _collision_layer(roomL)
	var collR := _collision_layer(roomR)
	if collL == null or collR == null: return

	var a_local := _world_to_cell_in(collL, mL.global_position) # usa .y
	var b_local := _world_to_cell_in(collR, mR.global_position) # usa .y
	var yL := a_local.y
	var yR := b_local.y
	
	# Converti Y locali (Collision) in Y del layer dei corridoi
	var yL_world := _row_world_center(collL, yL)
	var yR_world := _row_world_center(collR, yR)
	
	var y0 := _world_to_cell_layer(corridor_l, yL_world, corridor_l.tile_set.tile_size).y
	var y1 := _world_to_cell_layer(corridor_l, yR_world, corridor_l.tile_set.tile_size).y

	var mid_cell: Vector2i = _midpoint_cell(Vector2i(a.x, y0), Vector2i(b.x, y1), RoundPolicy.CEIL)
	var y_dist = abs(y0 - y1)
	if _are_adjacent_h(mL, mR):
		var higher_conn : int
		var floor: int
		var ceil: int
		if a.y <= b.y:
			higher_conn = yL
			floor = y0 + mL.offset_down
			ceil = y1 + mR.offset_up
			#corridor_l.set_cell(Vector2i(, floor), TILE_SOURCE_ID, AT["EDGE_NE"])
			
		else: 
			higher_conn = yR
			floor = y0 + mL.offset_down
			ceil = y1 + mR.offset_up
		
			
		_carve_opening_edge_layer(roomL, "E", higher_conn)
		_carve_opening_edge_layer(roomR, "W", higher_conn)
		return
		
	# Scava i varchi ai due bordi
	_carve_opening_edge_layer(roomL, "E", yL)
	_carve_opening_edge_layer(roomR, "W", yR)

	#corridor_l.set_cell(mid_cell, TILE_SOURCE_ID, AT["STRAIGHT_H"])
	
	var end_points_mL: Dictionary[String, int]
	var end_points_mR: Dictionary[String, int]
	
	if y_dist <= ALIGN_EPS:
		_draw_horizzontal_S_corridor(corridor_l, mR, mid_cell, y_dist)
		_draw_horizzontal_S_corridor(corridor_l, mL, mid_cell, y_dist)
		# pavimento
		var k = y0 + mL.offset_down - 1
		var pi = y1 + mR.offset_down - 1
		var temp1 = range(min(k, pi), max(k, pi))
		#soffitto
		k = y0 - mL.offset_up -1
		pi = y1 - mR.offset_up -1
		var temp2 = range(min(k, pi), max(k, pi))
		_fill_v_straigth_layer(corridor_l, temp1, temp2, mid_cell.x, mid_cell.x)
		return
	else:
		end_points_mR = _draw_horizzontal_L_corridor(corridor_l, mR, mid_cell, mL.offset_down, mL.offset_up)
		end_points_mL = _draw_horizzontal_L_corridor(corridor_l, mL, mid_cell, mR.offset_down, mR.offset_up)
		
	var rangeWL
	var rangeWR
	var x0
	var x1
	if y0 < y1:
		# Dal paviemnto della stanza sinistra a quello della stanza destra
		rangeWL = range(y0 + mL.offset_down, y1 + mR.offset_down - 1)
		# Dal soffitto della stanza sinistra a quello della stanza destra
		rangeWR = range(y0 - mL.offset_up - 1, y1 - mR.offset_up - 1)
		#
		#x0 = mid_cell.x - min(mL.offset_down, mR.offset_down) - 1
		#x1 = mid_cell.x + min(mL.offset_up, mR.offset_up) + 1
		
		x0 = end_points_mL["END_FLOOR"]
		x1 = end_points_mL["END_CEIL"]
	else:
		# Dal paviemnto della stanza destra a quello della stanza sinistra
		rangeWL = range(y1 - mR.offset_up - 1, y0 - mL.offset_up - 1)
		rangeWR = range(y1 + mR.offset_down, y0 + mL.offset_down - 1)
		#x0 = mid_cell.x - min(mL.offset_up, mR.offset_up) - 1
		#x1 = mid_cell.x + min(mL.offset_down, mR.offset_down) + 1
		x0 = end_points_mR["END_CEIL"]
		x1 = end_points_mR["END_FLOOR"]
		
	_fill_v_straigth_layer(corridor_l, rangeWL, rangeWR, x0, x1)
		


# Disegna V con eventuale gomito se le X non coincidono
static func _connect_pair_V(level: Node2D, corridor_l: TileMapLayer, roomTop: RoomTemplateMeta, roomBottom: RoomTemplateMeta) -> void:
	# stop se i template non hanno connettori N/S
	if not (roomTop.connectors["S"] and roomBottom.connectors["N"]): return
	
	var mT: RoomConnector = _get_connector(roomTop, "S")
	var mB: RoomConnector = _get_connector(roomBottom, "N")
	
	
	if mT == null or mB == null: return

	# Celle corridoio dei marker (per Y estremi)
	var a := _world_to_cell_layer(corridor_l, mT.global_position, corridor_l.tile_set.tile_size)
	var b := _world_to_cell_layer(corridor_l, mB.global_position, corridor_l.tile_set.tile_size)
	var y_top :int= min(a.y, b.y)
	var y_bot :int= max(a.y, b.y)

	# Collision locali (per X dei varchi)
	var collT := _collision_layer(roomTop)
	var collB := _collision_layer(roomBottom)
	if collT == null or collB == null: return

	var a_local := _world_to_cell_in(collT, mT.global_position) # usa .x
	var b_local := _world_to_cell_in(collB, mB.global_position) # usa .x
	var xT := a_local.x
	var xB := b_local.x

	# Scava varchi ai due bordi
	_carve_opening_edge_layer(roomTop, "S", xT)
	_carve_opening_edge_layer(roomBottom, "N", xB)

	# Converti X locali (Collision) in X del layer corridoio
	var xT_world := _col_world_center(collT, xT)
	var xB_world := _col_world_center(collB, xB)
	var x0 := _world_to_cell_layer(corridor_l, xT_world, corridor_l.tile_set.tile_size).x
	var x1 := _world_to_cell_layer(corridor_l, xB_world, corridor_l.tile_set.tile_size).x
	
	var mid_cell: Vector2i = _midpoint_cell(Vector2i(x0, a.y), Vector2i(x1, b.y), RoundPolicy.CEIL)
	
	var x_dist = abs(x0 - x1)
	if x_dist <= ALIGN_EPS:
		_draw_vertical_S_corridor(corridor_l, mT, mid_cell, x_dist)
		_draw_vertical_S_corridor(corridor_l, mB, mid_cell, x_dist)
	
	

	## SNAP: se quasi allineati, usa la stessa X
	#if abs(x0 - x1) <= ALIGN_EPS:
		#var x := (x0 + x1) / 2
		#_fill_v_rect_layer(corridor_l, y_top, y_bot, x, THICKNESS)
	#else:
		## V -> H -> V
		#var y_mid :int= (y_top + y_bot) >> 1
		#_fill_v_rect_layer(corridor_l, y_top, y_mid, x0, THICKNESS)
		#_fill_h_rect_layer(corridor_l, min(x0, x1), max(x0, x1), y_mid, THICKNESS)
		#_fill_v_rect_layer(corridor_l, y_mid, y_bot, x1, THICKNESS)
		## niente croce piena
		## _fill_cross3(corridor_l, Vector2i((x0 + x1) / 2, y_mid))

# =============== carving aperture ===============
static func _carve_opening_edge_layer(room: RoomTemplateMeta, dir: String, coord: int) -> void:
	var coll := _collision_layer(room)
	if coll == null: return

	var size_tiles :Vector2i
	var meta :RoomTemplateMeta= room as RoomTemplateMeta
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
			
			coll.set_cell(Vector2i((coord - 1) + -conn.offset_left, y_edge), TILE_SOURCE_ID, AT["EDGE_SE"])
			
			coll.set_cell(Vector2i(coord + conn.offset_right, y_edge), TILE_SOURCE_ID, AT["EDGE_SW"])
			
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

			coll.set_cell(Vector2i(coord - conn.offset_left -1, y_edge), TILE_SOURCE_ID, AT["EDGE_NE"])
			
			coll.set_cell(Vector2i(coord + conn.offset_right, y_edge), TILE_SOURCE_ID, AT["EDGE_NW"])
			
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
			
			coll.set_cell(Vector2i(x_edge, coord - conn.offset_up -1), TILE_SOURCE_ID, AT["STRAIGHT_H"], TileSetAtlasSource.TRANSFORM_FLIP_V )
			
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
			
			coll.set_cell(Vector2i(x_edge, coord - conn.offset_up - 1), TILE_SOURCE_ID, AT["STRAIGHT_H"], TileSetAtlasSource.TRANSFORM_FLIP_V )
			
			coll.set_cell(Vector2i(x_edge, coord + conn.offset_down), TILE_SOURCE_ID, AT["STRAIGHT_H"])

# =============== drawing utils ===============
#static func _fill_h_rect_layer(layer: TileMapLayer, x_min: int, x_max: int, y_center: int, conn: RoomConnector) -> void:
#
	#var y_floor := y_center + conn.offset_up      # riga basse (pavimento)
	#var y_ceil  := y_center - conn.offset_down     # riga alta (soffitto)
#
	## pavimento: atlas "normale"
	#for x in range(x_min, x_max + 1):
		#layer.set_cell(Vector2i(x, y_floor), TILE_SOURCE_ID, AT["STRAIGHT_H"])
	#
	## soffitto: stesso atlas ma ruotato 180°
	#for x in range(x_min, x_max + 1):
		#layer.set_cell(Vector2i(x, y_floor), TILE_SOURCE_ID, AT["STRAIGHT_H"])
#
	## pulisci l'interno (se thickness > 2)
	#for y in range(y_ceil + 1, y_floor):
		#for x in range(x_min, x_max + 1):
			#layer.set_cell(Vector2i(x, y), -1)
#
static func _draw_horizzontal_L_corridor(layer: TileMapLayer, conn: RoomConnector, mid_cell: Vector2i, sx_lim: int, dx_lim:int) -> Dictionary[String, int]:
	var marker_pos: Vector2i = _world_to_cell_layer(layer, conn.global_position, layer.tile_set.tile_size)
	
	var out: Dictionary[String, int]
	
	var floor: Vector2i = marker_pos + Vector2i(0, conn.offset_down)
	var ceil: Vector2i = marker_pos - Vector2i(0, conn.offset_up + 1)
	
	var t = layer.local_to_map(layer.to_local(conn.global_position))
		# La stanza è più alta del punto medio?
	var is_above: bool = t.y < mid_cell.y
	
	var range_floor: Array
	var range_ceil: Array
	
	var angle0: Vector2i
	var angle1: Vector2i
	var x0: int
	var x1: int

	match conn.axis:
		"W":
			if is_above:
				x0 = (mid_cell.x + min(conn.offset_down, dx_lim)) + 1 
				x1 = (mid_cell.x - min(conn.offset_up, sx_lim)) - 1
				
				angle0 = AT["EDGE_NW"]
				angle1 = AT["CORNER_NW"]
				
				range_floor = range(x0 + 1, floor.x)
				range_ceil = range(x1 + 1, ceil.x)
			else:
				x0 = (mid_cell.x - min(conn.offset_down, sx_lim)) - 1
				x1 = (mid_cell.x + min(conn.offset_up, dx_lim))  + 1
				
				angle0 = AT["CORNER_SW"]
				angle1 = AT["EDGE_SW"]
				
				range_floor = range(x0 + 1, floor.x)
				range_ceil = range(x1 + 1, ceil.x)
				
		"E":
			if is_above:
				x0 = (mid_cell.x - min(conn.offset_down, sx_lim)) - 1
				x1 = (mid_cell.x + min(conn.offset_up, dx_lim)) + 1
				
				angle0 = AT["EDGE_NE"]
				angle1 = AT["CORNER_NE"]
				
				range_floor = range(floor.x, x0)
				range_ceil = range(ceil.x, x1)

			else:
				x0 = (mid_cell.x + min(conn.offset_down, dx_lim)) + 1
				x1 = (mid_cell.x - min(conn.offset_up, sx_lim)) - 1
				
				angle0 = AT["CORNER_SE"]
				angle1 = AT["EDGE_SE"]
				
				range_floor = range(floor.x, x0)
				range_ceil = range(ceil.x, x1)
	
	_fill_h_straigth_layer(layer, range_floor, range_ceil, floor.y, ceil.y)
		
	layer.set_cell(Vector2i(x0, floor.y), TILE_SOURCE_ID, angle0)
	layer.set_cell(Vector2i(x1, ceil.y), TILE_SOURCE_ID, angle1)
	
	out["END_CEIL"] = x1
	out["END_FLOOR"] = x0
	
	return out
	#corridor_l.set_cell(Vector2i( mid_cell.x - mL.offset_down, y_floorL.y + mL.offset_down), TILE_SOURCE_ID, AT["CORNER_NE"])

# Verticale: disegna solo colonna sinistra (parete sx) e colonna destra (parete dx)
static func _fill_v_rect_layer(layer: TileMapLayer, y_min: int, y_max: int, x_center: int, thickness: int) -> void:
	var half := thickness >> 1
	var x_left  := x_center - half      # “parete sinistra”
	var x_right := x_center + half      # “parete destra”

	# “sinistra”: atlas normale
	for y in range(y_min, y_max + 1):
		layer.set_cell(Vector2i(x_left, y), TILE_SOURCE_ID, AT["STRAIGHT_V"])

	# “destra”: lo stesso atlas ma ruotato 180° (così lo “specchi”)
	for y in range(y_min, y_max + 1):
		layer.set_cell(Vector2i(x_left, y), TILE_SOURCE_ID, AT["STRAIGHT_V"])

	# pulisci l'interno (se thickness > 2)
	for x in range(x_left + 1, x_right):
		for y in range(y_min, y_max + 1):
			layer.set_cell(Vector2i(x, y), -1)

static func _fill_h_straigth_layer(layer: TileMapLayer, range_floor: Array, range_ceil: Array, floor_y: int, ceil_y: int) -> void:
	# pavimento: atlas "normale"
	for x in range_floor:
		layer.set_cell(Vector2i(x, floor_y), TILE_SOURCE_ID, AT["STRAIGHT_H"])

	for x in range_ceil:
		layer.set_cell(Vector2i(x, ceil_y), TILE_SOURCE_ID, AT["STRAIGHT_H"], TileSetAtlasSource.TRANSFORM_FLIP_V)

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
					if y_dist <= ALIGN_EPS:
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
				
					if y_dist <= ALIGN_EPS:
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

static func _draw_vertical_S_corridor(layer: TileMapLayer, conn: RoomConnector, mid_cell: Vector2i, x_dist: int):
	var marker_pos: Vector2i = _world_to_cell_layer(layer, conn.global_position, layer.tile_set.tile_size)
		
	var wR: Vector2i = marker_pos + Vector2i(conn.offset_right, 0)
	var wL: Vector2i = marker_pos - Vector2i(conn.offset_left, 0)
		
	var range: Array
		
	var angle0: Vector2i
	var angle1: Vector2i
		
	match conn.axis:
		"N":
			var add: int = 0
			if x_dist != 0:
				add = 1
				if x_dist <= ALIGN_EPS:
					angle0 = AT["EDGE_NE"]
					angle1 = AT["CORNER_NE"]
						
					layer.set_cell(Vector2i(wL.x - 1, mid_cell.y), TILE_SOURCE_ID, AT["EDGE_NE"])
					layer.set_cell(Vector2i(wR.x, mid_cell.y), TILE_SOURCE_ID, AT["CORNER_NE"])
						
				else:
					angle0 = AT["CORNER_SE"]
					angle1 = AT["EDGE_SE"]
						
					layer.set_cell(Vector2i(wL.x - 1, mid_cell.y), TILE_SOURCE_ID, AT["CORNER_NW"])
					layer.set_cell(Vector2i(wR.x, mid_cell.y), TILE_SOURCE_ID, AT["EDGE_NW"])
				
			range = range(mid_cell.y + add, marker_pos.y) 
				
		"S":
			if x_dist != 0:
				
				if x_dist <= ALIGN_EPS:
					angle0 = AT["EDGE_SE"]
					angle1 = AT["CORNER_SE"]
						
					layer.set_cell(Vector2i(wL.x - 1, mid_cell.y), TILE_SOURCE_ID, AT["CORNER_SE"])
					layer.set_cell(Vector2i(wR.x, mid_cell.y), TILE_SOURCE_ID, AT["EDGE_SE"])
				else:
					angle0 = AT["CORNER_NE"	]
					angle1 = AT["EDGE_NE"]
						
					layer.set_cell(Vector2i(wL.x - 1, mid_cell.y), TILE_SOURCE_ID, AT["CORNER_NE"])
					layer.set_cell(Vector2i(wR.x, mid_cell.y), TILE_SOURCE_ID, AT["EDGE_NE"])
				
			range = range(marker_pos.y, mid_cell.y)
			
	_fill_v_straigth_layer(layer, range, range, wL.x - 1, wR.x)
		
static func _fill_v_straigth_layer(layer: TileMapLayer, range_L_wall: Array, range_R_wall: Array, wall_L_x: int, wall_R_x: int, atlas_transform = TileSetAtlasSource.TRANSFORM_FLIP_H) -> void:
	
	var revers = TileSetAtlasSource.TRANSFORM_FLIP_V if atlas_transform == TileSetAtlasSource.TRANSFORM_FLIP_H else TileSetAtlasSource.TRANSFORM_FLIP_H
	
	# muro sinistro: atlas "normale"
	for y in range_L_wall:
		layer.set_cell(Vector2i(wall_L_x, y), TILE_SOURCE_ID, AT["STRAIGHT_H"], TileSetAtlasSource.TRANSFORM_TRANSPOSE | atlas_transform)

	for y in range_R_wall:
		layer.set_cell(Vector2i(wall_R_x, y), TILE_SOURCE_ID, AT["STRAIGHT_H"], TileSetAtlasSource.TRANSFORM_TRANSPOSE | revers )

		

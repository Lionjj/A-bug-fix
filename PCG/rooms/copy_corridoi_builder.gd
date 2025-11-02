extends Node
class_name CorridorBuilder

const TILE_SIZE: Vector2i = Vector2i(16, 16)
const ROOM_TILES: Vector2i = Vector2i(80, 48)

const TM_COLLISION := "Collision"   # se usi Map/Collision gli helper lo gestiscono
const TM_CORRIDOR  := "Corridor"
const TILE_SOURCE_ID := 0
const ATLAS := Vector2i(20, 2)      # coord dell'atlas per la tile corridoio
const THICKNESS := 5                # spessore corridoio (in tile) => tienilo dispari per simmetria: 1,3,5…

const ALIGN_EPS := 1   # tolleranza di 1 cella: se differenza <= 1, consideriamo allineati


const AT = {
	"STRAIGHT_H": Vector2i(20, 2),
	"STRAIGHT_V": Vector2i(5, 7),
	"CORNER_NE":  Vector2i(7, 6),
	"CORNER_NW":  Vector2i(5, 6),
	"CORNER_SE":  Vector2i(7, 8),
	"CORNER_SW":  Vector2i(5, 8),
	"END_E":      Vector2i(26, 2),
	"END_W":      Vector2i(27, 2),
	"END_S":      Vector2i(28, 2),
	"END_N":      Vector2i(29, 2),
}

static func beautify_corridors(level: Node2D) -> void:
	var layer := _get_or_create_corridor_layer(level)
	var used: Array[Vector2i] = []
	# raccogli tutte le celle corridoio piazzate
	for pos in layer.get_used_cells():
		used.append(pos)

	var used_set := {}
	for c in used: used_set[c] = true

	for c in used:
		var n := used_set.has(c + Vector2i(0,-1))
		var e := used_set.has(c + Vector2i(1,0))
		var s := used_set.has(c + Vector2i(0,1))
		var w := used_set.has(c + Vector2i(-1,0))

		var atlas := AT["STRAIGHT_H"]  # default
		var deg := int(n) + int(e) + int(s) + int(w)

		if deg == 1:
			if e: atlas = AT["END_E"]
			elif w: atlas = AT["END_W"]
			elif s: atlas = AT["END_S"]
			elif n: atlas = AT["END_N"]
		elif deg == 2:
			# rettilineo o gomito
			if (e and w) and not (n or s):
				atlas = AT["STRAIGHT_H"]
			elif (n and s) and not (e or w):
				atlas = AT["STRAIGHT_V"]
			else:
				# corner
				if n and e: atlas = AT["CORNER_NE"]
				elif n and w: atlas = AT["CORNER_NW"]
				elif s and e: atlas = AT["CORNER_SE"]
				elif s and w: atlas = AT["CORNER_SW"]
		elif deg >= 3:
			# incroci: usa straight o una tile “junction” se l’hai
			if n and s: atlas = AT["STRAIGHT_V"]
			else: atlas = AT["STRAIGHT_H"]

		layer.set_cell(c, TILE_SOURCE_ID, atlas)


# ================== API ==================
static func connect_adjacent(
	level: Node2D,
	grid_pos: Dictionary,
	room_tiles: Vector2i = ROOM_TILES,
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
		
		beautify_corridors(level)

# =============== helpers base ===============
static func _index_rooms_by_grid(level: Node2D, room_tiles: Vector2i, tile_size: Vector2i) -> Dictionary:
	var idx: Dictionary = {}
	var room_px := Vector2(room_tiles.x * tile_size.x, room_tiles.y * tile_size.y)
	for c in level.get_children():
		var n2d := c as Node2D
		if n2d == null: continue
		var gp := Vector2i(
			int(floor(n2d.position.x / room_px.x)),
			int(floor(n2d.position.y / room_px.y))
		)
		idx[gp] = n2d
	return idx

static func _get_or_create_corridor_layer(level: Node2D) -> TileMapLayer:
	var l := level.get_node_or_null(NodePath(TM_CORRIDOR)) as TileMapLayer
	if l != null:
		return l
	l = TileMapLayer.new()
	l.name = TM_CORRIDOR
	var first_collision := _find_first_collision_layer(level)
	if first_collision:
		l.tile_set = first_collision.tile_set  # riusa lo stesso TileSet
	level.add_child(l)
	l.owner = level
	return l

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

# =============== helpers robusti ===============
static func _set_cell_rot180(layer: TileMapLayer, cell: Vector2i, source_id: int, atlas: Vector2i) -> void:
	layer.set_cell(cell, source_id, atlas)
	var td := layer.get_cell_tile_data(cell)
	if td != null:
		# 180° = flip orizzontale + flip verticale
		td.flip_h = true
		td.flip_v = true

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


static func _world_to_cell_layer(layer: TileMapLayer, world: Vector2, tile_size: Vector2i) -> Vector2i:
	var local := layer.to_local(world)
	return Vector2i(int(floor(local.x / tile_size.x)), int(floor(local.y / tile_size.y)))

static func _world_to_cell_in(layer: TileMapLayer, world: Vector2) -> Vector2i:
	var ts := layer.tile_set.tile_size
	var local := layer.to_local(world)
	return Vector2i(int(floor(local.x / ts.x)), int(floor(local.y / ts.y)))

static func _marker_global(room: Node2D, name: String) -> Marker2D:
	return room.get_node_or_null(NodePath(name)) as Marker2D

# centro mondo della riga 'row' nel layer (usiamo la colonna 0, ci serve solo la Y)
static func _row_world_center(layer: TileMapLayer, row: int) -> Vector2:
	var ts := layer.tile_set.tile_size
	var local := layer.map_to_local(Vector2i(0, row)) + Vector2(ts.x * 0.5, ts.y * 0.5)
	return layer.to_global(local)

# centro mondo della colonna 'col' nel layer (usiamo la riga 0, ci serve solo la X)
static func _col_world_center(layer: TileMapLayer, col: int) -> Vector2:
	var ts := layer.tile_set.tile_size
	var local := layer.map_to_local(Vector2i(col, 0)) + Vector2(ts.x * 0.5, ts.y * 0.5)
	return layer.to_global(local)

static func _has_conn(room: Node2D, dir: String) -> bool:
	var m := room as RoomTemplateMeta
	return m != null and m.connectors.get(dir, false)

static func _need(room: Node2D, dir: String, name: String) -> Marker2D:
	var mk := room.get_node_or_null(NodePath(name)) as Marker2D
	if mk == null:
		push_warning("Missing marker %s in %s (dir=%s)" % [name, room.name, dir])
	return mk

# =============== collegamenti ===============
# Disegna H con eventuale gomito se le Y non coincidono
# Disegna H con eventuale gomito se le Y non coincidono
static func _connect_pair_H(level: Node2D, corridor_l: TileMapLayer, roomL: Node2D, roomR: Node2D) -> void:
	# stop se i template non hanno connettori E/W
	if not (_has_conn(roomL, "E") and _has_conn(roomR, "W")): return
	if _need(roomL, "E", "conn_E") == null or _need(roomR, "W", "conn_W") == null: return
	
	var mL := _marker_global(roomL, "conn_E")
	var mR := _marker_global(roomR, "conn_W")
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

	# Scava i varchi ai due bordi
	_carve_opening_edge_layer(roomL, "E", yL)
	_carve_opening_edge_layer(roomR, "W", yR)

	# Converti Y locali (Collision) in Y del layer dei corridoi
	var yL_world := _row_world_center(collL, yL)
	var yR_world := _row_world_center(collR, yR)
	var y0 := _world_to_cell_layer(corridor_l, yL_world, corridor_l.tile_set.tile_size).y
	var y1 := _world_to_cell_layer(corridor_l, yR_world, corridor_l.tile_set.tile_size).y

	# SNAP: se quasi allineati, usa la stessa Y per evitare gomiti/croci spurie
	if abs(y0 - y1) <= ALIGN_EPS:
		var y := (y0 + y1) / 2
		_fill_h_rect_layer(corridor_l, x_left, x_right, y, THICKNESS)
	else:
		# H -> V -> H
		var x_mid :int= (x_left + x_right) >> 1
		var y_min :int= min(y0, y1)
		var y_max :int= max(y0, y1)
		_fill_h_rect_layer(corridor_l, x_left, x_mid, y0, THICKNESS)
		_fill_v_rect_layer(corridor_l, y_min, y_max, x_mid, THICKNESS)
		_fill_h_rect_layer(corridor_l, x_mid, x_right, y1, THICKNESS)
		# niente croce “piena”: i fill già si toccano; se la vuoi, usa una croce sottile
		# _fill_cross3(corridor_l, Vector2i(x_mid, (y0 + y1) / 2))

# Disegna V con eventuale gomito se le X non coincidono
# Disegna V con eventuale gomito se le X non coincidono
static func _connect_pair_V(level: Node2D, corridor_l: TileMapLayer, roomTop: Node2D, roomBottom: Node2D) -> void:
	# stop se i template non hanno connettori N/S
	if not (_has_conn(roomTop, "S") and _has_conn(roomBottom, "N")): return
	if _need(roomTop, "S", "conn_S") == null or _need(roomBottom, "N", "conn_N") == null: return
	
	var mT := _marker_global(roomTop, "conn_S")
	var mB := _marker_global(roomBottom, "conn_N")
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

	# SNAP: se quasi allineati, usa la stessa X
	if abs(x0 - x1) <= ALIGN_EPS:
		var x := (x0 + x1) / 2
		_fill_v_rect_layer(corridor_l, y_top, y_bot, x, THICKNESS)
	else:
		# V -> H -> V
		var y_mid :int= (y_top + y_bot) >> 1
		_fill_v_rect_layer(corridor_l, y_top, y_mid, x0, THICKNESS)
		_fill_h_rect_layer(corridor_l, min(x0, x1), max(x0, x1), y_mid, THICKNESS)
		_fill_v_rect_layer(corridor_l, y_mid, y_bot, x1, THICKNESS)
		# niente croce piena
		# _fill_cross3(corridor_l, Vector2i((x0 + x1) / 2, y_mid))

# =============== drawing utils ===============
static func _fill_h_rect_layer(layer: TileMapLayer, x_min: int, x_max: int, y_center: int, thickness: int) -> void:
	var half := thickness >> 1
	var y_floor := y_center + half      # riga basse (pavimento)
	var y_ceil  := y_center - half      # riga alta (soffitto)

	# pavimento: atlas "normale"
	for x in range(x_min, x_max + 1):
		layer.set_cell(Vector2i(x, y_floor), TILE_SOURCE_ID, ATLAS)

	# soffitto: stesso atlas ma ruotato 180°
	for x in range(x_min, x_max + 1):
		_set_cell_rot180(layer, Vector2i(x, y_ceil), TILE_SOURCE_ID, ATLAS)

	# pulisci l'interno (se thickness > 2)
	for y in range(y_ceil + 1, y_floor):
		for x in range(x_min, x_max + 1):
			layer.set_cell(Vector2i(x, y), -1)

# Verticale: disegna solo colonna sinistra (parete sx) e colonna destra (parete dx)
static func _fill_v_rect_layer(layer: TileMapLayer, y_min: int, y_max: int, x_center: int, thickness: int) -> void:
	var half := thickness >> 1
	var x_left  := x_center - half      # “parete sinistra”
	var x_right := x_center + half      # “parete destra”

	# “sinistra”: atlas normale
	for y in range(y_min, y_max + 1):
		layer.set_cell(Vector2i(x_left, y), TILE_SOURCE_ID, ATLAS)

	# “destra”: lo stesso atlas ma ruotato 180° (così lo “specchi”)
	for y in range(y_min, y_max + 1):
		_set_cell_rot180(layer, Vector2i(x_right, y), TILE_SOURCE_ID, ATLAS)

	# pulisci l'interno (se thickness > 2)
	for x in range(x_left + 1, x_right):
		for y in range(y_min, y_max + 1):
			layer.set_cell(Vector2i(x, y), -1)

static func _stitch_elbow_H(layer: TileMapLayer, x_mid: int, y0: int, y1: int) -> void:
	# y0 e y1 sono le quote centrali dei due tratti orizzontali
	# mettiamo solo le 4 “pietre d’angolo” sui bordi, non nell’interno
	var half := THICKNESS >> 1
	var xL := x_mid - half    # colonna bordo sinistra del verticale
	var xR := x_mid + half    # colonna bordo destra del verticale

	var y0_ceil := y0 - half  # riga bordo alto del primo orizzontale
	var y0_floor := y0 + half # riga bordo basso del primo orizzontale

	var y1_ceil := y1 - half  # riga bordo alto del secondo orizzontale
	var y1_floor := y1 + half # riga bordo basso del secondo orizzontale

	# Angoli sul tratto di sinistra (quota y0)
	_set_cell_rot180(layer, Vector2i(xL, y0_ceil), TILE_SOURCE_ID, ATLAS) # soffitto
	layer.set_cell(Vector2i(xL, y0_floor), TILE_SOURCE_ID, ATLAS)         # pavimento

	# Angoli sul tratto di destra (quota y1)
	_set_cell_rot180(layer, Vector2i(xR, y1_ceil), TILE_SOURCE_ID, ATLAS) # soffitto
	layer.set_cell(Vector2i(xR, y1_floor), TILE_SOURCE_ID, ATLAS)         # pavimento

static func _stitch_elbow_V(layer: TileMapLayer, y_mid: int, x0: int, x1: int) -> void:
	# x0 e x1 sono le colonne centrali dei due tratti verticali
	var half := THICKNESS >> 1
	var yT := y_mid - half    # riga bordo superiore dell’orizzontale
	var yB := y_mid + half    # riga bordo inferiore dell’orizzontale

	var x0_left := x0 - half  # colonna bordo sinistra del primo verticale
	var x0_right := x0 + half # colonna bordo destra  del primo verticale

	var x1_left := x1 - half
	var x1_right := x1 + half

	# Angoli sul tratto superiore (x0)
	layer.set_cell(Vector2i(x0_left,  yT), TILE_SOURCE_ID, ATLAS)          # parete sx
	_set_cell_rot180(layer, Vector2i(x0_right, yB), TILE_SOURCE_ID, ATLAS) # parete dx (rotata)

	# Angoli sul tratto inferiore (x1)
	layer.set_cell(Vector2i(x1_left,  yT), TILE_SOURCE_ID, ATLAS)
	_set_cell_rot180(layer, Vector2i(x1_right, yB), TILE_SOURCE_ID, ATLAS)

static func _stitch_elbow_outline(layer: TileMapLayer, c: Vector2i, thickness: int) -> void:
	var half := thickness >> 1
	var x0 := c.x - half
	var x1 := c.x + half
	var y0 := c.y - half
	var y1 := c.y + half

	# top (soffitto) e bottom (pavimento)
	for x in range(x0, x1 + 1):
		_set_cell_rot180(layer, Vector2i(x, y0), TILE_SOURCE_ID, ATLAS) # top
		layer.set_cell(Vector2i(x, y1), TILE_SOURCE_ID, ATLAS)          # bottom

	# left (parete sx) e right (parete dx)
	for y in range(y0, y1 + 1):
		layer.set_cell(Vector2i(x0, y), TILE_SOURCE_ID, ATLAS)          # left
		_set_cell_rot180(layer, Vector2i(x1, y), TILE_SOURCE_ID, ATLAS) # right

	# svuota l'interno (corridoio deve essere cavo)
	for y in range(y0 + 1, y1):
		for x in range(x0 + 1, x1):
			layer.set_cell(Vector2i(x, y), -1)


static func seal_unused(level: Node2D, positions: Dictionary) -> void:
	var rooms_by_cell := _index_rooms_by_grid(level, ROOM_TILES, TILE_SIZE)
	for id in positions.keys():
		var cell: Vector2i = positions[id]
		var room := rooms_by_cell.get(cell) as Node2D
		if room == null: continue
		# per ogni direzione: se NON c'è stanza adiacente -> piazza un “cap” di corridoio o props
		_seal_if_no_neighbor(level, room, cell, positions, "E", Vector2i(1,0))
		_seal_if_no_neighbor(level, room, cell, positions, "W", Vector2i(-1,0))
		_seal_if_no_neighbor(level, room, cell, positions, "S", Vector2i(0,1))
		_seal_if_no_neighbor(level, room, cell, positions, "N", Vector2i(0,-1))

static func _seal_if_no_neighbor(level: Node2D, room: Node2D, cell: Vector2i, positions: Dictionary, dir: String, d: Vector2i) -> void:
	# se non c'è stanza nella cella adiacente → optional: disegna un mini “end-cap” visivo nel layer Corridoio
	var has_neighbor := false
	for k in positions.keys():
		if positions[k] == cell + d:
			has_neighbor = true
			break
	if has_neighbor: return
	# esempio minimal: NIENTE da scavare (muro resta intatto).
	# opzionale: puoi mettere 1–2 tile “tappo” su TM_CORRIDOR per estetica
	# (servono funzioni di supporto simili a _fill_h_rect_layer/_fill_v_rect_layer)

## Modulo per la creazione di corridoi tra le stanze.
extends Node
class_name CorridorBuilder

const TM_CORRIDOR  : String = "Corridor"
const TILE_SIZE: Vector2i = Vector2i(16, 16)
const TILE_SOURCE_ID := 0
const ROOM_GROUP: StringName = "rooms" 

const THICKNES: int = 4

enum RoundPolicy { ROUND, FLOOR, CEIL }

# ================== API ==================

static func connect_adjacent(
	level: Node2D,
	grid_pos: Dictionary,
	room_tiles: Vector2i,
	G: MissionGraph,
	tile_size: Vector2i = TILE_SIZE
) -> void:
	var rooms_by_cell: Dictionary[Vector2i, RoomTemplateMeta] = _index_rooms_by_grid(level, room_tiles, tile_size)
	var corridor_l: TileMapLayer = _get_or_create_corridor_layer(level)
	_fill_between_rooms(G, grid_pos, rooms_by_cell, corridor_l)
	
	var builded : Array[String] = []	# Node(String) - Node(String)
	
	for k in grid_pos.keys():
		var queue : Array[String] = G.neighbors(k).duplicate() as Array[String]
		queue.filter(func(s:String): if builded.has(s): queue.erase(s))
		
		while !queue.is_empty():
			var node : String = queue.pop_front()
			_build(level, corridor_l, grid_pos.get(k), grid_pos.get(node), rooms_by_cell)
		builded.append(k)

static func _fill_between_rooms(G: MissionGraph, grid_poss: Dictionary ,rooms: Dictionary[Vector2i, RoomTemplateMeta], corridor_l: TileMapLayer):
	var forbidden: Array[Rect2i] = []	#Aree che devono essere escluse dalla costruzione
	var done: Array[String] = []
	# Individua le aree vietate 
	for room in rooms.keys():
		var rt : RoomTemplateMeta = rooms.get(room)
		if rt == null: continue
		
		var room_box : Rect2i = _room_bbox_in_corridor_layer(corridor_l, rt)
		forbidden.append(room_box)
	
	for current in grid_poss.keys():
		var current_room : RoomTemplateMeta = rooms.get(grid_poss.get(current))
		var current_area : Rect2i = _room_bbox_in_corridor_layer(corridor_l, current_room)
		
		var adiacents : Array[String] = G.neighbors(current)
		
		for adiacent in adiacents:
			if done.has(adiacent): continue
			var adicent_room : RoomTemplateMeta = rooms.get(grid_poss.get(adiacent))
			var adiacent_area : Rect2i = _room_bbox_in_corridor_layer(corridor_l, adicent_room)
			_fill_between_rooms_bbox(current_area, adiacent_area, forbidden, corridor_l, TILE_SOURCE_ID, Vector2i(20, 2))
		
		done.append(current)

static func _fill_between_rooms_bbox(
	rect_a: Rect2i,
	rect_b: Rect2i,
	forbidden: Array[Rect2i],          # es. [rect_a, rect_b] o tutte le stanze
	corridor_tm: TileMapLayer,
	tile_source_id: int,
	atlas_coord: Vector2i
) -> void:
	# rettangolo minimo che contiene entrambe le stanze
	var min_x : int = min(rect_a.position.x, rect_b.position.x)
	var min_y : int = min(rect_a.position.y, rect_b.position.y)
	var max_x : int = max(rect_a.position.x + rect_a.size.x, rect_b.position.x + rect_b.size.x)
	var max_y : int = max(rect_a.position.y + rect_a.size.y, rect_b.position.y + rect_b.size.y)

	var outer : Rect2i = Rect2i(
		Vector2i(min_x, min_y),
		Vector2i(max_x - min_x, max_y - min_y)
	)

	for x in range(outer.position.x, outer.position.x + outer.size.x):
		for y in range(outer.position.y, outer.position.y + outer.size.y):
			var cell := Vector2i(x, y)

			# se il tile è dentro una stanza → NON lo toccare
			var blocked : bool = false
			for r in forbidden:
				if r.has_point(cell):
					blocked = true
					break
			if blocked:
				continue

			corridor_tm.set_cell(cell, tile_source_id, atlas_coord)

static func _build(level: Node2D, corridor_l: TileMapLayer, from: Vector2i, to: Vector2i, room_by_cell:Dictionary[Vector2i, RoomTemplateMeta]): 
	var dir : Vector2i = to - from
	match dir:
		# DESTRA
		Vector2i(1, 0):
			_connect_pair_H(level, corridor_l, room_by_cell.get(from), room_by_cell.get(to))
		Vector2i(-1, 0):
			_connect_pair_H(level, corridor_l, room_by_cell.get(to), room_by_cell.get(from))
		
		Vector2i(0, 1):
			_connect_pair_V(level, corridor_l, room_by_cell.get(from), room_by_cell.get(to))
		Vector2i(0, -1):
			_connect_pair_V(level, corridor_l, room_by_cell.get(to), room_by_cell.get(from))

# =============== collegamenti ===============
static func _connect_pair_H(level: Node2D, corridor_l: TileMapLayer, roomL: RoomTemplateMeta, roomR: RoomTemplateMeta) -> void:
	if not (roomL.connectors["E"] and roomR.connectors["W"]): return
	
	var mL: RoomConnector = _get_connector(roomL, "E")
	var mR: RoomConnector = _get_connector(roomR, "W")
	
	var start_cell : Vector2i = _marker_cell(corridor_l, mL)
	var end_cell : Vector2i = _marker_cell(corridor_l, mR)
	
	_carve_horizontal_opening_between(corridor_l, start_cell, end_cell, mL, mR)
	
	var collL: TileMapLayer = roomL.collision
	var collR: TileMapLayer = roomR.collision
	var a_local : Vector2i = _world_to_cell_in(collL, mL.global_position)
	var b_local : Vector2i = _world_to_cell_in(collR, mR.global_position)
	
	_carve_opening_edge_layer(roomL, collL, "E", a_local.y)
	_carve_opening_edge_layer(roomR, collR, "W", b_local.y)

# Disegna V con eventuale gomito se le X non coincidono
static func _connect_pair_V(level: Node2D, corridor_l: TileMapLayer, roomTop: RoomTemplateMeta, roomBottom: RoomTemplateMeta) -> void:
	# stop se i template non hanno connettori N/S
	if not (roomTop.connectors["S"] and roomBottom.connectors["N"]): return
	
	var mT: RoomConnector = _get_connector(roomTop, "S")
	var mB: RoomConnector = _get_connector(roomBottom, "N")
	
	var start_cell : Vector2i = _marker_cell(corridor_l, mT)
	var end_cell : Vector2i = _marker_cell(corridor_l, mB)
	
	_carve_vertical_opening_between(corridor_l, start_cell, end_cell, mT, mB)

	var collT: TileMapLayer = roomTop.collision
	var collB: TileMapLayer = roomBottom.collision
	var a_local : Vector2i = _world_to_cell_in(collT, mT.global_position) # usa .x
	var b_local : Vector2i = _world_to_cell_in(collB, mB.global_position) # usa .x
	
	_carve_opening_edge_layer(roomTop, collT, "S", a_local.x)
	_carve_opening_edge_layer(roomBottom, collB ,"N", b_local.x)

# =============== helpers base ===============

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
	
static func _get_or_create_corridor_layer(level: Node2D) -> TileMapLayer:
	var layer: TileMapLayer = level.get_node_or_null(NodePath(TM_CORRIDOR)) as TileMapLayer
	if layer != null: return layer
	
	layer = TileMapLayer.new()
	layer.name = TM_CORRIDOR
	
	var scene_tree: SceneTree = level.get_tree()
	var room: RoomTemplateMeta = scene_tree.get_first_node_in_group(ROOM_GROUP) as RoomTemplateMeta
	if room != null:
		var first_collision : TileMapLayer = room.collision
		layer.tile_set = first_collision.tile_set
		
	level.add_child(layer)
	layer.owner = level
	layer.add_to_group("corridor")
	
	return layer

static func _get_connector(room: RoomTemplateMeta, conn: String) -> RoomConnector:
	if not room.connectors[conn]: return
	return room.get_node_or_null(room.CONNECTOR_NAMES[conn])

static func _world_to_cell_in(layer: TileMapLayer, world: Vector2) -> Vector2i:
	var ts := layer.tile_set.tile_size
	var local := layer.to_local(world)
	return Vector2i(int(floor(local.x / ts.x)), int(floor(local.y / ts.y)))

static func _marker_cell(layer: TileMapLayer, node: Node2D) -> Vector2i:
	return layer.local_to_map(layer.to_local(node.global_position))


# =============== carving aperture ===============

static func _clear_edge_and_dig_inward(
	collision_layer: TileMapLayer,
	start_cell: Vector2i,
	inward_step: Vector2i,
	requires_air: bool
) -> void:
	# Cancella il tile sul bordo
	collision_layer.set_cell(start_cell, -1)

	# Avanza verso l'interno finché trova celle valide
	var current_cell : Vector2i = start_cell + inward_step
	while true:
		var tile_data : TileData = collision_layer.get_cell_tile_data(current_cell)
		if tile_data == null:
			break
		if requires_air and not tile_data.has_custom_data("wfc_air"):
			break
		collision_layer.set_cell(current_cell, -1)
		current_cell += inward_step

static func _carve_opening_edge_layer(
	room: RoomTemplateMeta,
	collision_layer: TileMapLayer,
	direction: String,
	door_coordinate: int
) -> void:
	if collision_layer == null or room == null:
		return

	var room_size_tiles: Vector2i = room.size_tiles
	var connector: RoomConnector = _get_connector(room, direction)
	if connector == null:
		return

	match direction:
		# ===================== NORTH =====================
		# door_coordinate = X del varco
		"N":
			var edge_y : int = 0
			for offset_x: int in range(-connector.offset_left, connector.offset_right):
				var x : int = clampi(door_coordinate + offset_x, 0, room_size_tiles.x - 1)
				_clear_edge_and_dig_inward(
					collision_layer,
					Vector2i(x, edge_y),
					Vector2i.DOWN,
					false
				)

		# ===================== SOUTH =====================
		"S":
			var edge_y : int = room_size_tiles.y - 1
			for offset_x: int in range(-connector.offset_left, connector.offset_right):
				var x : int = clampi(door_coordinate + offset_x, 0, room_size_tiles.x - 1)
				_clear_edge_and_dig_inward(
					collision_layer,
					Vector2i(x, edge_y),
					Vector2i.UP,
					false
				)

		# ===================== WEST =====================
		# door_coordinate = Y del varco
		"W":
			var edge_x : int = 0
			for offset_y: int in range(-connector.offset_up, connector.offset_down):
				var y : int = clampi(door_coordinate + offset_y, 0, room_size_tiles.y - 1)
				_clear_edge_and_dig_inward(
					collision_layer,
					Vector2i(edge_x, y),
					Vector2i.RIGHT,
					true
				)

		# ===================== EAST =====================
		"E":
			var edge_x : int = room_size_tiles.x - 1
			for offset_y: int in range(-connector.offset_up, connector.offset_down):
				var y : int = clampi(door_coordinate + offset_y, 0, room_size_tiles.y - 1)
				_clear_edge_and_dig_inward(
					collision_layer,
					Vector2i(edge_x, y),
					Vector2i.LEFT,
					true
				)

static func _room_bbox_in_corridor_layer(layer: TileMapLayer, room: RoomTemplateMeta) -> Rect2i:
	var coll = room.collision
	var min := Vector2i(999999, 999999)
	var max := Vector2i(-999999, -999999)

	for cell in coll.get_used_cells():
		var world = coll.map_to_local(cell)
		world = coll.to_global(world)
		var corridor_cell = layer.local_to_map(layer.to_local(world))

		min.x = min(min.x, corridor_cell.x)
		min.y = min(min.y, corridor_cell.y)
		max.x = max(max.x, corridor_cell.x)
		max.y = max(max.y, corridor_cell.y)

	return Rect2i(min, max - min + Vector2i.ONE)

static func _carve_horizontal_opening_between(
	layer: TileMapLayer,
	start_cell: Vector2i,   # cella del marker della stanza sinistra
	end_cell: Vector2i,     # cella del marker della stanza destra
	connL: RoomConnector,   # ha offset_up / offset_down
	connR: RoomConnector    # idem
) -> void:
	# normalizza: L a sinistra, R a destra
	var a_cell : Vector2i = start_cell
	var b_cell : Vector2i = end_cell
	var a_conn : RoomConnector = connL
	var b_conn : RoomConnector = connR

	if a_cell.x > b_cell.x:
		var tmp_cell : Vector2i = a_cell
		a_cell = b_cell
		b_cell = tmp_cell

		var tmp_conn : RoomConnector = a_conn
		a_conn = b_conn
		b_conn = tmp_conn

	# calcola top/bottom per ciascun connettore
	var a_top    : int = a_cell.y - a_conn.offset_up
	var a_bottom : int = a_cell.y + a_conn.offset_down

	var b_top    : int = b_cell.y - b_conn.offset_up
	var b_bottom : int = b_cell.y + b_conn.offset_down

	# voglio che il corridoio copra tutta la porta più "larga"
	var top    : int = min(a_top, b_top)
	var bottom : int = max(a_bottom, b_bottom)

	# ora scavo il rettangolo da a_cell.x a b_cell.x, tra top e bottom
	for x in range(a_cell.x, b_cell.x + 1):
		for y in range(top, bottom):
			layer.set_cell(Vector2i(x, y), -1)  # -1 = pulisci tile

static func _carve_vertical_opening_between(
	layer: TileMapLayer,
	start_cell: Vector2i,   # marker stanza sopra
	end_cell: Vector2i,     # marker stanza sotto
	connTop: RoomConnector, # offset_left / offset_right
	connBottom: RoomConnector
) -> void:
	var a_cell: Vector2i = start_cell
	var b_cell: Vector2i = end_cell
	var a_conn: RoomConnector = connTop
	var b_conn: RoomConnector = connBottom

	if a_cell.y > b_cell.y:
		var tmp_cell: Vector2i = a_cell; a_cell = b_cell; b_cell = tmp_cell
		var tmp_conn: RoomConnector = a_conn; a_conn = b_conn; b_conn = tmp_conn

	var a_left  : int = a_cell.x - a_conn.offset_left
	var a_right : int = a_cell.x + a_conn.offset_right

	var b_left  : int = b_cell.x - b_conn.offset_left
	var b_right : int = b_cell.x + b_conn.offset_right

	var left: int = min(a_left, b_left)
	var right: int = max(a_right, b_right)

	for y: int in range(a_cell.y, b_cell.y + 1):
		for x: int in range(left, right):
			layer.set_cell(Vector2i(x, y), -1)
	

# ============================================================================
# CorridorBuilder
# ============================================================================
## Modulo responsabile della generazione dei corridoi tra le stanze.[br]
##[br]
## Responsabilità:[br]
## - Collegare stanze adiacenti sulla griglia logica (MissionGraph)[br]
## - Creare / recuperare un TileMapLayer dedicato ai corridoi[br]
## - Riempire lo spazio "tra" le stanze senza invadere le loro bounding box[br]
## - Scavare varchi coerenti nei bordi delle stanze (aperture)[br]
## - Rispettare i connettori logici (N/E/S/W) definiti nei template[br]
##[br]
## Dipendenze:[br]
## - MissionGraph: topologia e vicinati tra nodi[br]
## - RoomTemplateMeta: stanza fisica, TileMapLayer di collisione, connettori[br]
## - RoomConnector: marker e offset di apertura (up/down/left/right)[br]
##[br]
## Coordinate:[br]
## - I corridoi vengono disegnati in CELLE (Vector2i)[br]
## - Conversioni world/cell centralizzate in helper dedicati[br]
##[br]
## Architettura:[br]
## - Static module (stateless): nessun riferimento persistente[br]
## - Un TileMapLayer "Corridor" condiviso a livello di Level[br]
# ============================================================================
extends Node
class_name CorridorBuilder


# ---------------------------------------------------------------------------
# Config / costanti
# ---------------------------------------------------------------------------

## Nome del TileMapLayer dedicato ai corridoi
const TM_CORRIDOR: String = "Corridor"

## Dimensione standard tile (fallback)
const TILE_SIZE: Vector2i = Vector2i(16, 16)

## TileSet source ID usato per settare tile sul layer corridoi
const TILE_SOURCE_ID: int = 0

## Gruppo in cui vengono registrate le stanze nel scene tree
const ROOM_GROUP: StringName = "rooms"

## Spessore base corridoio (non usato direttamente in questa versione)
const THICKNES: int = 4

## Politica di arrotondamento (placeholder / future use)
enum RoundPolicy { ROUND, FLOOR, CEIL }


# ---------------------------------------------------------------------------
# API pubblica
# ---------------------------------------------------------------------------

## Collega tutte le stanze adiacenti definite dal grafo logico. [br]
## [br]
## Pipeline: [br]
## 1) indicizza le RoomTemplateMeta per cella griglia (coordinate logiche); [br]
## 2) crea o recupera il TileMapLayer "Corridor"; [br]
## 3) riempie lo spazio tra stanze (fill estetico) evitando le aree delle stanze; [br]
## 4) scava i corridoi tra i connettori (aperture + edge carving). [br]
## [br]
## [param level] Root del livello ([WorldGen]) che contiene le stanze. [br]
## [param grid_pos] Dizionario { NodeId(String) : Vector2i } con posizione logica in griglia. [br]
## [param room_tiles] Dimensione stanza in tile (usata per l’indicizzazione su griglia). [br]
## [param G] MissionGraph con le adiacenze tra stanze. [br]
## [param tile_size] Dimensione tile (default 16x16). [br]
static func connect_adjacent(context: CorridorBuildContext) -> void:
	if context == null or context.root == null or context.graph == null:
		return

	var grid_pos: Dictionary[String, Vector2i] = context.positions
	if grid_pos.is_empty():
		return

	var room_tiles: Vector2i = context.cell_tiles
	var tile_size: Vector2i = context.tile_size if context.tile_size != Vector2i.ZERO else TILE_SIZE
	var level: Node2D = context.root
	var G: MissionGraph = context.graph

	var rooms_by_cell: Dictionary[Vector2i, RoomTemplateMeta] = \
		_index_rooms_by_positions(level, grid_pos)

	if rooms_by_cell.is_empty():
		return

	var corridor_l: TileMapLayer = _get_or_create_corridor_layer(level)
	if corridor_l == null:
		return

	_fill_between_rooms(G, grid_pos, rooms_by_cell, corridor_l)

	var builded: Array[String] = []

	for k in grid_pos.keys():
		var queue: Array = G.neighbors(k).duplicate()

		# NB: filter ritorna un array nuovo
		queue = queue.filter(func(s: String) -> bool:
			return not builded.has(s)
		)

		while not queue.is_empty():
			var node: String = String(queue.pop_front())
			_build(level, corridor_l, grid_pos.get(k), grid_pos.get(node), rooms_by_cell)

		builded.append(k)


# ---------------------------------------------------------------------------
# Fill tra bounding box delle stanze
# ---------------------------------------------------------------------------

## Riempie l’area tra stanze adiacenti evitando di scrivere dentro le stanze. [br]
## [br]
## Strategia: [br]
## - calcola le bounding box (in celle del corridor layer) di tutte le stanze → aree vietate; [br]
## - per ogni arco (current → adjacent) riempie il rettangolo minimo contenitore
##   tra le due bbox, saltando tutte le celle vietate. [br]
## [br]
## [param G] Grafo logico con le adiacenze. [br]
## [param grid_poss] Dizionario delle posizioni logiche in griglia. [br]
## [param rooms] Dizionario { grid_cell : RoomTemplateMeta }. [br]
## [param corridor_l] TileMapLayer su cui disegnare il fill dei corridoi. [br]
static func _fill_between_rooms(
	G: MissionGraph,
	grid_poss: Dictionary,
	rooms: Dictionary[Vector2i, RoomTemplateMeta],
	corridor_l: TileMapLayer
) -> void:
	if G == null:
		return
	if corridor_l == null:
		return
	if rooms.is_empty():
		return
	if grid_poss.is_empty():
		return

	var forbidden: Array[Rect2i] = []	## Aree che devono essere escluse dalla costruzione
	var done: Array[String] = []

	## 1) Individua tutte le aree vietate (bbox delle stanze)
	for room_cell in rooms.keys():
		var rt: RoomTemplateMeta = rooms.get(room_cell)
		if rt == null:
			continue

		var room_box: Rect2i = _room_bbox_in_corridor_layer(corridor_l, rt)
		forbidden.append(room_box)

	## 2) Riempie tra bbox di stanze adiacenti nel grafo
	for current in grid_poss.keys():
		var current_room: RoomTemplateMeta = rooms.get(grid_poss.get(current))
		if current_room == null:
			continue

		var current_area: Rect2i = _room_bbox_in_corridor_layer(corridor_l, current_room)
		var adiacents: Array = G.neighbors(current)

		for adiacent in adiacents:
			## Evita doppioni grossolani
			if done.has(adiacent):
				continue

			var adicent_room: RoomTemplateMeta = rooms.get(grid_poss.get(adiacent))
			if adicent_room == null:
				continue

			var adiacent_area: Rect2i = _room_bbox_in_corridor_layer(corridor_l, adicent_room)

			_fill_between_rooms_bbox(
				current_area,
				adiacent_area,
				forbidden,
				corridor_l,
				TILE_SOURCE_ID,
				Vector2i(20, 2)
			)

		done.append(current)


## Riempie il rettangolo minimo che contiene entrambe le stanze,
## evitando qualunque area presente in [param forbidden]. [br]
## [br]
## [param rect_a] Bounding box della stanza A (celle corridoio). [br]
## [param rect_b] Bounding box della stanza B (celle corridoio). [br]
## [param forbidden] Aree vietate (bbox stanze, ecc.). [br]
## [param corridor_tm] TileMapLayer dei corridoi. [br]
## [param tile_source_id] Sorgente tile da usare. [br]
## [param atlas_coord] Coordinate nell’atlante del tile da piazzare. [br]
static func _fill_between_rooms_bbox(
	rect_a: Rect2i,
	rect_b: Rect2i,
	forbidden: Array[Rect2i],
	corridor_tm: TileMapLayer,
	tile_source_id: int,
	atlas_coord: Vector2i
) -> void:
	if corridor_tm == null:
		return

	## rettangolo minimo che contiene entrambe le stanze
	var min_x: int = min(rect_a.position.x, rect_b.position.x)
	var min_y: int = min(rect_a.position.y, rect_b.position.y)
	var max_x: int = max(rect_a.position.x + rect_a.size.x, rect_b.position.x + rect_b.size.x)
	var max_y: int = max(rect_a.position.y + rect_a.size.y, rect_b.position.y + rect_b.size.y)

	var outer: Rect2i = Rect2i(
		Vector2i(min_x, min_y),
		Vector2i(max_x - min_x, max_y - min_y)
	)

	for x in range(outer.position.x, outer.position.x + outer.size.x):
		for y in range(outer.position.y, outer.position.y + outer.size.y):
			var cell: Vector2i = Vector2i(x, y)

			## Se la cella è dentro una stanza (o altra area forbidden) → skip
			var blocked: bool = false
			for r in forbidden:
				if r.has_point(cell):
					blocked = true
					break

			if blocked:
				continue

			corridor_tm.set_cell(cell, tile_source_id, atlas_coord)


# ---------------------------------------------------------------------------
# Costruzione connessioni
# ---------------------------------------------------------------------------

## Crea la connessione fisica tra due stanze adiacenti in griglia. [br]
## [br]
## La direzione viene determinata da (to - from): [br]
## - (1,0)  → orizzontale (da sinistra a destra) [br]
## - (-1,0) → orizzontale (da destra a sinistra, normalizzata) [br]
## - (0,1)  → verticale (dall’alto verso il basso) [br]
## - (0,-1) → verticale (dal basso verso l’alto, normalizzata) [br]
## [br]
## [param level] Root del livello (Node2D). [br]
## [param corridor_l] TileMapLayer corridoi su cui scavare. [br]
## [param from] Cella griglia logica della stanza sorgente. [br]
## [param to] Cella griglia logica della stanza destinazione. [br]
## [param room_by_cell] Dizionario { grid_cell : RoomTemplateMeta }. [br]
static func _build(
	level: Node2D,
	corridor_l: TileMapLayer,
	from: Vector2i,
	to: Vector2i,
	room_by_cell: Dictionary[Vector2i, RoomTemplateMeta]
) -> void:
	if corridor_l == null:
		return

	var dir: Vector2i = to - from

	match dir:
		## DESTRA: from -> to
		Vector2i(1, 0):
			_connect_pair_H(level, corridor_l, room_by_cell.get(from), room_by_cell.get(to))

		## SINISTRA: invertiamo per avere sempre L e R corretti
		Vector2i(-1, 0):
			_connect_pair_H(level, corridor_l, room_by_cell.get(to), room_by_cell.get(from))

		## GIÙ: from -> to (roomTop, roomBottom)
		Vector2i(0, 1):
			_connect_pair_V(level, corridor_l, room_by_cell.get(from), room_by_cell.get(to))

		## SU: invertiamo per avere sempre Top e Bottom corretti
		Vector2i(0, -1):
			_connect_pair_V(level, corridor_l, room_by_cell.get(to), room_by_cell.get(from))


# ---------------------------------------------------------------------------
# Connessioni orizzontali e verticali
# ---------------------------------------------------------------------------

## Collega due stanze orizzontalmente (L → R). [br]
## [br]
## Requisiti: [br]
## - roomL deve avere connettore "E"; [br]
## - roomR deve avere connettore "W". [br]
## [br]
## Effetti: [br]
## - scava un’apertura nel corridor layer tra i marker; [br]
## - scava un varco sui bordi delle TileMapLayer di collisione di entrambe le stanze. [br]
## [br]
## [param level] Root del livello (Node2D). [br]
## [param corridor_l] TileMapLayer corridoi. [br]
## [param roomL] Stanza a sinistra. [br]
## [param roomR] Stanza a destra. [br]
static func _connect_pair_H(
	level: Node2D,
	corridor_l: TileMapLayer,
	roomL: RoomTemplateMeta,
	roomR: RoomTemplateMeta
) -> void:
	if roomL == null:
		return
	if roomR == null:
		return

	if not (roomL.connectors["E"] and roomR.connectors["W"]):
		return

	var mL: RoomConnector = _get_connector(roomL, "E")
	var mR: RoomConnector = _get_connector(roomR, "W")
	if mL == null:
		return
	if mR == null:
		return

	var start_cell: Vector2i = _marker_cell(corridor_l, mL)
	var end_cell: Vector2i = _marker_cell(corridor_l, mR)

	_carve_horizontal_opening_between(corridor_l, start_cell, end_cell, mL, mR)

	var collL: TileMapLayer = roomL.collision
	var collR: TileMapLayer = roomR.collision
	if collL == null:
		return
	if collR == null:
		return

	var a_local: Vector2i = _world_to_cell_in(collL, mL.global_position)
	var b_local: Vector2i = _world_to_cell_in(collR, mR.global_position)

	_carve_opening_edge_layer(roomL, collL, "E", a_local.y)
	_carve_opening_edge_layer(roomR, collR, "W", b_local.y)


## Collega due stanze verticalmente (Top → Bottom). [br]
## [br]
## Requisiti: [br]
## - roomTop deve avere connettore "S"; [br]
## - roomBottom deve avere connettore "N". [br]
## [br]
## Effetti: [br]
## - scava un’apertura nel corridor layer tra i marker; [br]
## - scava un varco sui bordi delle TileMapLayer di collisione. [br]
## [br]
## [param level] Root del livello (Node2D). [br]
## [param corridor_l] TileMapLayer corridoi. [br]
## [param roomTop] Stanza superiore. [br]
## [param roomBottom] Stanza inferiore. [br]
static func _connect_pair_V(
	level: Node2D,
	corridor_l: TileMapLayer,
	roomTop: RoomTemplateMeta,
	roomBottom: RoomTemplateMeta
) -> void:
	if roomTop == null:
		return
	if roomBottom == null:
		return

	if not (roomTop.connectors["S"] and roomBottom.connectors["N"]):
		return

	var mT: RoomConnector = _get_connector(roomTop, "S")
	var mB: RoomConnector = _get_connector(roomBottom, "N")
	if mT == null:
		return
	if mB == null:
		return

	var start_cell: Vector2i = _marker_cell(corridor_l, mT)
	var end_cell: Vector2i = _marker_cell(corridor_l, mB)

	_carve_vertical_opening_between(corridor_l, start_cell, end_cell, mT, mB)

	var collT: TileMapLayer = roomTop.collision
	var collB: TileMapLayer = roomBottom.collision
	if collT == null:
		return
	if collB == null:
		return

	var a_local: Vector2i = _world_to_cell_in(collT, mT.global_position) ## usa .x
	var b_local: Vector2i = _world_to_cell_in(collB, mB.global_position) ## usa .x

	_carve_opening_edge_layer(roomTop, collT, "S", a_local.x)
	_carve_opening_edge_layer(roomBottom, collB, "N", b_local.x)


# ---------------------------------------------------------------------------
# Helpers base / indexing / layer management
# ---------------------------------------------------------------------------

## Indicizza le stanze per cella griglia. [br]
## [br]
## La cella viene calcolata in base alla posizione world della stanza e alla
## dimensione della stanza in pixel (room_tiles * tile_size). [br]
## [br]
## [param level] Nodo che contiene le stanze. [br]
## [param room_tiles] Dimensione stanza in tile. [br]
## [param tile_size] Dimensione tile. [br]
## [return] Dizionario { grid_cell : RoomTemplateMeta }. [br]
static func _index_rooms_by_positions(
	level: Node2D,
	positions: Dictionary[String, Vector2i]
) -> Dictionary[Vector2i, RoomTemplateMeta]:
	var idx: Dictionary[Vector2i, RoomTemplateMeta] = {}
	if level == null or positions.is_empty():
		return idx

	for child in level.get_children():
		var room: RoomTemplateMeta = child as RoomTemplateMeta
		if room == null or room.logic_node == null:
			continue

		var id: String = room.logic_node.id
		if not positions.has(id):
			continue

		idx[positions[id]] = room

	return idx


## Recupera il TileMapLayer dei corridoi se esiste, altrimenti lo crea. [br]
## [br]
## Note: [br]
## - eredita la TileSet dalla prima stanza trovata (per coerenza visual); [br]
## - il layer viene aggiunto come figlio di [param level]. [br]
## [br]
## [param level] Root del livello (Node2D). [br]
## [return] Il TileMapLayer dei corridoi, oppure null se non creabile. [br]
static func _get_or_create_corridor_layer(level: Node2D) -> TileMapLayer:
	if level == null:
		return null

	var layer: TileMapLayer = level.get_node_or_null(NodePath(TM_CORRIDOR)) as TileMapLayer
	if layer != null:
		return layer

	layer = TileMapLayer.new()
	layer.name = TM_CORRIDOR

	## Se posso, eredito la TileSet dalla prima stanza
	var scene_tree: SceneTree = level.get_tree()
	if scene_tree != null:
		var room: RoomTemplateMeta = scene_tree.get_first_node_in_group(ROOM_GROUP) as RoomTemplateMeta
		if room != null and room.collision != null:
			layer.tile_set = room.collision.tile_set

	level.add_child(layer)
	layer.owner = level
	layer.add_to_group("corridor")

	return layer


## Recupera il RoomConnector per una direzione (N/E/S/W). [br]
## [br]
## [param room] Stanza da cui leggere il connettore. [br]
## [param conn] Direzione ("N", "S", "E", "W"). [br]
## [return] Il RoomConnector relativo, oppure null se assente. [br]
static func _get_connector(room: RoomTemplateMeta, conn: String) -> RoomConnector:
	if room == null:
		return null

	## Guard clause: se il connettore è dichiarato assente → null
	if not room.connectors.has(conn):
		return null
	if not room.connectors[conn]:
		return null

	return room.get_node_or_null(room.CONNECTOR_NAMES[conn]) as RoomConnector


## Converte coordinate world in cella locale di un TileMapLayer. [br]
## [br]
## [param layer] TileMapLayer di riferimento. [br]
## [param world] Posizione in coordinate globali. [br]
## [return] Coordinate cella (Vector2i) nel layer. [br]
static func _world_to_cell_in(layer: TileMapLayer, world: Vector2) -> Vector2i:
	var ts: Vector2i = layer.tile_set.tile_size
	var local: Vector2 = layer.to_local(world)
	return Vector2i(int(floor(local.x / ts.x)), int(floor(local.y / ts.y)))


## Ritorna la cella del corridor layer corrispondente a un marker (RoomConnector). [br]
## [br]
## [param layer] TileMapLayer dei corridoi. [br]
## [param node] Marker (Node2D) del connettore. [br]
## [return] Cella nel corridor layer corrispondente alla posizione del marker. [br]
static func _marker_cell(layer: TileMapLayer, node: Node2D) -> Vector2i:
	return layer.local_to_map(layer.to_local(node.global_position))


# ---------------------------------------------------------------------------
# Carving aperture (scavo nei layer di collisione)
# ---------------------------------------------------------------------------

## Pulisce il tile sul bordo e scava verso l'interno finché trova solidi validi. [br]
## [br]
## Regole di stop: [br]
## - se il tile è nullo (aria) si ferma; [br]
## - se [param requires_air] è true, scava solo finché il tile ha custom_data "wfc_air". [br]
## [br]
## [param collision_layer] TileMapLayer collisione stanza. [br]
## [param start_cell] Cella sul bordo da pulire. [br]
## [param inward_step] Direzione verso l’interno (UP/DOWN/LEFT/RIGHT). [br]
## [param requires_air] Se true, richiede custom_data "wfc_air" per continuare lo scavo. [br]
static func _clear_edge_and_dig_inward(
	collision_layer: TileMapLayer,
	start_cell: Vector2i,
	inward_step: Vector2i,
	requires_air: bool
) -> void:
	## Guard clause
	if collision_layer == null:
		return

	## Cancella il tile sul bordo
	collision_layer.set_cell(start_cell, -1)

	## Avanza verso l'interno finché incontra condizioni di stop
	var current_cell: Vector2i = start_cell + inward_step

	while true:
		var tile_data: TileData = collision_layer.get_cell_tile_data(current_cell)

		## Stop: ho trovato aria (niente tile)
		if tile_data == null:
			break

		## Stop: richiedo tile "aria WFC" ma non è presente
		if requires_air and not tile_data.has_custom_data("wfc_air"):
			break

		collision_layer.set_cell(current_cell, -1)
		current_cell += inward_step


## Scava il varco sul bordo della stanza in base alla direzione. [br]
## [br]
## [param room] Stanza su cui aprire il varco. [br]
## [param collision_layer] TileMapLayer collisione stanza. [br]
## [param direction] Direzione ("N", "S", "E", "W"). [br]
## [param door_coordinate] Coordinata lungo l’edge: X per N/S, Y per E/W. [br]
static func _carve_opening_edge_layer(
	room: RoomTemplateMeta,
	collision_layer: TileMapLayer,
	direction: String,
	door_coordinate: int
) -> void:
	if room == null:
		return
	if collision_layer == null:
		return

	var room_size_tiles: Vector2i = room.size_tiles
	var connector: RoomConnector = _get_connector(room, direction)
	if connector == null:
		return

	match direction:
		## ===================== NORTH =====================
		## door_coordinate = X del varco
		"N":
			var edge_y: int = 0
			for offset_x: int in range(-connector.offset_left, connector.offset_right):
				var x: int = clampi(door_coordinate + offset_x, 0, room_size_tiles.x - 1)
				_clear_edge_and_dig_inward(
					collision_layer,
					Vector2i(x, edge_y),
					Vector2i.DOWN,
					false
				)

		## ===================== SOUTH =====================
		"S":
			var edge_y: int = room_size_tiles.y - 1
			for offset_x: int in range(-connector.offset_left, connector.offset_right):
				var x: int = clampi(door_coordinate + offset_x, 0, room_size_tiles.x - 1)
				_clear_edge_and_dig_inward(
					collision_layer,
					Vector2i(x, edge_y),
					Vector2i.UP,
					false
				)

		## ===================== WEST =====================
		## door_coordinate = Y del varco
		"W":
			var edge_x: int = 0
			for offset_y: int in range(-connector.offset_up, connector.offset_down):
				var y: int = clampi(door_coordinate + offset_y, 0, room_size_tiles.y - 1)
				_clear_edge_and_dig_inward(
					collision_layer,
					Vector2i(edge_x, y),
					Vector2i.RIGHT,
					true
				)

		## ===================== EAST =====================
		"E":
			var edge_x: int = room_size_tiles.x - 1
			for offset_y: int in range(-connector.offset_up, connector.offset_down):
				var y: int = clampi(door_coordinate + offset_y, 0, room_size_tiles.y - 1)
				_clear_edge_and_dig_inward(
					collision_layer,
					Vector2i(edge_x, y),
					Vector2i.LEFT,
					true
				)


# ---------------------------------------------------------------------------
# Bounding box stanza nel corridor layer
# ---------------------------------------------------------------------------

## Calcola la bounding box di una stanza espressa in celle del corridor layer. [br]
## [br]
## La bbox viene derivata dalle used cells del layer di collisione della stanza,
## convertite in coordinate del corridor layer tramite world-space. [br]
## [br]
## [param layer] TileMapLayer dei corridoi. [br]
## [param room] Stanza di cui calcolare la bbox. [br]
## [return] Rect2i che rappresenta la bbox della stanza (celle corridoio). [br]
static func _room_bbox_in_corridor_layer(layer: TileMapLayer, room: RoomTemplateMeta) -> Rect2i:
	var coll: TileMapLayer = room.collision
	var min_v: Vector2i = Vector2i(999999, 999999)
	var max_v: Vector2i = Vector2i(-999999, -999999)

	for cell in coll.get_used_cells():
		var world: Vector2 = coll.map_to_local(cell)
		world = coll.to_global(world)

		var corridor_cell: Vector2i = layer.local_to_map(layer.to_local(world))

		min_v.x = min(min_v.x, corridor_cell.x)
		min_v.y = min(min_v.y, corridor_cell.y)
		max_v.x = max(max_v.x, corridor_cell.x)
		max_v.y = max(max_v.y, corridor_cell.y)

	return Rect2i(min_v, max_v - min_v + Vector2i.ONE)


# ---------------------------------------------------------------------------
# Carving nel corridor layer tra due marker
# ---------------------------------------------------------------------------

## Scava un'apertura orizzontale nel corridor layer tra due marker. [br]
## [br]
## Comportamento: [br]
## - normalizza sempre L a sinistra e R a destra; [br]
## - usa gli offset up/down dei connettori per definire l’altezza del varco; [br]
## - pulisce le celle tra i due marker (set_cell(..., -1)). [br]
## [br]
## [param layer] TileMapLayer dei corridoi. [br]
## [param start_cell] Cella del marker di partenza. [br]
## [param end_cell] Cella del marker di arrivo. [br]
## [param connL] Connettore della stanza sinistra. [br]
## [param connR] Connettore della stanza destra. [br]
static func _carve_horizontal_opening_between(
	layer: TileMapLayer,
	start_cell: Vector2i,
	end_cell: Vector2i,
	connL: RoomConnector,
	connR: RoomConnector
) -> void:
	if layer == null:
		return
	if connL == null:
		return
	if connR == null:
		return

	## Normalizzazione: L a sinistra, R a destra
	var a_cell: Vector2i = start_cell
	var b_cell: Vector2i = end_cell
	var a_conn: RoomConnector = connL
	var b_conn: RoomConnector = connR

	if a_cell.x > b_cell.x:
		var tmp_cell: Vector2i = a_cell
		a_cell = b_cell
		b_cell = tmp_cell

		var tmp_conn: RoomConnector = a_conn
		a_conn = b_conn
		b_conn = tmp_conn

	## Calcola top/bottom per ciascun connettore
	var a_top: int = a_cell.y - a_conn.offset_up
	var a_bottom: int = a_cell.y + a_conn.offset_down

	var b_top: int = b_cell.y - b_conn.offset_up
	var b_bottom: int = b_cell.y + b_conn.offset_down

	## Il corridoio copre la porta più "larga"
	var top: int = min(a_top, b_top)
	var bottom: int = max(a_bottom, b_bottom)

	## Scavo rettangolo da a_cell.x a b_cell.x, tra top e bottom
	for x in range(a_cell.x, b_cell.x + 1):
		for y in range(top, bottom):
			layer.set_cell(Vector2i(x, y), -1)  ## -1 = pulisci tile


## Scava un'apertura verticale nel corridor layer tra due marker. [br]
## [br]
## Comportamento: [br]
## - normalizza sempre Top sopra e Bottom sotto; [br]
## - usa gli offset left/right dei connettori per definire la larghezza del varco; [br]
## - pulisce le celle tra i due marker (set_cell(..., -1)). [br]
## [br]
## [param layer] TileMapLayer dei corridoi. [br]
## [param start_cell] Cella del marker di partenza. [br]
## [param end_cell] Cella del marker di arrivo. [br]
## [param connTop] Connettore della stanza superiore. [br]
## [param connBottom] Connettore della stanza inferiore. [br]
static func _carve_vertical_opening_between(
	layer: TileMapLayer,
	start_cell: Vector2i,
	end_cell: Vector2i,
	connTop: RoomConnector,
	connBottom: RoomConnector
) -> void:
	if layer == null:
		return
	if connTop == null:
		return
	if connBottom == null:
		return

	var a_cell: Vector2i = start_cell
	var b_cell: Vector2i = end_cell
	var a_conn: RoomConnector = connTop
	var b_conn: RoomConnector = connBottom

	if a_cell.y > b_cell.y:
		var tmp_cell: Vector2i = a_cell
		a_cell = b_cell
		b_cell = tmp_cell

		var tmp_conn: RoomConnector = a_conn
		a_conn = b_conn
		b_conn = tmp_conn

	var a_left: int = a_cell.x - a_conn.offset_left
	var a_right: int = a_cell.x + a_conn.offset_right

	var b_left: int = b_cell.x - b_conn.offset_left
	var b_right: int = b_cell.x + b_conn.offset_right

	var left: int = min(a_left, b_left)
	var right: int = max(a_right, b_right)

	for y: int in range(a_cell.y, b_cell.y + 1):
		for x: int in range(left, right):
			layer.set_cell(Vector2i(x, y), -1)

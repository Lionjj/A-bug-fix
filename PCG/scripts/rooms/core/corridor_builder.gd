# ============================================================================
# CorridorBuilder
# ============================================================================
## Modulo responsabile della generazione dei corridoi tra le stanze.[br]
##
## [b]Responsabilità principali[/b]:[br]
## - Collegare stanze adiacenti sulla griglia logica usando il [MissionGraph].[br]
## - Creare/recuperare un [TileMapLayer] dedicato ai corridoi (unico per livello).[br]
## - Riempire lo spazio “tra” le stanze senza invadere le loro aree (fill estetico).[br]
## - Scavare varchi coerenti sui bordi delle stanze (aperture) in base ai [RoomConnector].[br]
## - Rispettare la convenzione N/E/S/W dei connettori definiti nei template.[br]
##[br]
## [b]Coordinate[/b]:[br]
## - I corridoi vengono disegnati in CELLE ([Vector2i]) del layer corridoi.[br]
## - Le aperture nelle stanze vengono scavate nelle celle dei loro layer collisione.[br]
## - Conversioni world↔cell sono centralizzate in helper dedicati.[br]
##[br]
## [b]Dipendenze[/b]:[br]
## - [MissionGraph]: topologia e vicinati tra nodi.[br]
## - [RoomTemplateMeta]: stanza fisica + [member RoomTemplateMeta.collision] + connettori.[br]
## - [RoomConnector]: marker con offset (up/down/left/right) per dimensione varco.[br]
## - [CorridorBuildContext]: context dati (root/graph/positions/cell_tiles/tile_size).[br]
##[br]
## [b]Note architetturali[/b]:[br]
## - Modulo stateless: espone solo funzioni statiche.[br]
## - Il [TileMapLayer] "Corridor" è condiviso a livello di scena/livello.[br]
# ============================================================================

extends Node
class_name CorridorBuilder


# ---------------------------------------------------------------------------
# Config / Costanti
# ---------------------------------------------------------------------------

## Nome del [TileMapLayer] dedicato ai corridoi.
const TM_CORRIDOR: String = "Corridor"

## Dimensione standard tile (fallback) usata quando il context non la fornisce.
const TILE_SIZE: Vector2i = Vector2i(16, 16)

## TileSet source ID usato per settare tile sul layer corridoi.
const TILE_SOURCE_ID: int = 0

## Gruppo in cui vengono registrate le stanze nel scene tree.
const ROOM_GROUP: StringName = &"rooms"

## Spessore base corridoio (placeholder: non usato direttamente in questa versione).
const THICKNES: int = 4


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Collega tutte le stanze adiacenti definite dal grafo logico.[br]
##[br]
## Pipeline:[br]
## 1) indicizza le [RoomTemplateMeta] per cella griglia (coordinate logiche);[br]
## 2) crea o recupera il [TileMapLayer] "Corridor";[br]
## 3) riempie lo spazio tra stanze (fill estetico) evitando le aree delle stanze;[br]
## 4) scava i corridoi tra i connettori (aperture + carving tra marker).[br]
##[br]
## [param context]: [CorridorBuildContext] con root/graph/positions/cell_tiles/tile_size.[br]
static func connect_adjacent(context: CorridorBuildContext) -> void:
	# Guard: context minimo valido
	if context == null:
		return
	if context.root == null:
		return
	if context.graph == null:
		return

	var grid_pos: Dictionary[String, Vector2i] = context.positions
	if grid_pos.is_empty():
		return

	var level: Node2D = context.root
	var G: MissionGraph = context.graph
	var room_tiles: Vector2i = context.cell_tiles

	# tile_size qui serve solo come fallback per helper che lo leggono dal tileset;
	# se il context fornisce ZERO, usiamo TILE_SIZE.
	var tile_size: Vector2i = context.tile_size
	if tile_size == Vector2i.ZERO:
		tile_size = TILE_SIZE

	var rooms_by_cell: Dictionary[Vector2i, RoomTemplateMeta] = _index_rooms_by_positions(level, grid_pos)
	if rooms_by_cell.is_empty():
		return

	var corridor_l: TileMapLayer = _get_or_create_corridor_layer(level)
	if corridor_l == null:
		return

	# 1) Fill estetico tra bbox stanze (non dentro le stanze)
	_fill_between_rooms(G, grid_pos, rooms_by_cell, corridor_l)

	# 2) Carving per ogni edge del grafo (evita doppioni)
	var built: Dictionary[String, bool] = {}

	for id: String in grid_pos.keys():
		built[id] = true

		var neighbors: Array = G.neighbors(id)
		if neighbors.is_empty():
			continue

		for n in neighbors:
			var nid: String = String(n)

			# Evita doppioni: se stiamo da A e troviamo B, quando itereremo B troveremo A.
			# Costruiamo solo se "B non è già stato processato come current" (built.has(nid) == false),
			# oppure usiamo un criterio lessicografico per stabilizzare.
			# Qui usiamo criterio stabile: costruisci solo se id < nid.
			if id >= nid:
				continue

			_build(level, corridor_l, grid_pos.get(id), grid_pos.get(nid), rooms_by_cell)


# ---------------------------------------------------------------------------
# Fill tra bounding box delle stanze
# ---------------------------------------------------------------------------

## Riempie l’area tra stanze adiacenti evitando di scrivere dentro le stanze.[br]
##[br]
## Strategia:[br]
## - Calcola le bounding box (in celle del corridor layer) di tutte le stanze → aree forbidden.[br]
## - Per ogni arco (current → adjacent) riempie il rettangolo minimo contenitore tra le due bbox,[br]
##   saltando tutte le celle forbidden.[br]
##[br]
## [param G]: [MissionGraph] con le adiacenze.[br]
## [param grid_poss]: dizionario { node_id -> cella griglia }.[br]
## [param rooms]: dizionario { cella griglia -> [RoomTemplateMeta] }.[br]
## [param corridor_l]: [TileMapLayer] su cui disegnare il fill.[br]
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

	# Aree che devono essere escluse (bbox delle stanze sul layer corridoi)
	var forbidden: Array[Rect2i] = []

	for room_cell: Vector2i in rooms.keys():
		var rt: RoomTemplateMeta = rooms.get(room_cell)
		if rt == null:
			continue
		forbidden.append(_room_bbox_in_corridor_layer(corridor_l, rt))

	# Fill tra bbox di stanze adiacenti
	var done: Dictionary[String, bool] = {}

	for current in grid_poss.keys():
		done[String(current)] = true

		var current_room: RoomTemplateMeta = rooms.get(grid_poss.get(current))
		if current_room == null:
			continue

		var current_area: Rect2i = _room_bbox_in_corridor_layer(corridor_l, current_room)
		var adiacents: Array = G.neighbors(String(current))

		for adiacent in adiacents:
			var adj_id: String = String(adiacent)

			# criterio stabile: fill solo una volta per coppia
			if String(current) >= adj_id:
				continue

			var adj_room: RoomTemplateMeta = rooms.get(grid_poss.get(adj_id))
			if adj_room == null:
				continue

			var adj_area: Rect2i = _room_bbox_in_corridor_layer(corridor_l, adj_room)

			_fill_between_rooms_bbox(
				current_area,
				adj_area,
				forbidden,
				corridor_l,
				TILE_SOURCE_ID,
				Vector2i(20, 2)
			)


## Riempie il rettangolo minimo che contiene entrambe le stanze, evitando le celle forbidden.[br]
##[br]
## [param rect_a]: bbox stanza A (celle corridoio).[br]
## [param rect_b]: bbox stanza B (celle corridoio).[br]
## [param forbidden]: array di [Rect2i] da escludere (bbox stanze, ecc.).[br]
## [param corridor_tm]: [TileMapLayer] corridoi.[br]
## [param tile_source_id]: source id del tileset.[br]
## [param atlas_coord]: coordinate atlante del tile da piazzare.[br]
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

	# Rettangolo minimo che contiene entrambe le bbox
	var min_x: int = min(rect_a.position.x, rect_b.position.x)
	var min_y: int = min(rect_a.position.y, rect_b.position.y)
	var max_x: int = max(rect_a.position.x + rect_a.size.x, rect_b.position.x + rect_b.size.x)
	var max_y: int = max(rect_a.position.y + rect_a.size.y, rect_b.position.y + rect_b.size.y)

	var outer: Rect2i = Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x, max_y - min_y))

	for x: int in range(outer.position.x, outer.position.x + outer.size.x):
		for y: int in range(outer.position.y, outer.position.y + outer.size.y):
			var cell: Vector2i = Vector2i(x, y)

			# Skip se la cella è dentro una forbidden area
			var blocked: bool = false
			for r: Rect2i in forbidden:
				if r.has_point(cell):
					blocked = true
					break
			if blocked:
				continue

			corridor_tm.set_cell(cell, tile_source_id, atlas_coord)


# ---------------------------------------------------------------------------
# Costruzione connessioni (per edge)
# ---------------------------------------------------------------------------

## Crea la connessione fisica tra due stanze adiacenti in griglia.[br]
##[br]
## Direzione determinata da (to - from):[br]
## - (1,0)  → orizzontale L→R[br]
## - (-1,0) → orizzontale (normalizzata invertendo)[br]
## - (0,1)  → verticale Top→Bottom[br]
## - (0,-1) → verticale (normalizzata invertendo)[br]
##[br]
## [param level]: root del livello ([Node2D]).[br]
## [param corridor_l]: [TileMapLayer] corridoi.[br]
## [param from]: cella griglia logica stanza sorgente.[br]
## [param to]: cella griglia logica stanza destinazione.[br]
## [param room_by_cell]: dizionario { cella griglia -> [RoomTemplateMeta] }.[br]
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
		Vector2i(1, 0):
			_connect_pair_H(level, corridor_l, room_by_cell.get(from), room_by_cell.get(to))
		Vector2i(-1, 0):
			_connect_pair_H(level, corridor_l, room_by_cell.get(to), room_by_cell.get(from))
		Vector2i(0, 1):
			_connect_pair_V(level, corridor_l, room_by_cell.get(from), room_by_cell.get(to))
		Vector2i(0, -1):
			_connect_pair_V(level, corridor_l, room_by_cell.get(to), room_by_cell.get(from))


# ---------------------------------------------------------------------------
# Connessioni orizzontali e verticali
# ---------------------------------------------------------------------------

## Collega due stanze orizzontalmente (Left → Right).[br]
##[br]
## Requisiti:[br]
## - roomL deve avere connettore "E".[br]
## - roomR deve avere connettore "W".[br]
##[br]
## Effetti:[br]
## - scava l’apertura nel layer corridoi tra i marker.[br]
## - scava il varco sui bordi dei layer collisione di entrambe le stanze.[br]
##[br]
## [param level]: root del livello ([Node2D]).[br]
## [param corridor_l]: [TileMapLayer] corridoi.[br]
## [param roomL]: stanza a sinistra ([RoomTemplateMeta]).[br]
## [param roomR]: stanza a destra ([RoomTemplateMeta]).[br]
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

	# Guard: connettori logici presenti
	if not (roomL.connectors.get("E", false) and roomR.connectors.get("W", false)):
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

	# Converto marker world in cella locale del layer collisione stanza
	var a_local: Vector2i = _world_to_cell_in(collL, mL.global_position)
	var b_local: Vector2i = _world_to_cell_in(collR, mR.global_position)

	# Sui bordi E/W la coordinata lungo l’edge è Y
	_carve_opening_edge_layer(roomL, collL, "E", a_local.y)
	_carve_opening_edge_layer(roomR, collR, "W", b_local.y)


## Collega due stanze verticalmente (Top → Bottom).[br]
##[br]
## Requisiti:[br]
## - roomTop deve avere connettore "S".[br]
## - roomBottom deve avere connettore "N".[br]
##[br]
## Effetti:[br]
## - scava l’apertura nel layer corridoi tra i marker.[br]
## - scava il varco sui bordi dei layer collisione di entrambe le stanze.[br]
##[br]
## [param level]: root del livello ([Node2D]).[br]
## [param corridor_l]: [TileMapLayer] corridoi.[br]
## [param roomTop]: stanza superiore ([RoomTemplateMeta]).[br]
## [param roomBottom]: stanza inferiore ([RoomTemplateMeta]).[br]
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

	if not (roomTop.connectors.get("S", false) and roomBottom.connectors.get("N", false)):
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

	var a_local: Vector2i = _world_to_cell_in(collT, mT.global_position)
	var b_local: Vector2i = _world_to_cell_in(collB, mB.global_position)

	# Sui bordi N/S la coordinata lungo l’edge è X
	_carve_opening_edge_layer(roomTop, collT, "S", a_local.x)
	_carve_opening_edge_layer(roomBottom, collB, "N", b_local.x)


# ---------------------------------------------------------------------------
# Helpers: indexing / layer management
# ---------------------------------------------------------------------------

## Indicizza le stanze per cella griglia, usando [member RoomTemplateMeta.logic_node.id]
## per matchare l’entry in positions.[br]
##[br]
## [param level]: nodo che contiene le stanze (root del livello).[br]
## [param positions]: dizionario { node_id -> cella griglia }.[br]
## [return]: dizionario { cella griglia -> [RoomTemplateMeta] }.[br]
static func _index_rooms_by_positions(
	level: Node2D,
	positions: Dictionary[String, Vector2i]
) -> Dictionary[Vector2i, RoomTemplateMeta]:
	var idx: Dictionary[Vector2i, RoomTemplateMeta] = {}
	if level == null:
		return idx
	if positions.is_empty():
		return idx

	for child: Node in level.get_children():
		var room: RoomTemplateMeta = child as RoomTemplateMeta
		if room == null:
			continue
		if room.logic_node == null:
			continue

		var id: String = room.logic_node.id
		if not positions.has(id):
			continue

		idx[positions[id]] = room

	return idx


## Recupera il [TileMapLayer] dei corridoi se esiste, altrimenti lo crea.[br]
##[br]
## Note:[br]
## - Se possibile, eredita la TileSet dalla prima stanza del gruppo [constant ROOM_GROUP].[br]
## - Aggiunge il layer come child di [param level] e lo registra nel gruppo "corridor".[br]
##[br]
## [param level]: root del livello ([Node2D]).[br]
## [return]: [TileMapLayer] corridoi oppure null se non creabile.[br]
static func _get_or_create_corridor_layer(level: Node2D) -> TileMapLayer:
	if level == null:
		return null

	var layer: TileMapLayer = level.get_node_or_null(NodePath(TM_CORRIDOR)) as TileMapLayer
	if layer != null:
		return layer

	layer = TileMapLayer.new()
	layer.name = TM_CORRIDOR

	# Provo a clonare la tileset dalla prima stanza disponibile
	var scene_tree: SceneTree = level.get_tree()
	if scene_tree != null:
		var room: RoomTemplateMeta = scene_tree.get_first_node_in_group(ROOM_GROUP) as RoomTemplateMeta
		if room != null and room.collision != null:
			layer.tile_set = room.collision.tile_set

	level.add_child(layer)
	layer.owner = level
	layer.add_to_group("corridor")

	return layer


## Recupera il [RoomConnector] per una direzione N/E/S/W.[br]
##[br]
## [param room]: stanza da cui leggere il connettore.[br]
## [param conn]: direzione "N","S","E","W".[br]
## [return]: [RoomConnector] oppure null se assente.[br]
static func _get_connector(room: RoomTemplateMeta, conn: String) -> RoomConnector:
	if room == null:
		return null

	# Guard: direzione non presente o connettore dichiarato assente
	if not room.connectors.has(conn):
		return null
	if not room.connectors[conn]:
		return null

	return room.get_node_or_null(room.CONNECTOR_NAMES[conn]) as RoomConnector


## Converte world-space in cella locale di un [TileMapLayer].[br]
##[br]
## Nota:[br]
## - Usa la tile_size della TileSet del layer (non il fallback globale).[br]
##[br]
## [param layer]: [TileMapLayer] di riferimento.[br]
## [param world]: posizione in coordinate globali.[br]
## [return]: cella locale nel layer ([Vector2i]).[br]
static func _world_to_cell_in(layer: TileMapLayer, world: Vector2) -> Vector2i:
	var ts: Vector2i = layer.tile_set.tile_size
	var local: Vector2 = layer.to_local(world)
	return Vector2i(int(floor(local.x / ts.x)), int(floor(local.y / ts.y)))


## Ritorna la cella del corridor layer corrispondente alla posizione globale di un marker.[br]
##[br]
## [param layer]: [TileMapLayer] corridoi.[br]
## [param node]: marker [Node2D] (tipicamente [RoomConnector]).[br]
## [return]: cella nel layer corridoi ([Vector2i]).[br]
static func _marker_cell(layer: TileMapLayer, node: Node2D) -> Vector2i:
	return layer.local_to_map(layer.to_local(node.global_position))


# ---------------------------------------------------------------------------
# Carving aperture: scavo nei layer collisione stanza
# ---------------------------------------------------------------------------

## Pulisce il tile sul bordo e scava verso l'interno finché trova solidi “scavabili”.[br]
##[br]
## Regole di stop:[br]
## - Se trova aria (tile_data == null) si ferma.[br]
## - Se [param requires_air] è true, continua solo finché il tile ha custom_data "wfc_air". [br]
##[br]
## [param collision_layer]: [TileMapLayer] collisione della stanza.[br]
## [param start_cell]: cella sul bordo da pulire.[br]
## [param inward_step]: direzione verso l’interno (UP/DOWN/LEFT/RIGHT).[br]
## [param requires_air]: se true richiede "wfc_air" per continuare lo scavo.[br]
static func _clear_edge_and_dig_inward(
	collision_layer: TileMapLayer,
	start_cell: Vector2i,
	inward_step: Vector2i,
	requires_air: bool
) -> void:
	if collision_layer == null:
		return

	# Cancella il tile sul bordo
	collision_layer.set_cell(start_cell, -1)

	# Avanza verso l'interno finché incontra condizioni di stop
	var current_cell: Vector2i = start_cell + inward_step

	while true:
		var tile_data: TileData = collision_layer.get_cell_tile_data(current_cell)

		# Stop: aria
		if tile_data == null:
			break

		# Stop: richiedo "wfc_air" ma il tile non lo ha
		if requires_air and not tile_data.has_custom_data("wfc_air"):
			break

		collision_layer.set_cell(current_cell, -1)
		current_cell += inward_step


## Scava un varco sul bordo della stanza in base alla direzione e agli offset del [RoomConnector].[br]
##[br]
## Convenzione:[br]
## - Per N/S: [param door_coordinate] è X lungo l’edge.[br]
## - Per E/W: [param door_coordinate] è Y lungo l’edge.[br]
##[br]
## [param room]: stanza su cui aprire il varco.[br]
## [param collision_layer]: [TileMapLayer] collisione della stanza.[br]
## [param direction]: direzione "N","S","E","W".[br]
## [param door_coordinate]: coordinata lungo l’edge (X per N/S, Y per E/W).[br]
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
		"N":
			var edge_y: int = 0
			for offset_x: int in range(-connector.offset_left, connector.offset_right):
				var x: int = clampi(door_coordinate + offset_x, 0, room_size_tiles.x - 1)
				_clear_edge_and_dig_inward(collision_layer, Vector2i(x, edge_y), Vector2i.DOWN, false)

		"S":
			var edge_y: int = room_size_tiles.y - 1
			for offset_x: int in range(-connector.offset_left, connector.offset_right):
				var x: int = clampi(door_coordinate + offset_x, 0, room_size_tiles.x - 1)
				_clear_edge_and_dig_inward(collision_layer, Vector2i(x, edge_y), Vector2i.UP, false)

		"W":
			var edge_x: int = 0
			for offset_y: int in range(-connector.offset_up, connector.offset_down):
				var y: int = clampi(door_coordinate + offset_y, 0, room_size_tiles.y - 1)
				_clear_edge_and_dig_inward(collision_layer, Vector2i(edge_x, y), Vector2i.RIGHT, true)

		"E":
			var edge_x: int = room_size_tiles.x - 1
			for offset_y: int in range(-connector.offset_up, connector.offset_down):
				var y: int = clampi(door_coordinate + offset_y, 0, room_size_tiles.y - 1)
				_clear_edge_and_dig_inward(collision_layer, Vector2i(edge_x, y), Vector2i.LEFT, true)


# ---------------------------------------------------------------------------
# Bounding box stanza nel corridor layer
# ---------------------------------------------------------------------------

## Calcola la bounding box di una stanza espressa in celle del corridor layer.[br]
##[br]
## Derivazione:[br]
## - Itera le used cells del layer collisione stanza.[br]
## - Converte ogni cella in world-space e poi in cella del corridor layer.[br]
## - Calcola min/max e ritorna un [Rect2i] inclusivo.[br]
##[br]
## [param layer]: [TileMapLayer] corridoi.[br]
## [param room]: stanza target ([RoomTemplateMeta]).[br]
## [return]: bbox in celle corridoio ([Rect2i]).[br]
static func _room_bbox_in_corridor_layer(layer: TileMapLayer, room: RoomTemplateMeta) -> Rect2i:
	var coll: TileMapLayer = room.collision

	var min_v: Vector2i = Vector2i(999999, 999999)
	var max_v: Vector2i = Vector2i(-999999, -999999)

	for cell: Vector2i in coll.get_used_cells():
		var world: Vector2 = coll.to_global(coll.map_to_local(cell))
		var corridor_cell: Vector2i = layer.local_to_map(layer.to_local(world))

		min_v.x = min(min_v.x, corridor_cell.x)
		min_v.y = min(min_v.y, corridor_cell.y)
		max_v.x = max(max_v.x, corridor_cell.x)
		max_v.y = max(max_v.y, corridor_cell.y)

	return Rect2i(min_v, max_v - min_v + Vector2i.ONE)


# ---------------------------------------------------------------------------
# Carving nel corridor layer tra due marker
# ---------------------------------------------------------------------------

## Scava un'apertura orizzontale nel corridor layer tra due marker.[br]
##[br]
## Normalizzazione:[br]
## - Garantisce sempre che A sia a sinistra e B a destra.[br]
## - Usa offset_up/down dei connettori per determinare l’altezza finale del varco.[br]
##[br]
## Nota:[br]
## - Qui si “pulisce” il corridor layer (set_cell(..., -1)) per creare un passaggio.[br]
##[br]
## [param layer]: [TileMapLayer] corridoi.[br]
## [param start_cell]: cella del marker di partenza.[br]
## [param end_cell]: cella del marker di arrivo.[br]
## [param connL]: connettore stanza sinistra ([RoomConnector]).[br]
## [param connR]: connettore stanza destra ([RoomConnector]).[br]
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

	var a_top: int = a_cell.y - a_conn.offset_up
	var a_bottom: int = a_cell.y + a_conn.offset_down
	var b_top: int = b_cell.y - b_conn.offset_up
	var b_bottom: int = b_cell.y + b_conn.offset_down

	var top: int = min(a_top, b_top)
	var bottom: int = max(a_bottom, b_bottom)

	for x: int in range(a_cell.x, b_cell.x + 1):
		for y: int in range(top, bottom):
			layer.set_cell(Vector2i(x, y), -1)


## Scava un'apertura verticale nel corridor layer tra due marker.[br]
##[br]
## Normalizzazione:[br]
## - Garantisce sempre che A sia sopra e B sotto.[br]
## - Usa offset_left/right dei connettori per determinare la larghezza finale del varco.[br]
##[br]
## [param layer]: [TileMapLayer] corridoi.[br]
## [param start_cell]: cella del marker di partenza.[br]
## [param end_cell]: cella del marker di arrivo.[br]
## [param connTop]: connettore stanza superiore ([RoomConnector]).[br]
## [param connBottom]: connettore stanza inferiore ([RoomConnector]).[br]
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

# CorridorBuilder.gd (TileMapLayer only)
extends Node
class_name CorridorBuilder

const TILE := 16

# ---- NOMI LAYER (uguali in tutti i template) ----
const TM_CORRIDOR := "Corridor"
const TM_COLLISION := "Collision"
const MIN_CORRIDOR_THICKNESS := 2  # almeno 2 tile di passaggio (≈ 32px)


# ---- TILE SOURCE e ATLAS COORD (metti i TUOI valori) ----
const TILE_SOURCE_ID := 0
const AT := {
	"STRAIGHT_H": Vector2i(20, 4),
	"STRAIGHT_V": Vector2i(20, 4),
	"CORNER_NE": Vector2i(7, 6),
	"CORNER_NW": Vector2i(5, 6),
	"CORNER_SE": Vector2i(7, 8),
	"CORNER_SW": Vector2i(5, 8),
	"CAP_FLOOR": Vector2i(20, 2),
	"CAP_CEIL":  Vector2i(20, 2)
}

# Stato per la connessione corrente
var _a_corridor : TileMapLayer
var _a_collision : TileMapLayer
var _b_corridor : TileMapLayer
var _b_collision : TileMapLayer
# layer muri (se esiste nella stanza: Walls/Geometry/Room/Structure)
var _a_walls : TileMapLayer
var _b_walls : TileMapLayer
var _a_tile: Vector2i
var _b_tile: Vector2i

# ---------- helpers base ----------
static func _snap16(p: Vector2) -> Vector2: return p.snapped(Vector2(TILE, TILE))
static func _world_tile_to_px(t: Vector2i) -> Vector2: return Vector2(t.x * TILE, t.y * TILE)

func _find_room_root(n: Node) -> Node:
	# risali finché trovi un nodo che contenga i layer richiesti
	var cur := n
	while cur:
		if cur.has_node(TM_CORRIDOR) and cur.has_node(TM_COLLISION):
			return cur
		# fallback: cerca ricorsivamente (nel caso i layer siano annidati)
		if cur.find_child(TM_CORRIDOR, true, false) and cur.find_child(TM_COLLISION, true, false):
			return cur
		cur = cur.get_parent()
	return n

func _get_room_layers(room_root: Node) -> Dictionary:
	var corr := room_root.get_node_or_null(TM_CORRIDOR)
	if corr == null: corr = room_root.find_child(TM_CORRIDOR, true, false)
	var coll := room_root.get_node_or_null(TM_COLLISION)
	if coll == null: coll = room_root.find_child(TM_COLLISION, true, false)

	if not (corr is TileMapLayer) or not (coll is TileMapLayer):
		push_warning("CorridorBuilder: layer non trovati o non sono TileMapLayer sotto '%s'", [room_root.name])
	return {"corridor": corr, "collision": coll}

# world-tile -> map coords di un TileMapLayer
func _worldtile_to_mapcoords(layer: TileMapLayer, world_tile: Vector2i) -> Vector2i:
	var world_px := _world_tile_to_px(world_tile)
	var local = (layer as CanvasItem).to_local(world_px)
	return layer.local_to_map(local)

# scelta layer A/B in base alla distanza dal rispettivo marker
func _choose_layers_for_tile(world_tile: Vector2i) -> Dictionary:
	var da :int= abs(world_tile.x - _a_tile.x) + abs(world_tile.y - _a_tile.y)
	var db :int= abs(world_tile.x - _b_tile.x) + abs(world_tile.y - _b_tile.y)
	return {
		"corridor": _a_corridor if (da <= db) else _b_corridor,
		"collision": _a_collision if (da <= db) else _b_collision
	}

func _place_tile(world_tile: Vector2i, atlas_coord: Vector2i) -> void:
	var layers := _choose_layers_for_tile(world_tile)
	var layer: TileMapLayer = layers.corridor
	if layer:
		var mc := _worldtile_to_mapcoords(layer, world_tile)
		layer.set_cell(mc, TILE_SOURCE_ID, atlas_coord)

func _clear_collision_at(world_tile: Vector2i) -> void:
	var layers := _choose_layers_for_tile(world_tile)
	var layer: TileMapLayer = layers.collision
	if layer:
		var mc := _worldtile_to_mapcoords(layer, world_tile)
		layer.set_cell(mc, -1, Vector2i.ZERO)

# ---------- entry point ----------
func build_between(a_marker: Node, b_marker: Node) -> void:
	# trova room/layer
	var room_a := _find_room_root(a_marker)
	var room_b := _find_room_root(b_marker)
	var la := _get_room_layers(room_a)
	var lb := _get_room_layers(room_b)
	_a_corridor = la.corridor; _a_collision = la.collision
	_b_corridor = lb.corridor; _b_collision = lb.collision

	if not _a_corridor or not _b_corridor:
		push_warning("CorridorBuilder: Corridors layer mancante")
		return

	# world -> tile
	var a_pos: Vector2 = _snap16((a_marker as Node2D).global_position)
	var b_pos: Vector2 = _snap16((b_marker as Node2D).global_position)
	_a_tile = Vector2i(int(a_pos.x)/TILE, int(a_pos.y)/TILE)
	_b_tile = Vector2i(int(b_pos.x)/TILE, int(b_pos.y)/TILE)

	# adiacenti? apri solo varco
	if _are_rooms_adjacent(_a_tile, _b_tile):
		_open_gap_between(a_marker, b_marker, _a_tile, _b_tile)
		return

	# 3) path a gomiti
	var spine := _route_stair_step(_a_tile, _b_tile)

	# 3a) porta all’uscita della stanza A (in base alla prima direzione)
	if spine.size() > 0:
		var first_dir := spine[0] - _a_tile
		_open_entry_at(a_marker, _a_tile, first_dir)

	# 4) posa corridoio
	_lay_corridor_with_width(spine, a_marker, b_marker)

	# 4a) porta all’ingresso in stanza B (in base all’ultima direzione)
	if spine.size() > 0:
		var last_dir := _b_tile - spine[spine.size()-1]
		_open_entry_at(b_marker, _b_tile, last_dir)

	# 5) rifiniture
	_apply_caps_and_corners(spine, a_marker, b_marker)


# ---------- adiacenza + varco ----------
func _are_rooms_adjacent(a_t: Vector2i, b_t: Vector2i) -> bool:
	var dx :int= abs(a_t.x - b_t.x)
	var dy :int= abs(a_t.y - b_t.y)
	return (dx == 1 and dy <= 4) or (dy == 1 and dx <= 4)

func _open_gap_between(a_marker: Node, b_marker: Node, a_t: Vector2i, b_t: Vector2i) -> void:
	var use_axis := ""
	if a_marker is RoomConnector:
		use_axis = (a_marker as RoomConnector).axis
	else:
		# inferenza: se differiscono di più su X, muro verticale (E/W), altrimenti N/S
		use_axis = "E" if (abs(a_t.x - b_t.x) >= abs(a_t.y - b_t.y)) else "N"

	if use_axis in ["E","W"]:
		var top := - (a_marker as RoomConnector).offset_up if (a_marker is RoomConnector) else 0
		var bot := (a_marker as RoomConnector).offset_down if (a_marker is RoomConnector) else 0
		var height :int= max(1, (a_marker as RoomConnector).corridor_height) if (a_marker is RoomConnector) else 1
		_carve_vertical_gap(a_t, b_t, top, bot, height)
	else:
		var left := - (a_marker as RoomConnector).offset_left if (a_marker is RoomConnector) else 0
		var right := (a_marker as RoomConnector).offset_right if (a_marker is RoomConnector) else 0
		var width :int= max(1, (a_marker as RoomConnector).corridor_height) if (a_marker is RoomConnector) else 1
		_carve_horizontal_gap(a_t, b_t, left, right, width)

func _carve_vertical_gap(a_t: Vector2i, b_t: Vector2i, top:int, bot:int, height:int) -> void:
	var x := int(round((a_t.x + b_t.x) * 0.5))
	var y0 := int(round((a_t.y + b_t.y) * 0.5)) + top
	var y1 := int(round((a_t.y + b_t.y) * 0.5)) + bot + height - 1
	for y in range(min(y0,y1), max(y0,y1)+1):
		var t := Vector2i(x, y)
		_place_tile(t, AT["STRAIGHT_V"]); _clear_collision_at(t)

func _carve_horizontal_gap(a_t: Vector2i, b_t: Vector2i, left:int, right:int, width:int) -> void:
	var y := int(round((a_t.y + b_t.y) * 0.5))
	var x0 := int(round((a_t.x + b_t.x) * 0.5)) + left
	var x1 := int(round((a_t.x + b_t.x) * 0.5)) + right + width - 1
	for x in range(min(x0,x1), max(x0,x1)+1):
		var t := Vector2i(x, y)
		_place_tile(t, AT["STRAIGHT_H"]); _clear_collision_at(t)

# ---------- path e posa ----------
func _route_stair_step(a_t: Vector2i, b_t: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cur := a_t
	var sx := 1 if (a_t.x < b_t.x) else -1
	var sy := 1 if (a_t.y < b_t.y) else -1
	while cur.x != b_t.x:
		cur = Vector2i(cur.x + sx, cur.y); path.append(cur)
	while cur.y != b_t.y:
		cur = Vector2i(cur.x, cur.y + sy); path.append(cur)
	return path

func _lay_corridor_with_width(spine: Array[Vector2i], a_marker: Node, b_marker: Node) -> void:
	if spine.is_empty(): return
	var thickness :int= max(1, (a_marker as RoomConnector).corridor_height) if(a_marker is RoomConnector) else 1
	thickness = max(thickness, MIN_CORRIDOR_THICKNESS)
	var prev := spine[0]
	for i in spine.size():
		var p := spine[i]
		var dir := (p - prev)
		if dir == Vector2i.ZERO and i+1 < spine.size(): dir = spine[i+1] - p

		var bounds := _thickness_bounds(thickness)
		if abs(dir.x) > 0:
			for t in range(bounds.x, bounds.y + 1):
				var tt := Vector2i(p.x, p.y + t)
				_place_tile(tt, AT["STRAIGHT_H"]); _clear_collision_at(tt)
		else:
			for t in range(bounds.x, bounds.y + 1):
				var tt := Vector2i(p.x + t, p.y)
				_place_tile(tt, AT["STRAIGHT_V"]); _clear_collision_at(tt)

		if i > 0 and i < spine.size() - 1:
			var prev_dir := p - spine[i-1]
			var next_dir := spine[i+1] - p
			if prev_dir != next_dir: _place_corner(p, prev_dir, next_dir, thickness)
		prev = p

func _place_corner(p: Vector2i, d1: Vector2i, d2: Vector2i, thickness:int) -> void:
	var a := Vector2i(_sgn(d1.x), _sgn(d1.y))
	var b := Vector2i(_sgn(d2.x), _sgn(d2.y))
	var key := ""
	if a.x != 0 and b.y != 0:
		key = "CORNER_NE" if (a.x > 0 and b.y < 0) else "CORNER_NW" if (a.x < 0 and b.y < 0) else "CORNER_SE" if (a.x > 0 and b.y > 0) else "CORNER_SW"
	elif a.y != 0 and b.x != 0:
		key = "CORNER_NE" if(a.y < 0 and b.x > 0) else "CORNER_NW" if (a.y < 0 and b.x < 0) else "CORNER_SE" if (a.y > 0 and b.x > 0) else "CORNER_SW"
	if key != "":
		var bounds := _thickness_bounds(thickness)
		for t in range(bounds.x, bounds.y + 1):
			_place_tile(p, AT[key]); _clear_collision_at(p)

func _thickness_bounds(thickness:int) -> Vector2i:
	var left  := -int((thickness - 1) / 2)
	var right :=  int(thickness / 2)
	return Vector2i(left, right)

func _apply_caps_and_corners(spine:Array[Vector2i], a_marker: Node, b_marker: Node) -> void:
	var top_clear :int= max(0, (a_marker as RoomConnector).clearance_top) if (a_marker is RoomConnector) else 0
	var bot_clear :int= max(0, (a_marker as RoomConnector).clearance_bottom) if (a_marker is RoomConnector) else 0
	if top_clear == 0 and bot_clear == 0: return
	for p in spine:
		if bot_clear > 0: _place_tile(Vector2i(p.x, p.y + 1), AT["CAP_FLOOR"])
		if top_clear > 0: _place_tile(Vector2i(p.x, p.y - 1), AT["CAP_CEIL"])

func _sgn(v:int) -> int: return 1 if (v>0) else -1 if (v<0) else 0

func _open_entry_at(marker: Node, tile_pos: Vector2i, first_step_dir: Vector2i) -> void:
	var is_horizontal :bool= abs(first_step_dir.x) > 0  # il corridoio va in orizzontale fuori dalla stanza?

	# parametri dal marker se è un RoomConnector
	var up := 0
	var down := 0
	var left := 0
	var right := 0
	var thickness := MIN_CORRIDOR_THICKNESS
	if marker is RoomConnector:
		var rc := marker as RoomConnector
		up = rc.offset_up
		down = rc.offset_down
		left = rc.offset_left
		right = rc.offset_right
		thickness = max(MIN_CORRIDOR_THICKNESS, max(1, rc.corridor_height))

	if is_horizontal:
		# muro verticale (E/W) -> apri varco VERTICALE centrato sul marker
		var top := -up
		var bot :=  down
		var height := thickness  # spessore corridoio = “colonne” orizzontali, ma la porta è alta top..bot
		_carve_vertical_entry(tile_pos, top, bot, height)
	else:
		# muro orizzontale (N/S) -> apri varco ORIZZONTALE centrato sul marker
		var l := -left
		var r :=  right
		var width := thickness
		_carve_horizontal_entry(tile_pos, l, r, width)

func _carve_vertical_entry(center: Vector2i, top:int, bot:int, thickness:int) -> void:
	var x := center.x
	var y0 := center.y + top
	var y1 := center.y + bot + thickness - 1
	for y in range(min(y0,y1), max(y0,y1)+1):
		var t := Vector2i(x, y)
		_place_tile(t, AT["STRAIGHT_V"])
		_clear_collision_at(t)
		_clear_wall_at(t)

func _carve_horizontal_entry(center: Vector2i, left:int, right:int, thickness:int) -> void:
	var y := center.y
	var x0 := center.x + left
	var x1 := center.x + right + thickness - 1
	for x in range(min(x0,x1), max(x0,x1)+1):
		var t := Vector2i(x, y)
		_place_tile(t, AT["STRAIGHT_H"])
		_clear_collision_at(t)
		_clear_wall_at(t)

func _clear_wall_at(world_tile: Vector2i) -> void:
	# Scegli stanza A o B per vicinanza alla tile
	var da :int= abs(world_tile.x - _a_tile.x) + abs(world_tile.y - _a_tile.y)
	var db :int= abs(world_tile.x - _b_tile.x) + abs(world_tile.y - _b_tile.y)
	var wall_layer : TileMapLayer = _a_walls if da <= db else _b_walls
	if wall_layer:
		var mc := _worldtile_to_mapcoords(wall_layer, world_tile)
		wall_layer.set_cell(mc, -1, Vector2i.ZERO)

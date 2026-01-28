@tool
extends AutoMapLayer

const CORNER_OUT_NW := Vector2i(5, 6)
const CORNER_OUT_NE := Vector2i(7, 6) 
const CORNER_OUT_SW := Vector2i(5, 8) 
const CORNER_OUT_SE := Vector2i(7, 8) 
const CAP_NW := Vector2i(3, 8) 
const CAP_NE := Vector2i(1, 8) 
const CAP_SW := Vector2i(3, 6) 
const CAP_SE := Vector2i(1, 6)

const FLOOR_CEIL_WALL := [
	{"x": 20, "y": 2, "w": 5.0},
	{"x": 19, "y": 2, "w": 0.5},
	{"x": 18, "y": 2, "w": 0.5},
	{"x": 17, "y": 2, "w": 0.5},
	{"x": 16, "y": 2, "w": 0.5},
]

const INNER_WALL := [
	{"x": 18, "y": 3, "w": 5.0},
	{"x": 19, "y": 3, "w": 0.5},
	{"x": 20, "y": 3, "w": 0.5},
	{"x": 18, "y": 4, "w": 5.0},
	{"x": 19, "y": 4, "w": 0.5},
	{"x": 20, "y": 4, "w": 0.5},
	{"x": 12, "y": 4, "w": 5.0},
]

func get_tile(neighbors: Array[bool] = [false,false,false,false], coord: Vector2i = Vector2i.ZERO) -> Array:
	var N = neighbors[0]
	var E = neighbors[1]
	var S = neighbors[2]
	var W = neighbors[3]
	# diagonali (le leggi direttamente dal layout)
	var NW = tile_exists(layout, coord + Vector2i(-1, -1))
	var NE = tile_exists(layout, coord + Vector2i( 1, -1))
	var SW = tile_exists(layout, coord + Vector2i(-1,  1))
	var SE = tile_exists(layout, coord + Vector2i( 1,  1))
	
	if N and W and (not NW):
		return [CAP_NW.x, CAP_NW.y, 0]

	if N and E and (not NE):
		return [CAP_NE.x, CAP_NE.y, 0]

	if S and W and (not SW):
		return [CAP_SW.x, CAP_SW.y, 0]

	if S and E and (not SE):
		return [CAP_SE.x, CAP_SE.y, 0]
	
	# neighbors = [N,E,S,W]
	match neighbors:
		## Pavimento/bordi esterni
		[false, true, true, true]:
			var picked := weighted_pick(FLOOR_CEIL_WALL)
			return [picked["x"], picked["y"], 0]

		## Soffitto/bordi interni
		[true, true, false, true]:
			var picked := weighted_pick(FLOOR_CEIL_WALL)
			return [picked["x"], picked["y"], FV]
		
		## Muro destro
		[true, false, true, true]:
			var picked := weighted_pick(FLOOR_CEIL_WALL)
			return [picked["x"], picked["y"], FH + T]
		
		## Muro sinistro
		[true, true, true, false]:
			var picked := weighted_pick(FLOOR_CEIL_WALL)
			return [picked["x"], picked["y"], T]
		## Angoli esterni
		## NW
		[false, true, true, false]:
			return [CORNER_OUT_NW.x, CORNER_OUT_NW.y, 0]
		## NE
		[false, false, true, true]:
			return [CORNER_OUT_NE.x, CORNER_OUT_NE.y, 0]
		## SW
		[true, true, false, false]:
			return [CORNER_OUT_SW.x, CORNER_OUT_SW.y, 0]
		## SE
		[true, false, false, true]:
			return [CORNER_OUT_SE.x, CORNER_OUT_SE.y, 0]
			
		# fallback: se è un caso “strano”, riempi
		_:
			var picked := weighted_pick(INNER_WALL)
			return [picked["x"], picked["y"], 0]

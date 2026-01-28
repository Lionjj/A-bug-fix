@tool
extends AutoMapLayer

var up: bool = false
var left: bool = false
var right: bool = false
var down: bool = false

# lista decorazioni (atlas coords) - usa Dictionary così eviti problemi dei "const" e delle classi
var DECO_TOP := [
	# cable
	{"x": 16, "y": 7, "w": 0.06},
	{"x": 17, "y": 7, "w": 0.06},
	{"x": 18, "y": 7, "w": 0.06},
	{"x": 19, "y": 7, "w": 0.06},
	{"x": 20, "y": 7, "w": 0.06},
	{"x": 21, "y": 7, "w": 0.06},
	
	# pin-grass
	{"x": 17, "y": 1, "w": 0.06},
	{"x": 16, "y": 1, "w": 0.06},
	{"x": 18, "y": 1, "w": 0.06},
	{"x": 19, "y": 1, "w": 0.06},
	
	{"x": -1, "y": -1, "w": 0.4},
]

var DECO_CEIL := [
	{"x": 16, "y": 5, "w": 0.12},
	{"x": 17, "y": 5, "w": 0.12},
	{"x": 18, "y": 5, "w": 0.12},
	{"x": 19, "y": 5, "w": 0.12},
	{"x": 20, "y": 5, "w": 0.12},
	
	{"x": -1, "y": -1, "w": 0.4},
]

func get_tile(neighbors: Array[bool] = [false,false,false,false], coord: Vector2i = Vector2i.ZERO) -> Array:
	var picked_top:= weighted_pick(DECO_TOP)
	var picked_ceil:= weighted_pick(DECO_CEIL)
	match neighbors:
		
		## pavimento/contorno superiore
		[false, true, true, true]:
			up = true
			return [picked_top["x"], picked_top["y"], 0]
		
		## pavimento angolo destro
		[false, false, true, true]:
			up = true
			return [picked_top["x"], picked_top["y"], 0]
		
		## pavimento angolo sinistro
		[false, true, true, false]:
			up = true
			return [picked_top["x"], picked_top["y"], 0]
		
		## soffitto/contorno interno/inferiore
		[true, true, false, true]:
			down = true
			return [picked_ceil["x"], picked_ceil["y"], 0]
		
		## angolo destro inferiore
		[true, false, false, true]:
			down = true
			return [picked_ceil["x"], picked_ceil["y"], 0]
		
		## angolo sinistro inferiore
		[true, true, false, false]:
			down = true
			return [picked_ceil["x"], picked_ceil["y"], 0]

		## muro/contorno destro
		[true, false, true, true]:
			right = true
			return [picked_top["x"], picked_top["y"], T + FH]
		
		## muro/contorno sinistro
		[true, true, true, false]:
			left = true
			return [picked_top["x"], picked_top["y"], T]
		
		_:
			return[-1, -1, 0]

	return [-1, -1, 0]  # nessuna deco

func update():
	if !layout: return
	clear()
	if reroll_seed: randomize()
	if auto_align: global_position = layout.global_position + tile_set.tile_size * .5

	for coord in layout.get_used_cells():
		var neighbors: Array[bool] = get_neighbors(layout, coord)
		var tile_data = get_tile(neighbors, coord)
		if tile_data[0] < 0: 
			reset_flag()
			continue
		var offset : Vector2i = coord + applay_offset()
		
		set_cell(offset, source_id, Vector2i(tile_data[0], tile_data[1]), tile_data[2])


func applay_offset() -> Vector2i:
	var out: Vector2i = Vector2i.ZERO
	if up: out =  Vector2i.UP
	if down: out = Vector2i.DOWN
	if left: out = Vector2i.LEFT
	if right: out = Vector2i.RIGHT

	reset_flag()
	
	return out

func reset_flag() -> void:
	up = false
	down = false
	left = false
	right = false
	

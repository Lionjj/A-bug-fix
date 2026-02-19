# ============================================================================
# ConnectorOperator
# ============================================================================
## Operatore strutturale globale.
## - Genera connettori N/E/S/W
## - Carva il volume nella mask
## - Parametrico e mutabile
# ============================================================================

class_name ConnectorOperator
extends LayoutOperator

var profile: ConnectorProfile


# ------------------------------------------------------------
# Costruttore
# ------------------------------------------------------------

func _init(_context: OperatorContext, _params: Dictionary = {}) -> void:
	super(_context, _params)
	type = LayoutOperator.Type.CONNECTOR
	role = LayoutOperator.Role.PRIMARY
	weight = 1.0
	profile = ConnectorProfile.new()


# ------------------------------------------------------------
# APPLY
# ------------------------------------------------------------

func apply() -> bool:

	if not params.has("openings"):
		push_error("ConnectorOperator: params missing")
		return false
	
	var plan: ConnectorPlan = ConnectorPlan.new()
	
	var mask: RoomLayoutMask = context.mask
	var openings: Dictionary = params["openings"]

	for dir in openings.keys():

		var data: Dictionary = openings[dir]
		var coord: int = data["coord"]
		var width: int = data["width"]
		
		plan.set_opening(dir, coord, width)
	
	context.connector_plan = plan
	return true


# ------------------------------------------------------------
# RANDOM PARAMS
# ------------------------------------------------------------

func create_random_params() -> Dictionary:
	var mask: RoomLayoutMask = context.mask
	var rng: RandomNumberGenerator = context.rng

	var result: Dictionary = {
		#kay: dir (N, S, O, W) 
		#value: Dictionary 
		"openings": {}
	}

	for dir in Dir4.ORDER:

		var max_w := _max_width(dir)
		var width := rng.randi_range(profile.min_width_tiles, max_w)

		var bounds := _coord_bounds(dir, width)
		var coord := rng.randi_range(bounds.x, bounds.y)

		result["openings"][dir] = {
			"coord": coord,
			"width": width
		}

	return result



# ------------------------------------------------------------
# MUTATE PARAMS
# ------------------------------------------------------------

func mutate_params() -> void:

	if not params.has("openings"):
		return

	var openings: Dictionary = params["openings"]
	var rng: RandomNumberGenerator = context.rng
	var mask: RoomLayoutMask = context.mask

	var dir: int = Dir4.ORDER[rng.randi() % Dir4.ORDER.size()]
	var data: Dictionary = openings[dir]

	match rng.randi_range(0, 1):

		# ----------------------
		# WIDTH
		# ----------------------
		0:
			var max_w: int = _max_width(dir)

			data["width"] = clamp(
				data["width"] + rng.randi_range(-2, 2),
				profile.min_width_tiles,
				max_w
			)

		# ----------------------
		# COORD
		# ----------------------
		1:
			var bounds: Vector2i = _coord_bounds(dir, data["width"])

			data["coord"] = clamp(
				data["coord"] + rng.randi_range(-3, 3),
				bounds.x,
				bounds.y
			)

# ------------------------------------------------------------
# Helper
# ------------------------------------------------------------

func _useful_space(dir: int) -> int:
	var mask: RoomLayoutMask = context.mask
	
	var wall: int = mask.wall_thickness
	var margin: int = profile.corner_margin_tiles

	if dir == Dir4.D.N or dir == Dir4.D.S:
		return mask.size.x - 2 * (wall + margin)
	else:
		return mask.size.y - 2 * (wall + margin)


func _max_width(dir: int) -> int:
	var useful: int = _useful_space(dir)

	var ratio_width: int = int(useful * profile.max_width_ratio)
	var max_width: int = min(profile.max_width_abs, ratio_width)

	return max(max_width, profile.min_width_tiles)


func _coord_bounds(dir: int, width: int) -> Vector2i:
	var mask: RoomLayoutMask = context.mask
	
	var wall: int = mask.wall_thickness
	var margin: int = profile.corner_margin_tiles

	var min_c: int = wall + margin

	var max_c: int

	if dir == Dir4.D.N or dir == Dir4.D.S:
		max_c = mask.size.x - wall - margin - width
	else:
		max_c = mask.size.y - wall - margin - width

	return Vector2i(min_c, max_c)


# ------------------------------------------------------------
# CARVE
# ------------------------------------------------------------

func _carve(
	mask: RoomLayoutMask,
	dir: int,
	coord: int,
	width: int
) -> void:

	var wall: int = mask.wall_thickness

	match dir:

		Dir4.D.N:
			for x in range(coord, coord + width):
				for y in range(0, wall):
					if mask.in_bounds(x, y):
						mask.set_empty(x, y)

		Dir4.D.S:
			for x in range(coord, coord + width):
				for y in range(mask.size.y - wall, mask.size.y):
					if mask.in_bounds(x, y):
						mask.set_empty(x, y)

		Dir4.D.W:
			for y in range(coord, coord + width):
				for x in range(0, wall):
					if mask.in_bounds(x, y):
						mask.set_empty(x, y)

		Dir4.D.E:
			for y in range(coord, coord + width):
				for x in range(mask.size.x - wall, mask.size.x):
					if mask.in_bounds(x, y):
						mask.set_empty(x, y)

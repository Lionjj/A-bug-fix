# ============================================================================
# RoomLayoutMask
# ============================================================================
## Maschera logica stanza (celle): muri/vuoti + piano connettori (debug).
# ============================================================================

class_name RoomLayoutMask
extends RefCounted


var wall_thickness: int
var size: Vector2i
var solid: PackedByteArray
var rng: RandomNumberGenerator
var context: LayoutContext

var walkable_cells: Array[Vector2i]
var empty_cells: Array[Vector2i]


func _init(_context: LayoutContext) -> void:
	context = _context
	size = context.size
	rng = context.rng
	wall_thickness = context.size_profile.wall_thickness
	solid = PackedByteArray()
	solid.resize(size.x * size.y)
	solid.fill(1)
	
	walkable_cells = _get_all_walckable_cell()
	empty_cells = _get_all_empty_cells()
	
	#_seed_base()


# ---------------------------------------------------------------------------
# Utility interne
# ---------------------------------------------------------------------------

func _idx(x: int, y: int) -> int:
	return y * size.x + x

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size.x and y < size.y


# ---------------------------------------------------------------------------
# Query
# ---------------------------------------------------------------------------

func is_solid(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return true
	return solid[_idx(x, y)] == 1

func get_all_solid_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []

	for y in range(size.y):
		for x in range(size.x):
			if not is_solid(x, y):
				continue
				
			out.append(Vector2i(x, y))

	return out

func is_empty(x: int, y: int) -> bool:
	return not is_solid(x, y)

## Ritorna tutte le celle EMPTY della maschera.[br]
##
## Utile per:[br]
## - flood fill[br]
## - verifica connettività[br]
## - analisi topologica
func _get_all_empty_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []

	for y in range(size.y):
		for x in range(size.x):
			if not is_empty(x, y):
				continue
				
			out.append(Vector2i(x, y))

	return out


func _get_all_walckable_cell() -> Array[Vector2i]:

	var floors: Array[Vector2i] = []

	for y in range(size.y):
		for x in range(size.x):

			var p := Vector2i(x, y)

			if _is_floor(p):
				floors.append(p)

	return floors


func _is_floor(p: Vector2i) -> bool:

	if not in_bounds(p.x, p.y):
		return false

	if is_solid(p.x, p.y):
		return false

	var below := p + Vector2i.DOWN

	return in_bounds(below.x, below.y) and is_solid(below.x, below.y)


# ---------------------------------------------------------------------------
# Mutatori
# ---------------------------------------------------------------------------

func set_solid(x: int, y: int) -> void:
	if not in_bounds(x, y):
		return
	solid[_idx(x, y)] = 1

func set_empty(x: int, y: int) -> void:
	if not in_bounds(x, y):
		return
	solid[_idx(x, y)] = 0


# ---------------------------------------------------------------------------
# Debug ASCII
# ---------------------------------------------------------------------------

## '#' muro, '.' vuoto
func to_ascii() -> String:
	var lines: Array[String] = []

	for y in range(size.y):
		var line := ""
		for x in range(size.x):
			line += "#" if is_solid(x, y) else "."
		lines.append(line)

	return "\n".join(lines)


# ---------------------------------------------------------------------------
# Costruisci una stanza valida
# ---------------------------------------------------------------------------


## Crea una stanza base sempre valida:
## - perimetro solido
## - interno vuoto
func _seed_base() -> void:
	var w: int = size.x
	var h: int = size.y

	for y in range(h):
		for x in range(w):
			var is_border: bool = (
				x < wall_thickness or
				y < wall_thickness or
				x >= w - wall_thickness or
				y >= h - wall_thickness
			)

			if is_border:
				set_solid(x, y)
			else:
				set_empty(x, y)


# ---------------------------------------------------------------------------
# Duplica la mask
# ---------------------------------------------------------------------------

func duplicate() -> RoomLayoutMask:
	var copy: RoomLayoutMask = RoomLayoutMask.new(context)

	copy.size = size
	copy.wall_thickness = wall_thickness

	# Copia profonda dell'array
	copy.solid = solid.duplicate()

	return copy

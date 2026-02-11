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

func _init(context: LayoutContext) -> void:
	size = context.size
	wall_thickness = context.size_profile.wall_thickness
	solid = PackedByteArray()
	solid.resize(size.x * size.y)
	solid.fill(1)
	
	_seed_base()


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

func is_empty(x: int, y: int) -> bool:
	return not is_solid(x, y)

## Ritorna tutte le celle EMPTY della maschera.[br]
##
## Utile per:[br]
## - flood fill[br]
## - verifica connettività[br]
## - analisi topologica
func get_all_empty_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []

	for y in range(size.y):
		for x in range(size.x):
			if is_empty(x, y):
				out.append(Vector2i(x, y))

	return out

func pick_spawn() -> Vector2i:
	var center: Vector2i = Vector2i(size.x / 2, size.y / 2)
	if is_empty(center.x, center.y):
		return center

	var empties: Array[Vector2i] = get_all_empty_cells()
	if empties.is_empty():
		return Vector2i(-1, -1)

	return empties[0]


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

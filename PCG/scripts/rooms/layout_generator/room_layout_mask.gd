# ============================================================================
# RoomLayoutMask
# ============================================================================
## Maschera logica stanza (celle): muri/vuoti + piano connettori (debug).
# ============================================================================

class_name RoomLayoutMask
extends RefCounted

@export var wall_thickness: int = 3

var size: Vector2i
var solid: PackedByteArray

## Piano connettori (risultato OpeningPolicy / Rules)
var connector_plan: ConnectorPlan = null


func _init(sz: Vector2i) -> void:
	size = sz
	solid = PackedByteArray()
	solid.resize(size.x * size.y)
	solid.fill(1) # default: tutto muro


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

## Debug: ASCII con i connettori marcati sul bordo
## - '#' muro
## - '.' vuoto
## - 'N','E','S','W' = celle bordo coperte dal varco
func to_ascii_with_connectors() -> String:
	var lines: Array[String] = []

	# 1) griglia base
	for y in range(size.y):
		var line := ""
		for x in range(size.x):
			line += "#" if is_solid(x, y) else "."
		lines.append(line)

	if connector_plan == null:
		return "\n".join(lines)

	# 2) overlay varchi (N,E,S,W) - ordine stabile
	for d in Dir4.ORDER:
		if not connector_plan.is_enabled(d):
			continue

		var c: int = connector_plan.get_coord(d)
		var w: int = connector_plan.get_width(d)

		for cell: Vector2i in _connector_cells(d, c, w):
			if not in_bounds(cell.x, cell.y):
				continue
			var ch := _dir_char(d)
			var row: String = lines[cell.y]
			lines[cell.y] = row.substr(0, cell.x) + ch + row.substr(cell.x + 1)

	return "\n".join(lines)


func _dir_char(d: int) -> String:
	match d:
		Dir4.D.N: return "N"
		Dir4.D.E: return "E"
		Dir4.D.S: return "S"
		Dir4.D.W: return "W"
		_: return "?"


## Celle del bordo coperte dal varco:
## - N/S: coord = X centrale
## - E/W: coord = Y centrale
func _connector_cells(d: int, coord: int, width_tiles: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []

	var w: int = max(4, width_tiles)
	var neg: int = w / 2
	var pos: int = w - neg

	match d:
		Dir4.D.N:
			var y: int = 0
			for dx in range(-neg, pos):
				out.append(Vector2i(coord + dx, y))

		Dir4.D.S:
			var y: int = size.y - 1
			for dx in range(-neg, pos):
				out.append(Vector2i(coord + dx, y))

		Dir4.D.W:
			var x: int = 0
			for dy in range(-neg, pos):
				out.append(Vector2i(x, coord + dy))

		Dir4.D.E:
			var x: int = size.x - 1
			for dy in range(-neg, pos):
				out.append(Vector2i(x, coord + dy))

	return out

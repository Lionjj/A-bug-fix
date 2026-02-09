# ============================================================================
# ConnectivityOperator
# ============================================================================
# Garantisce la connettività delle aree EMPTY aprendo il minor numero
# possibile di celle SOLID.
# ============================================================================

extends RefCounted
class_name ConnectivityOperator

const DIRS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT
]

const INVALID_CELL := Vector2i(-1, -1)

# ---------------------------------------------------------------------------
# API pubblica
# ---------------------------------------------------------------------------
func apply(mask: RoomLayoutMask) -> void:
	var regions: Array[Array] = _find_empty_regions(mask)
	if regions.size() <= 1:
		return

	var main_region: Array[Vector2i] = _pick_main_region(regions)

	for region: Array[Vector2i] in regions:
		if region == main_region:
			continue

		var wall_pos: Vector2i = _find_minimal_connection(mask, region, main_region)
		if wall_pos != INVALID_CELL:
			mask.set_empty(wall_pos.x, wall_pos.y)

# ---------------------------------------------------------------------------
# STEP 1 — Flood fill delle regioni EMPTY
# ---------------------------------------------------------------------------
func _find_empty_regions(mask: RoomLayoutMask) -> Array[Array]:
	var visited: Dictionary = {}
	var regions: Array[Array] = []

	for y: int in range(mask.size.y):
		for x: int in range(mask.size.x):
			var p := Vector2i(x, y)

			if mask.is_solid(x, y):
				continue
			if visited.has(p):
				continue

			var region: Array[Vector2i] = []
			_flood_fill(mask, p, visited, region)
			regions.append(region)

	return regions


func _flood_fill(
	mask: RoomLayoutMask,
	start: Vector2i,
	visited: Dictionary,
	out_region: Array[Vector2i]
) -> void:
	var stack: Array[Vector2i] = [start]
	visited[start] = true

	while not stack.is_empty():
		var current: Vector2i = stack.pop_back()
		out_region.append(current)

		for d: Vector2i in DIRS:
			var nx: int = current.x + d.x
			var ny: int = current.y + d.y
			var n := Vector2i(nx, ny)

			if not mask.in_bounds(nx, ny):
				continue
			if mask.is_solid(nx, ny):
				continue
			if visited.has(n):
				continue

			visited[n] = true
			stack.append(n)

# ---------------------------------------------------------------------------
# STEP 2 — Regione principale (più grande)
# ---------------------------------------------------------------------------
func _pick_main_region(regions: Array[Array]) -> Array[Vector2i]:
	var best: Array[Vector2i] = regions[0]

	for region: Array[Vector2i] in regions:
		if region.size() > best.size():
			best = region

	return best

# ---------------------------------------------------------------------------
# STEP 3 — Trova il muro minimo da aprire
# ---------------------------------------------------------------------------
func _find_minimal_connection(
	mask: RoomLayoutMask,
	from_region: Array[Vector2i],
	to_region: Array[Vector2i]
) -> Vector2i:
	var to_set: Dictionary = {}
	for p: Vector2i in to_region:
		to_set[p] = true

	for cell: Vector2i in from_region:
		for d: Vector2i in DIRS:
			var wx: int = cell.x + d.x
			var wy: int = cell.y + d.y
			var bx: int = wx + d.x
			var by: int = wy + d.y

			if not mask.in_bounds(bx, by):
				continue
			if not mask.is_solid(wx, wy):
				continue

			var beyond := Vector2i(bx, by)
			if to_set.has(beyond):
				return Vector2i(wx, wy)

	return INVALID_CELL

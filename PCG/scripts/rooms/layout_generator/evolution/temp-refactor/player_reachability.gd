class_name PlayerReachability
extends RefCounted


# ==========================================================
# PLAYER STATE
# ==========================================================

enum PlayerState {
	SURFACE,   # floor o wall
	AIR
}


# ==========================================================
# INTERNAL NODE
# ==========================================================

class ReachNode:
	var pos: Vector2i
	var state: int

	func _init(p: Vector2i, s: int) -> void:
		pos = p
		state = s

	func key() -> String:
		return str(pos) + "_" + str(state)


# ==========================================================
# PUBLIC API
# ==========================================================

static func has_path(
	mask: RoomLayoutMask,
	profile: PlayerTraversalProfile,
	start: Vector2i,
	target_cells: Array
) -> bool:
	return not find_path(mask, profile, start, target_cells).is_empty()


static func find_path(
	mask: RoomLayoutMask,
	profile: PlayerTraversalProfile,
	start: Vector2i,
	target_cells: Array
) -> Array[Vector2i]:

	var result: Dictionary = _bfs(mask, profile, start, target_cells)
	var path: Array = result["path"]
	if path.is_empty(): return []
	return result["path"]


static func can_reach_all_floor_tiles(
	mask: RoomLayoutMask, 
	profile: PlayerTraversalProfile
) -> bool:
	var floors: Array[Vector2i] = mask.walkable_cells
	if floors.is_empty():
		return true

	var start: Vector2i = floors[0]
	
	# Trovo il punto più, in questo modo mi garantisce che se c'è una via per
	# salire c'è anche per scendere.
	for f in floors:
		if f.y <= start.y:
			continue
		start = f

	var bfs_result: Dictionary = _bfs(
		mask,
		profile,
		start,
		[]  # nessun target → esplora tutto
	)

	var visited: Dictionary = bfs_result["visited"]

	for f in floors:
		var key_surface = [f, PlayerState.SURFACE]
		var key_air = [f, PlayerState.AIR]

		if not visited.has(key_surface) and not visited.has(key_air):
			return false

	return true


# ==========================================================
# BFS CORE (multi-target)
# ==========================================================

static func _bfs(
	mask: RoomLayoutMask,
	profile: PlayerTraversalProfile,
	start: Vector2i,
	target_cells: Array
) -> Dictionary:

	var has_targets := not target_cells.is_empty()
	var target_set := {}

	if has_targets:
		for t in target_cells:
			target_set[t] = true

	var start_state: int = _resolve_state(mask, start)
	var start_node := ReachNode.new(start, start_state)

	var queue: Array[ReachNode] = [start_node]
	var head: int = 0

	var visited := {}
	var parent := {}

	visited[[start, start_state]] = true

	while head < queue.size():

		var current: ReachNode = queue[head]
		head += 1

		if has_targets and target_set.has(current.pos):
			return {
				"path": _reconstruct(parent, current),
				"visited": visited,
				"parent": parent
			}

		for next in _expand(mask, profile, current):

			var key = [next.pos, next.state]

			if visited.has(key):
				continue

			visited[key] = true
			parent[key] = current
			queue.append(next)

	return {
		"path": [],
		"visited": visited,
		"parent": parent
	}



# ==========================================================
# MOVEMENT MODEL
# ==========================================================

static func _expand(
	mask: RoomLayoutMask,
	profile: PlayerTraversalProfile,
	node: ReachNode
) -> Array[ReachNode]:

	var result: Array[ReachNode] = []
	var p: Vector2i = node.pos

	match node.state:

		# --------------------------------------
		# SURFACE
		# --------------------------------------
		PlayerState.SURFACE:

			# WALK
			for dir in [Vector2i.LEFT, Vector2i.RIGHT]:
				var n: Vector2i = p + dir
				if _is_valid(mask, n):
					result.append(
						ReachNode.new(n, _resolve_state(mask, n))
					)

			# START JUMP (permissivo ma controllato)
			for dy in range(-profile.max_jump_tiles, 1):
				for dx in range(-profile.max_jump_tiles, profile.max_jump_tiles + 1):

					if dx == 0 and dy == 0:
						continue

					if abs(dy) > profile.max_jump_tiles:
						continue

					var n: Vector2i = p + Vector2i(dx, dy)

					if not _is_valid(mask, n):
						continue

					if _air_path_clear(mask, p, n):
						result.append(
							ReachNode.new(n, PlayerState.AIR)
						)

		# --------------------------------------
		# AIR
		# --------------------------------------
		PlayerState.AIR:

			# FALL
			var below: Vector2i = p + Vector2i.DOWN
			if _is_valid(mask, below):
				result.append(
					ReachNode.new(below, _resolve_state(mask, below))
				)

			# AIR CONTROL
			for dir in [Vector2i.LEFT, Vector2i.RIGHT]:
				var n: Vector2i = p + dir
				if _is_valid(mask, n):
					result.append(
						ReachNode.new(n, PlayerState.AIR)
					)

	return result


# ==========================================================
# STATE RESOLUTION
# ==========================================================

static func _resolve_state(mask: RoomLayoutMask, p: Vector2i) -> int:

	if _is_floor(mask, p):
		return PlayerState.SURFACE

	if _is_wall_adjacent(mask, p):
		return PlayerState.SURFACE

	return PlayerState.AIR


# ==========================================================
# VALIDATION
# ==========================================================

static func _is_valid(mask: RoomLayoutMask, p: Vector2i) -> bool:

	if not mask.in_bounds(p.x, p.y):
		return false

	if mask.is_solid(p.x, p.y):
		return false

	var above: Vector2i = p + Vector2i.UP
	if mask.in_bounds(above.x, above.y) and mask.is_solid(above.x, above.y):
		return false

	return true


static func _is_floor(mask: RoomLayoutMask, p: Vector2i) -> bool:
	var below: Vector2i = p + Vector2i.DOWN
	return mask.in_bounds(below.x, below.y) and mask.is_solid(below.x, below.y)


static func _is_wall_adjacent(mask: RoomLayoutMask, p: Vector2i) -> bool:

	var left: Vector2i = p + Vector2i.LEFT
	var right: Vector2i = p + Vector2i.RIGHT

	return (
		mask.in_bounds(left.x, left.y) and mask.is_solid(left.x, left.y)
	) or (
		mask.in_bounds(right.x, right.y) and mask.is_solid(right.x, right.y)
	)


# ==========================================================
# AIR PATH CHECK
# ==========================================================

static func _air_path_clear(
	mask: RoomLayoutMask,
	a: Vector2i,
	b: Vector2i
) -> bool:

	var steps: int = max(abs(b.x - a.x), abs(b.y - a.y))

	for i in range(1, steps + 1):

		var x: int = a.x + int((b.x - a.x) * float(i) / steps)
		var y: int = a.y + int((b.y - a.y) * float(i) / steps)

		var p := Vector2i(x, y)

		if not _is_valid(mask, p):
			return false

	return true


# ==========================================================
# PATH RECONSTRUCTION
# ==========================================================

static func _reconstruct(
	parent: Dictionary,
	end_node: ReachNode
) -> Array[Vector2i]:

	var path: Array[Vector2i] = []
	var current: ReachNode = end_node

	while parent.has(current.key()):
		path.append(current.pos)
		current = parent[current.key()]

	path.append(current.pos)
	path.reverse()

	return path


# ==========================================================
# DEBUG ASCII
# ==========================================================

static func debug_draw_path(
	mask: RoomLayoutMask,
	path: Array[Vector2i]
) -> String:

	if path.is_empty():
		return "NO PATH"

	var grid: Array = []

	for y in range(mask.size.y):
		var row: Array[String] = []
		for x in range(mask.size.x):
			row.append("#" if mask.is_solid(x, y) else ".")
		grid.append(row)

	var start: Vector2i = path[0]

	for p in path:
		if mask.in_bounds(p.x, p.y):
			grid[p.y][p.x] = "█"

	grid[start.y][start.x] = "S"

	var lines: Array[String] = []
	for y in range(mask.size.y):
		lines.append("".join(grid[y]))

	return "\n".join(lines)


# ==========================================================
# CONNECTOR VOLUME TARGETS
# ==========================================================

static func get_connector_volume_cells(
	mask: RoomLayoutMask,
	plan: ConnectorPlan,
	dir: int
) -> Array[Vector2i]:

	var result: Array[Vector2i] = []
	var wall: int = mask.wall_thickness
	var coord: int = plan.get_coord(dir)
	var width: int = plan.get_width(dir)

	match dir:

		Dir4.D.N:
			for x in range(coord, coord + width):
				for y in range(0, wall):
					if mask.is_empty(x, y):
						result.append(Vector2i(x, y))

		Dir4.D.S:
			for x in range(coord, coord + width):
				for y in range(mask.size.y - wall, mask.size.y):
					if mask.is_empty(x, y):
						result.append(Vector2i(x, y))

		Dir4.D.W:
			for y in range(coord, coord + width):
				for x in range(0, wall):
					if mask.is_empty(x, y):
						result.append(Vector2i(x, y))

		Dir4.D.E:
			for y in range(coord, coord + width):
				for x in range(mask.size.x - wall, mask.size.x):
					if mask.is_empty(x, y):
						result.append(Vector2i(x, y))

	return result


# ==========================================================
# CARVE CONNECTOR VOLUME (for temp validation mask)
# ==========================================================

static func carve_connector_volume(
	mask: RoomLayoutMask,
	plan: ConnectorPlan,
	dir: int
) -> void:

	var wall: int = mask.wall_thickness
	var coord: int = plan.get_coord(dir)
	var width: int = plan.get_width(dir)

	match dir:

		# ---------------- NORTH ----------------
		Dir4.D.N:
			for x in range(coord, coord + width):
				for y in range(0, wall):
					if mask.in_bounds(x, y):
						mask.set_empty(x, y)

		# ---------------- SOUTH ----------------
		Dir4.D.S:
			for x in range(coord, coord + width):
				for y in range(mask.size.y - wall, mask.size.y):
					if mask.in_bounds(x, y):
						mask.set_empty(x, y)

		# ---------------- WEST ----------------
		Dir4.D.W:
			for y in range(coord, coord + width):
				for x in range(0, wall):
					if mask.in_bounds(x, y):
						mask.set_empty(x, y)

		# ---------------- EAST ----------------
		Dir4.D.E:
			for y in range(coord, coord + width):
				for x in range(mask.size.x - wall, mask.size.x):
					if mask.in_bounds(x, y):
						mask.set_empty(x, y)

# ==========================================================
# SCEGLIERE LO START
# ==========================================================

static func get_connector_entry_cell(
	mask: RoomLayoutMask,
	plan: ConnectorPlan,
	dir: int
) -> Vector2i:

	var wall: int = mask.wall_thickness
	var coord: int = plan.get_coord(dir)
	var width: int = plan.get_width(dir)

	match dir:

		Dir4.D.N:
			var y := wall
			for x in range(coord, coord + width):
				if mask.is_empty(x, y):
					return Vector2i(x, y)

		Dir4.D.S:
			var y := mask.size.y - wall - 1
			for x in range(coord, coord + width):
				if mask.is_empty(x, y):
					return Vector2i(x, y)

		Dir4.D.W:
			var x := wall
			for y in range(coord, coord + width):
				if mask.is_empty(x, y):
					return Vector2i(x, y)

		Dir4.D.E:
			var x := mask.size.x - wall - 1
			for y in range(coord, coord + width):
				if mask.is_empty(x, y):
					return Vector2i(x, y)

	return Vector2i(-1, -1)

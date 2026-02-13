# ============================================================================
# TraversalAnalyzer
# ============================================================================
class_name TraversalAnalyzer
extends RefCounted


# ============================================================================
# API
# ============================================================================

static func analyze(
	mask: RoomLayoutMask,
	profile: PlayerTraversalProfile,
	spawn: Vector2i
) -> TraversalResult:

	if not _is_standable(mask, spawn):
		return null

	var reachable := _forward_reach(mask, profile, spawn)
	var returnable := _backward_reach(mask, profile, spawn, reachable)

	return TraversalResult.new(reachable, returnable)


# ============================================================================
# FORWARD REACH
# ============================================================================

static func _forward_reach(
	mask: RoomLayoutMask,
	profile: PlayerTraversalProfile,
	spawn: Vector2i
) -> Dictionary[Vector2i, bool]:

	var visited: Dictionary[Vector2i, bool] = {}
	var queue: Array[Vector2i] = [spawn]
	visited[spawn] = true

	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()

		for nxt in _possible_moves(mask, profile, cur):
			if visited.has(nxt):
				continue
			visited[nxt] = true
			queue.append(nxt)

	return visited


# ============================================================================
# BACKWARD REACH
# ============================================================================

static func _backward_reach(
	mask: RoomLayoutMask,
	profile: PlayerTraversalProfile,
	spawn: Vector2i,
	reachable: Dictionary[Vector2i, bool]
) -> Dictionary[Vector2i, bool]:

	var returnable: Dictionary[Vector2i, bool] = {}
	var queue: Array[Vector2i] = [spawn]
	returnable[spawn] = true

	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()

		for prev in _reverse_moves(mask, profile, cur):
			if not reachable.has(prev):
				continue
			if returnable.has(prev):
				continue
			returnable[prev] = true
			queue.append(prev)

	return returnable


# ============================================================================
# POSSIBLE MOVES (FORWARD)
# ============================================================================

static func _possible_moves(
	mask: RoomLayoutMask,
	profile: PlayerTraversalProfile,
	pos: Vector2i
) -> Array[Vector2i]:

	var out: Array[Vector2i] = []

	# ------------------------------------------------
	# 1) Camminata orizzontale
	# ------------------------------------------------
	for dir in [Vector2i.LEFT, Vector2i.RIGHT]:
		var p: Vector2i = pos + dir
		if _is_standable(mask, p):
			out.append(p)

	# ------------------------------------------------
	# 2) Caduta (sempre consentita)
	# ------------------------------------------------
	var fall_pos: Vector2i = pos
	var fall_count: int = 0

	while fall_count < profile.max_fall_tiles:
		var next: Vector2i = fall_pos + Vector2i.DOWN
		if not _is_empty(mask, next):
			break
		fall_pos = next
		fall_count += 1

	if fall_pos != pos:
		if _is_standable(mask, fall_pos):
			out.append(fall_pos)


	# ------------------------------------------------
	# 3) Salto verticale libero
	# ------------------------------------------------
	for dy in range(1, profile.max_jump_tiles + 1):
		var p := pos + Vector2i(0, -dy)

		if not _is_empty(mask, p):
			break

		out.append(p)

	# ------------------------------------------------
	# 4) Climb infinito su muro
	# ------------------------------------------------
	if profile.can_climb:
		for side in [Vector2i.LEFT, Vector2i.RIGHT]:
			var wall: Vector2i = pos + side

			if _is_wall(mask, wall):
				var climb_pos := pos

				while true:
					climb_pos += Vector2i.UP
					if not _is_empty(mask, climb_pos):
						break
					out.append(climb_pos)

	# ------------------------------------------------
	# 5) Wall jump chain
	# ------------------------------------------------
	if profile.can_wall_jump:
		for side in [Vector2i.LEFT, Vector2i.RIGHT]:
			if _is_wall(mask, pos + side):

				for dy in range(1, profile.wall_jump_tiles + 1):
					var p := pos + Vector2i(-side.x, -dy)

					if not _is_empty(mask, p):
						break

					out.append(p)

	return out


# ============================================================================
# REVERSE MOVES (SIMMETRICO)
# ============================================================================

static func _reverse_moves(
	mask: RoomLayoutMask,
	profile: PlayerTraversalProfile,
	pos: Vector2i
) -> Array[Vector2i]:

	var out: Array[Vector2i] = []

	# ------------------------------------------------
	# 1) Inverso camminata
	# ------------------------------------------------
	for dir in [Vector2i.LEFT, Vector2i.RIGHT]:
		var p: Vector2i = pos + dir
		if _is_standable(mask, p):
			out.append(p)

	# ------------------------------------------------
	# 2) Inverso salto (cioè caduta dall'alto)
	# ------------------------------------------------
	for dy in range(1, profile.max_jump_tiles + 1):
		var p := pos + Vector2i(0, dy)

		if not _is_empty(mask, p):
			break

		out.append(p)

	# ------------------------------------------------
	# 3) Reverse climb infinito
	# ------------------------------------------------
	if profile.can_climb:
		for side in [Vector2i.LEFT, Vector2i.RIGHT]:
			var wall: Vector2i = pos + side

			if _is_wall(mask, wall):
				var down_pos := pos

				while true:
					down_pos += Vector2i.DOWN
					if not _is_empty(mask, down_pos):
						break
					out.append(down_pos)

	# ------------------------------------------------
	# 4) Reverse wall jump
	# ------------------------------------------------
	if profile.can_wall_jump:
		for side in [Vector2i.LEFT, Vector2i.RIGHT]:
			for dy in range(1, profile.wall_jump_tiles + 1):
				var p := pos + Vector2i(side.x, dy)

				if not _is_empty(mask, p):
					break

				out.append(p)

	return out


# ============================================================================
# GEOMETRY HELPERS
# ============================================================================

static func _is_empty(mask: RoomLayoutMask, p: Vector2i) -> bool:
	return mask.in_bounds(p.x, p.y) and mask.is_empty(p.x, p.y)

static func _is_wall(mask: RoomLayoutMask, p: Vector2i) -> bool:
	return mask.in_bounds(p.x, p.y) and mask.is_solid(p.x, p.y)

static func _is_standable(mask: RoomLayoutMask, p: Vector2i) -> bool:
	if not _is_empty(mask, p):
		return false

	var below := p + Vector2i.DOWN
	return mask.in_bounds(below.x, below.y) and mask.is_solid(below.x, below.y)

static func _evaluate_traversal(
	mask: RoomLayoutMask,
	plan: ConnectorPlan,
) -> float:
	var profile: PlayerTraversalProfile = PlayerTraversalProfile.new()

	var spawn_points := {}

	for d in Dir4.ORDER:
		spawn_points[d] = _internal_spawn(mask, plan, d)

	var first_dir = Dir4.ORDER[0]

	var result := TraversalAnalyzer.analyze(
		mask,
		profile,
		spawn_points[first_dir]
	)

	if result == null:
		return -1

	# Verifica raggiungibilità bidirezionale
	for d in Dir4.ORDER:
		print("from:", d , "to", spawn_points[d])
		if not result.reachable.has(spawn_points[d]):
			return -1
		#if not result.returnable.has(spawn_points[d]):
			#return -1

	# --------------------------------------------------
	# Scoring traversal avanzato
	# --------------------------------------------------

	var reach_ratio := float(result.reachable.size()) / float(mask.get_all_empty_cells().size())

	# penalizza stanze troppo banali (100% trivial reach)
	var diversity_bonus :float= 1.0 - abs(reach_ratio - 0.75)

	return reach_ratio * 10.0 + diversity_bonus * 5.0

static func _internal_spawn(
	mask: RoomLayoutMask,
	plan: ConnectorPlan,
	dir: int
) -> Vector2i:

	var wall := mask.wall_thickness
	var coord := plan.get_coord(dir)

	match dir:

		Dir4.D.N:
			return Vector2i(coord, wall)

		Dir4.D.S:
			return Vector2i(coord, mask.size.y - wall - 1)

		Dir4.D.W:
			return Vector2i(wall, coord)

		Dir4.D.E:
			return Vector2i(mask.size.x - wall - 1, coord)

	return Vector2i(-1, -1)

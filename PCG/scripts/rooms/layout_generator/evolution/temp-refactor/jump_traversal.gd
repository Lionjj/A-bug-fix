# ============================================================================
# JumpTraversal
# ============================================================================
## Implementazione pura del modello del paper.
##
## Movimento astratto:
## - Floor tile = empty con solid sotto
## - Il player può:
##     - Saltare fino a max_jump_tiles verticali
##     - Muoversi orizzontalmente 1 tile per tile verticale
## - Deve esserci headroom
## - Il percorso in aria deve essere EMPTY
##
## Non simula fisica.
## Non usa wall jump.
## Non usa climb.
# ============================================================================

class_name JumpTraversal
extends RefCounted


# ============================================================================
# API PUBBLICA
# ============================================================================

static func build_jump_graph(
	mask: RoomLayoutMask,
	profile: PlayerTraversalProfile
) -> Dictionary[Vector2i, Array]:
	# Ritorna:
	# Dictionary[Vector2i, Array[Vector2i]]
	# Nodo = floor tile
	# Edge = salto possibile

	var floors: Array[Vector2i] = _collect_floor_tiles(mask)
	var graph: Dictionary[Vector2i, Array] = {}

	for a in floors:
		graph[a] = []

		for b in floors:
			if a == b:
				continue
			
			if _can_walk(a, b):
				graph[a].append(b)
				continue
			
			if _can_fall(mask, profile, a, b):
				graph[a].append(b)
				continue
			
			var is_valid: bool = _can_jump(mask, profile, a, b) or _can_wall_jump(mask, profile, a, b)
			
			if is_valid:
				graph[a].append(b)

	return graph


static func is_fully_connected(graph: Dictionary[Vector2i, Array]) -> bool:

	if graph.is_empty():
		return false

	var start: Vector2i = graph.keys()[0]
	var visited: Dictionary[Vector2i, bool] = {}
	var queue: Array[Vector2i]= [start]
	visited[start] = true

	while not queue.is_empty():
		var cur = queue.pop_front()

		for nxt in graph[cur]:
			if visited.has(nxt):
				continue

			visited[nxt] = true
			queue.append(nxt)


	return visited.size() == graph.size()


# ============================================================================
# FLOOR TILE
# ============================================================================

static func _collect_floor_tiles(mask: RoomLayoutMask) -> Array[Vector2i]:

	var floors: Array[Vector2i] = []

	for y in range(mask.size.y):
		for x in range(mask.size.x):

			var p := Vector2i(x, y)

			if _is_floor(mask, p):
				floors.append(p)

	return floors


static func _is_floor(mask: RoomLayoutMask, p: Vector2i) -> bool:

	if not mask.in_bounds(p.x, p.y):
		return false

	if mask.is_solid(p.x, p.y):
		return false

	var below := p + Vector2i.DOWN

	return mask.in_bounds(below.x, below.y) and mask.is_solid(below.x, below.y)


# ============================================================================
# CONTROLLO MURO
# ============================================================================

static func _is_wall_adjacent(
	mask: RoomLayoutMask,
	p: Vector2i
) -> bool:

	var left := p + Vector2i.LEFT
	var right := p + Vector2i.RIGHT

	if mask.in_bounds(left.x, left.y) and mask.is_solid(left.x, left.y):
		return true

	if mask.in_bounds(right.x, right.y) and mask.is_solid(right.x, right.y):
		return true

	return false


# ============================================================================
# CONTROLLO ARIA + HEADROOM
# ============================================================================

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

		# deve essere empty
		if not mask.in_bounds(p.x, p.y):
			return false

		if mask.is_solid(p.x, p.y):
			return false

		# headroom (1 tile sopra)
		var above := p + Vector2i.UP
		if not mask.in_bounds(above.x, above.y):
			return false

		if mask.is_solid(above.x, above.y):
			return false

	return true


# ============================================================================
# Movimenti
# ============================================================================
static func _can_walk(
	a: Vector2i,
	b: Vector2i
) -> bool:
	return abs(a.x - b.x) == 1 and a.y == b.y
	
	
static func _can_jump(
	mask: RoomLayoutMask,
	profile: PlayerTraversalProfile,
	a: Vector2i,
	b: Vector2i
) -> bool:

	var dy: int = b.y - a.y
	var dx: int = b.x - a.x

	# 1) Limite verticale
	if abs(dy) > profile.max_jump_tiles:
		return false

	# 2) 1 tile orizzontale per tile verticale
	# abs(dx) <= abs(dy)
	if abs(dx) > abs(dy):
		return false

	# 3) Percorso in aria deve essere empty
	if not _air_path_clear(mask, a, b):
		return false
	
	return true


static func _can_wall_jump(	
	mask: RoomLayoutMask,
	profile: PlayerTraversalProfile,
	a: Vector2i,
	b: Vector2i
) -> bool:
	
	if not profile.can_wall_jump:
		return false
	
	# Se il punto di partenza è più alto non puo salire
	if a.y <= b.y:
		return false
	
	var dy: int = b.y - a.y
	var dx: int = b.x - a.x
	
	var steps: int = abs(dy)
	
	for i in range(1, steps + 1):
		var p := Vector2i(a.x, a.y - i)
		
		if not _is_wall_adjacent(mask, p):
			return false
		
		if not  mask.in_bounds(p.x, p.y):
			return false
		
		if mask.is_solid(p.x, p.y) and not _can_overcome(mask, profile, p):
			return false	
	
	return true


static func _can_fall(
	mask: RoomLayoutMask,
	profile: PlayerTraversalProfile,
	a: Vector2i,
	b: Vector2i
) -> bool:

	# deve essere sotto
	if b.y <= a.y:
		return false
	
	var dy: int = b.y - a.y
	var dx: int = b.x - a.x
	
	if abs(dx) > 1:
		return false
	
	var start: int = a.x + dx
	
	for step in range(1, dy + 1):
		var p := Vector2i(start, a.y + step)
		
		if not  mask.in_bounds(p.x, p.y):
			return false
		
		if mask.is_solid(p.x, p.y):
			return false
	
	return _is_floor(mask, b)


static func _can_overcome(mask: RoomLayoutMask, profile: PlayerTraversalProfile, p: Vector2i) -> bool:
	var offset_counted: int = 0
	
	var left: Vector2i = p + Vector2i.LEFT
	var right: Vector2i = p + Vector2i.RIGHT
	
	while mask.in_bounds(left.x, left.y) or mask.in_bounds(right.x, right.y):
		offset_counted += 1
		left.x += -1
		right.x += 1
	
	return offset_counted <= profile.wall_jump_horizontal_tiles
	

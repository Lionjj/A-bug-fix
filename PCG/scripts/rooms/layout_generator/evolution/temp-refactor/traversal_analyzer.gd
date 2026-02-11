# ============================================================================
# TraversalAnalyzer
# ============================================================================
## Analizza una RoomLayoutMask tenendo conto delle REALI capacità del player.
##
## OBIETTIVO:
## - Determinare quali celle sono:
##   - raggiungibili
##   - da cui il player può TORNARE indietro
##
## DIFFERENZA CHIAVE rispetto a BFS classico:
## - NON tutte le discese sono valide
## - Una cella è valida SOLO se il player può:
##   - arrivarci
##   - risalire (direttamente o indirettamente)
##
## FILOSOFIA:
## - Analisi discreta (tile-based)
## - Nessuna simulazione fisica frame-based
## - Fail-first: se una regola fallisce → movimento non consentito
# ============================================================================

class_name TraversalAnalyzer
extends RefCounted


# ---------------------------------------------------------------------------
# API pubblica
# ---------------------------------------------------------------------------

## Calcola la mappa di raggiungibilità e ritorno.
##
## Ritorna un Dictionary:
## {
##   reachable : Dictionary[Vector2i, bool],
##   returnable: Dictionary[Vector2i, bool]
## }
##
static func analyze(
	mask: RoomLayoutMask,
	profile: PlayerTraversalProfile,
	spawn: Vector2i
) -> TraversalResult:

	# Fail-first: spawn non valido
	if not mask.in_bounds(spawn.x, spawn.y):
		return null
	if not mask.is_empty(spawn.x, spawn.y):
		return null

	var reachable: Dictionary[Vector2i, bool] = _forward_reach(mask, profile, spawn)
	var returnable: Dictionary[Vector2i, bool] = _backward_reach(mask, profile, spawn, reachable)

	return TraversalResult.new(
		reachable,
		returnable
	)


# ---------------------------------------------------------------------------
# Forward reach (posso ARRIVARCI?)
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Backward reach (posso TORNARE INDIETRO?)
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# MOSSE POSSIBILI (player-aware)
# ---------------------------------------------------------------------------

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
	var fall := pos + Vector2i.DOWN
	if _is_empty(mask, fall):
		out.append(fall)

	# ------------------------------------------------
	# 3) Salto verticale
	# ------------------------------------------------
	for dy in range(1, profile.max_jump_tiles + 1):
		var p := pos + Vector2i(0, -dy)
		if not _is_empty(mask, p):
			break
		if _has_ground(mask, p):
			out.append(p)

	# ------------------------------------------------
	# 4) Wall jump
	# ------------------------------------------------
	if profile.can_wall_jump:
		for side in [Vector2i.LEFT, Vector2i.RIGHT]:
			if _is_wall(mask, pos + side):
				for dy in range(1, profile.wall_jump_tiles + 1):
					var p := pos + Vector2i(-side.x, -dy)
					if not _is_empty(mask, p):
						break
					if _has_ground(mask, p):
						out.append(p)

	return out


# ---------------------------------------------------------------------------
# MOSSE INVERSE (posso arrivare QUI da dove?)
# ---------------------------------------------------------------------------

static func _reverse_moves(
	mask: RoomLayoutMask,
	profile: PlayerTraversalProfile,
	pos: Vector2i
) -> Array[Vector2i]:

	var out: Array[Vector2i] = []

	# Inverso della camminata
	for dir in [Vector2i.LEFT, Vector2i.RIGHT]:
		var p: Vector2i = pos + dir
		if _is_standable(mask, p):
			out.append(p)

	# Inverso del salto = caduta
	for dy in range(1, profile.max_jump_tiles + 1):
		var p := pos + Vector2i(0, dy)
		if _is_empty(mask, p):
			out.append(p)

	# Inverso del wall jump
	if profile.can_wall_jump:
		for side in [Vector2i.LEFT, Vector2i.RIGHT]:
			for dy in range(1, profile.wall_jump_tiles + 1):
				var p := pos + Vector2i(side.x, dy)
				if _is_empty(mask, p):
					out.append(p)

	return out


# ---------------------------------------------------------------------------
# Utility geometriche
# ---------------------------------------------------------------------------

static func _is_empty(mask: RoomLayoutMask, p: Vector2i) -> bool:
	return mask.in_bounds(p.x, p.y) and mask.is_empty(p.x, p.y)

static func _has_ground(mask: RoomLayoutMask, p: Vector2i) -> bool:
	var below := p + Vector2i.DOWN
	return mask.in_bounds(below.x, below.y) and mask.is_solid(below.x, below.y)

static func _is_standable(mask: RoomLayoutMask, p: Vector2i) -> bool:
	return _is_empty(mask, p) and _has_ground(mask, p)

static func _is_wall(mask: RoomLayoutMask, p: Vector2i) -> bool:
	return mask.in_bounds(p.x, p.y) and mask.is_solid(p.x, p.y)

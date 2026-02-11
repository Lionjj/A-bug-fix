# ============================================================================
# LayoutValidator
# ============================================================================
## Verifica se un layout è GIOCABILE (fail-first).
# ============================================================================

class_name LayoutValidator
extends RefCounted

const W_TRAVERSAL: float = 4.0

static func validate(mask: RoomLayoutMask) -> LayoutValidatorContext:
	var out: LayoutValidatorContext = LayoutValidatorContext.new(0.0, false)
	if mask == null:
		return out
	if mask.size.x <= 0 or mask.size.y <= 0:
		return out

	var spawn: Vector2i = mask.pick_spawn()
	if not mask.in_bounds(spawn.x, spawn.y):
		return out
	if not mask.is_empty(spawn.x, spawn.y):
		return out

	var profile: PlayerTraversalProfile = PlayerTraversalProfile.new()
	var traversal: TraversalResult = TraversalAnalyzer.analyze(mask, profile, spawn)

	if traversal.reachable.is_empty() or traversal.returnable.is_empty() :
		return out

	var empty_cells: Array[Vector2i] = _mask_attach_empty(mask)
	var traversal_score: float = _traversal_score(empty_cells, traversal)

	if traversal_score <= 0.0:
		return out
	
	out.is_valid = true
	out.score = traversal_score * W_TRAVERSAL
	return out

# ---------------------------------------------------------------------------
# METRICHE
# ---------------------------------------------------------------------------

## Quanto spazio è:[br]
## - raggiungibile[br]
## - e da cui si può tornare indietro[br]
static func _traversal_score(
	empty_cells: Array[Vector2i],
	traversal: TraversalResult
) -> float:

	var reachable: Dictionary[Vector2i, bool] = traversal.reachable
	var returnable: Dictionary[Vector2i, bool] = traversal.returnable

	var total: int = empty_cells.size()
	if total == 0:
		return 0.0

	var good: float = 0.0
	for p in empty_cells:
		if reachable.has(p) and returnable.has(p):
			good += 1.0

	return good / float(total)


# ---------------------------------------------------------------------------
# UTILITY
# ---------------------------------------------------------------------------

static func _mask_attach_empty(mask: RoomLayoutMask) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(mask.size.y):
		for x in range(mask.size.x):
			if mask.is_empty(x, y):
				out.append(Vector2i(x, y))
	return out

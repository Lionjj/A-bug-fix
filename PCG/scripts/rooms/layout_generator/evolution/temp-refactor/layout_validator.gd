# ============================================================================
# LayoutValidator
# ============================================================================
## Verifica se un layout è GIOCABILE
##
## RESPONSABILITÀ:
## - Validare la stanza secondo il player reale
## - Garantire assenza di isole inutili
## - Garantire spawn sensato
##
## FILOSOFIA:
## - Fail-first
## - Hard constraints prima dello scoring
# ============================================================================

class_name LayoutValidator
extends RefCounted


# ---------------------------------------------------------------------------
# PESI
# ---------------------------------------------------------------------------

const W_TRAVERSAL: float = 2.5


# ---------------------------------------------------------------------------
# SOGLIE DI VALIDAZIONE
# ---------------------------------------------------------------------------

## Percentuale minima di spazio realmente giocabile
const MIN_PLAYABLE_RATIO: float = 0.65

## Percentuale minima di spazio connesso al componente principale
const MIN_CONNECTED_RATIO: float = 0.70


# ---------------------------------------------------------------------------
# ENTRY POINT
# ---------------------------------------------------------------------------

static func validate(mask: RoomLayoutMask) -> LayoutValidatorContext:
	
	#print(mask.to_ascii())

	var out := LayoutValidatorContext.new(0.0, false)

	# ------------------------------------------------------------
	# Controlli base
	# ------------------------------------------------------------

	if mask == null:
		return out

	if mask.size.x <= 0 or mask.size.y <= 0:
		return out

	# ------------------------------------------------------------
	# Validazione spawn
	# ------------------------------------------------------------

	var spawn := mask.pick_spawn()

	if not mask.in_bounds(spawn.x, spawn.y):
		return out

	if not mask.is_empty(spawn.x, spawn.y):
		return out

	# Spawn deve avere spazio sopra
	if not _has_headroom(mask, spawn):
		return out

	# Spawn non deve essere incastrato ai bordi
	if _is_near_border(mask, spawn):
		return out

	# ------------------------------------------------------------
	# Analisi traversal
	# ------------------------------------------------------------

	var profile := PlayerTraversalProfile.new()
	var traversal := TraversalAnalyzer.analyze(mask, profile, spawn)
	

	if traversal.reachable.is_empty():
		return out

	#if traversal.returnable.is_empty():
		#return out

	var empty_cells := _collect_empty_cells(mask)
	if empty_cells.is_empty():
		return out

	# ------------------------------------------------------------
	# Metriche strutturali
	# ------------------------------------------------------------

	#var playable_ratio := _playable_ratio(empty_cells, traversal)
	
	#print("reachable:", traversal.reachable.size())
	#print("returnable:", traversal.returnable.size())
	#print("empty:", empty_cells.size())
	#print("ratio:", playable_ratio)

	#if playable_ratio < MIN_PLAYABLE_RATIO:
		#return out

	var connected_ratio := float(traversal.reachable.size()) / float(empty_cells.size())

	if connected_ratio < MIN_CONNECTED_RATIO:
		return out

	# ------------------------------------------------------------
	# Layout valido
	# ------------------------------------------------------------

	out.is_valid = true
	out.score = connected_ratio * W_TRAVERSAL
	return out


# ============================================================================
# METRICHE
# ============================================================================

## Percentuale di celle:
## - raggiungibili
## - e da cui si può tornare indietro
static func _playable_ratio(
	empty_cells: Array[Vector2i],
	traversal: TraversalResult
) -> float:

	var reachable := traversal.reachable
	var returnable := traversal.returnable

	var total := empty_cells.size()
	if total == 0:
		return 0.0

	var valid := 0.0

	for p in empty_cells:
		if reachable.has(p) and returnable.has(p):
			valid += 1.0

	return valid / float(total)


# ============================================================================
# SPAWN VALIDATION
# ============================================================================

static func _has_headroom(mask: RoomLayoutMask, pos: Vector2i) -> bool:
	var above := pos + Vector2i.UP
	if not mask.in_bounds(above.x, above.y):
		return false
	return mask.is_empty(above.x, above.y)


static func _is_near_border(mask: RoomLayoutMask, pos: Vector2i) -> bool:
	const BORDER_MARGIN: int = 1

	return (
		pos.x <= BORDER_MARGIN or
		pos.x >= mask.size.x - 1 - BORDER_MARGIN or
		pos.y <= BORDER_MARGIN or
		pos.y >= mask.size.y - 1 - BORDER_MARGIN
	)


# ============================================================================
# UTILITY
# ============================================================================

static func _collect_empty_cells(mask: RoomLayoutMask) -> Array[Vector2i]:
	var out: Array[Vector2i] = []

	for y in range(mask.size.y):
		for x in range(mask.size.x):
			if mask.is_empty(x, y):
				out.append(Vector2i(x, y))

	return out

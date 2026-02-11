# ============================================================================
# LayoutScorer
# ============================================================================
## Valuta la qualità di un layout generato.
##
## OBIETTIVO:
## - Assegnare uno score numerico a una RoomLayoutMask
## - Scartare layout non giocabili secondo il PLAYER REALE
##
## FILOSOFIA:
## - Nessuna decisione binaria se non necessaria
## - Fail-first per layout rotti
## - Metriche continue (0.0 → 1.0)
##
## NOTE DI DESIGN:
## - Stateless
## - NON modifica la mask
## - NON conosce gli operatori
## - Player-aware tramite TraversalAnalyzer
# ============================================================================

class_name LayoutScorer
extends RefCounted


# ---------------------------------------------------------------------------
# PESI GLOBALI
# ---------------------------------------------------------------------------

const W_TRAVERSAL: float = 4.0
const W_SOLID_DENSITY: float = 1.5
const W_VERTICALITY: float = 1.0
const W_SYMMETRY: float = 2.0

const IDEAL_SOLID_RATIO: float = 0.30


# ---------------------------------------------------------------------------
# ENTRY POINT
# ---------------------------------------------------------------------------

static func score(mask: RoomLayoutMask) -> float:
	var spawn: Vector2i = mask.pick_spawn()

	var density: float = _solid_density(mask)
	var vertical: float = _verticality(mask)
	var symmetry: float = _symmetry_penalty(mask)

	var score: float = 0.0
	score += density * W_SOLID_DENSITY
	score += vertical * W_VERTICALITY
	score -= symmetry * W_SYMMETRY

	return score


# ---------------------------------------------------------------------------
# METRICHE
# ---------------------------------------------------------------------------


## Penalizza stanze troppo vuote o troppo piene
static func _solid_density(mask: RoomLayoutMask) -> float:
	var total: int = mask.size.x * mask.size.y
	if total <= 0:
		return 0.0

	var solid: float = 0.0
	for y in range(mask.size.y):
		for x in range(mask.size.x):
			if mask.is_solid(x, y):
				solid += 1.0

	var ratio: float = solid / float(total)
	var diff: float = abs(ratio - IDEAL_SOLID_RATIO)

	return clamp(1.0 - diff * 3.0, 0.0, 1.0)


## Quanto spazio verticale è realmente sfruttabile
static func _verticality(mask: RoomLayoutMask) -> float:
	var min_y: float = INF
	var max_y: float = -INF

	for y in range(mask.size.y):
		for x in range(mask.size.x):
			if mask.is_empty(x, y):
				min_y = min(min_y, y)
				max_y = max(max_y, y)

	if min_y == INF:
		return 0.0

	var span: float = max_y - min_y
	return clamp(span / float(mask.size.y), 0.0, 1.0)


## Penalizza layout troppo simmetrici
static func _symmetry_penalty(mask: RoomLayoutMask) -> float:
	var mid_x: int = mask.size.x / 2
	if mid_x <= 0:
		return 0.0

	var mismatches: float = 0.0
	var checks: float = 0.0

	for y in range(mask.size.y):
		for x in range(mid_x):
			var a: bool = mask.is_solid(x, y)
			var b: bool = mask.is_solid(mask.size.x - 1 - x, y)
			checks += 1.0
			if a != b:
				mismatches += 1.0

	if checks <= 0.0:
		return 0.0

	return 1.0 - (mismatches / checks)

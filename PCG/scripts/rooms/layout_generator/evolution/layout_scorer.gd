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
	var articulation: float = _articulation(mask)
	var concavity: float = _concavity(mask)
	var flatness: float = _flatness(mask)

	var score: float = 0.0
	## Aspetti positivi
	score += density * W_SOLID_DENSITY
	score += vertical * W_VERTICALITY
	score += articulation * 2.5
	score += concavity * 2.0
	
	## Aspetti negativi
	score -= symmetry * W_SYMMETRY
	score -= flatness * 3.0


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


static func _articulation(mask: RoomLayoutMask) -> float:
	var transitions: float = 0.0
	var checks: float = 0.0
	
	for y in range(mask.size.y):
		for x in range(mask.size.x - 1):
			if mask.is_solid(x, y) != mask.is_solid(x + 1, y):
				transitions += 1.0
			checks += 1.0

	if checks == 0:
		return 0.0
	
	return clamp(transitions / checks, 0.0, 1.0)


static func _concavity(mask: RoomLayoutMask) -> float:
	var concave: float = 0.0
	
	for y in range(1, mask.size.y - 1):
		for x in range(1, mask.size.x - 1):
			if mask.is_empty(x, y):
				var solids: int = 0
				if mask.is_solid(x+1, y): solids += 1
				if mask.is_solid(x-1, y): solids += 1
				if mask.is_solid(x, y+1): solids += 1
				if mask.is_solid(x, y-1): solids += 1
				
				if solids >= 3:
					concave += 1
	
	return clamp(concave / 200.0, 0.0, 1.0)


static func _flatness(mask: RoomLayoutMask) -> float:
	var total_penalty: float = 0.0
	var max_width: int = mask.size.x
	
	if max_width <= 0:
		return 0.0
	
	for y in range(mask.size.y):
		var current_run: int = 0
		
		for x in range(mask.size.x):
			if mask.is_solid(x, y):
				current_run += 1
			else:
				if current_run > 0:
					total_penalty += _flat_run_penalty(current_run, max_width)
					current_run = 0
		
		# fine riga
		if current_run > 0:
			total_penalty += _flat_run_penalty(current_run, max_width)
	
	# normalizzazione
	return clamp(total_penalty / float(mask.size.y), 0.0, 1.0)
	
	
static func _flat_run_penalty(run: int, max_width: int) -> float:
	var ratio: float = run / float(max_width)
	
	# Penalizza solo se segmento supera il 40% della larghezza
	if ratio < 0.4:
		return 0.0
	
	# Penalità quadratica (più lungo → cresce forte)
	return ratio * ratio

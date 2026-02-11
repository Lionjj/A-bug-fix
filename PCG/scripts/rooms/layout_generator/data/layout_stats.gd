# ============================================================================
# LayoutStats
# ============================================================================
## Raccolta di metriche oggettive su una RoomLayoutMask.
##
## OBIETTIVO:
## - Descrivere un layout in modo numerico
## - Nessuna decisione, nessun punteggio
##
## FILOSOFIA:
## - Solo misure, niente giudizi
## - Tutti i valori sono normalizzati o confrontabili
## - Stateless: una mask → uno snapshot di dati
##
## QUESTO FILE:
## ✔ serve al Generator
## ✔ serve allo Scorer
## ✔ serve all’EvolutionEngine
## ✘ NON filtra
## ✘ NON modifica la mask
# ============================================================================

class_name LayoutStats
extends RefCounted


# ---------------------------------------------------------------------------
# Dati grezzi
# ---------------------------------------------------------------------------

var size: Vector2i

var total_cells: int
var solid_cells: int
var empty_cells: int

var solid_ratio: float        # solid / totale
var empty_ratio: float

# ---------------------------------------------------------------------------
# Connettività
# ---------------------------------------------------------------------------

var reachable_empty: int
var reachable_ratio: float    # celle vuote raggiungibili / celle vuote totali

# ---------------------------------------------------------------------------
# Spazialità
# ---------------------------------------------------------------------------

var min_empty_y: int
var max_empty_y: int
var vertical_span: int
var vertical_ratio: float     # span / height

# ---------------------------------------------------------------------------
# Geometria utile
# ---------------------------------------------------------------------------

var narrow_passages: int      # quante zone < min_passage_tiles
var isolated_pockets: int    # pocket chiuse (0 ideale)

# ---------------------------------------------------------------------------
# Simmetria
# ---------------------------------------------------------------------------

var symmetry_mismatch_ratio: float   # 0 = perfetta simmetria, 1 = caos totale


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

static func compute(
	mask: RoomLayoutMask,
	min_passage_tiles: int = 4
) -> LayoutStats:
	
	var spawn: Vector2i = mask.pick_spawn()
	var profile: PlayerTraversalProfile = PlayerTraversalProfile.new()
	var stats := LayoutStats.new()

	# ------------------------------------------------------------
	# Base
	# ------------------------------------------------------------

	stats.size = mask.size
	stats.total_cells = mask.size.x * mask.size.y
	stats.solid_cells = 0
	stats.empty_cells = 0

	for y in range(mask.size.y):
		for x in range(mask.size.x):
			if mask.is_solid(x, y):
				stats.solid_cells += 1
			else:
				stats.empty_cells += 1

	stats.solid_ratio = float(stats.solid_cells) / float(stats.total_cells)
	stats.empty_ratio = 1.0 - stats.solid_ratio

	# ------------------------------------------------------------
	# Reachability
	# ------------------------------------------------------------

	var reach_map := TraversalAnalyzer.analyze(mask, profile, spawn)
	stats.reachable_empty = 0

	for y in range(mask.size.y):
		for x in range(mask.size.x):
			if mask.is_empty(x, y) and reach_map.has(Vector2i(x, y)):
				stats.reachable_empty += 1

	stats.reachable_ratio = (
		float(stats.reachable_empty) / float(stats.empty_cells)
		if stats.empty_cells > 0 else 0.0
	)

	# ------------------------------------------------------------
	# Verticalità reale
	# ------------------------------------------------------------

	stats.min_empty_y = INF
	stats.max_empty_y = -INF

	for y in range(mask.size.y):
		for x in range(mask.size.x):
			if mask.is_empty(x, y):
				stats.min_empty_y = min(stats.min_empty_y, y)
				stats.max_empty_y = max(stats.max_empty_y, y)

	if stats.min_empty_y == INF:
		stats.vertical_span = 0
		stats.vertical_ratio = 0.0
	else:
		stats.vertical_span = stats.max_empty_y - stats.min_empty_y
		stats.vertical_ratio = float(stats.vertical_span) / float(mask.size.y)

	# ------------------------------------------------------------
	# Passaggi stretti (anti-giocabilità)
	# ------------------------------------------------------------

	stats.narrow_passages = 0

	for y in range(mask.size.y):
		for x in range(mask.size.x):
			if mask.is_solid(x, y):
				continue

			var span_x := _span_empty_x(mask, x, y)
			var span_y := _span_empty_y(mask, x, y)

			if min(span_x, span_y) < min_passage_tiles:
				stats.narrow_passages += 1

	# ------------------------------------------------------------
	# Simmetria verticale
	# ------------------------------------------------------------

	var mid_x := mask.size.x / 2
	var mismatches := 0
	var checks := 0

	for y in range(mask.size.y):
		for x in range(mid_x):
			var a := mask.is_solid(x, y)
			var b := mask.is_solid(mask.size.x - 1 - x, y)
			checks += 1
			if a != b:
				mismatches += 1

	stats.symmetry_mismatch_ratio = (
		float(mismatches) / float(checks)
		if checks > 0 else 0.0
	)

	return stats


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _span_empty_x(mask: RoomLayoutMask, x: int, y: int) -> int:
	var a := x
	while a - 1 >= 0 and mask.is_empty(a - 1, y):
		a -= 1
	var b := x
	while b + 1 < mask.size.x and mask.is_empty(b + 1, y):
		b += 1
	return b - a + 1


static func _span_empty_y(mask: RoomLayoutMask, x: int, y: int) -> int:
	var a := y
	while a - 1 >= 0 and mask.is_empty(x, a - 1):
		a -= 1
	var b := y
	while b + 1 < mask.size.y and mask.is_empty(x, b + 1):
		b += 1
	return b - a + 1

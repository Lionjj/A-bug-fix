# ============================================================================
# RingOperator
# ============================================================================
## Crea un anello solido interno alla stanza con almeno un accesso.[br]
##
## Responsabilità:[br]
## - Costruire un ring solido interno.[br]
## - Aprire almeno un varco di accesso.[br]
## - Garantire la connettività globale.[br]
##
## Garanzie:[br]
## - NON tocca i bordi stanza.[br]
## - NON crea zone irraggiungibili.[br]
## - Rispetta i solidi già presenti.[br]
##
## Ordine consigliato nella pipeline:[br]
## Divider → Indent → Platform → Ring → Connector → Score
# ============================================================================

class_name RingOperator
extends LayoutOperator


# ---------------------------------------------------------------------------
# Policy
# ---------------------------------------------------------------------------

const BORDER_MARGIN := 3
const RING_OFFSET := 4
const RING_THICKNESS := 3

## larghezza del varco nel ring
const GATE_WIDTH := 4

## numero minimo e massimo di accessi
const MIN_GATES := 1
const MAX_GATES := 2


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func apply(mask: RoomLayoutMask, rng: RandomNumberGenerator) -> bool:
	var changed: Array[Vector2i] = []

	# ------------------------------------------------------------
	# Calcolo bounds ring
	# ------------------------------------------------------------

	var x0 := BORDER_MARGIN + RING_OFFSET
	var y0 := BORDER_MARGIN + RING_OFFSET
	var x1 := mask.size.x - BORDER_MARGIN - RING_OFFSET
	var y1 := mask.size.y - BORDER_MARGIN - RING_OFFSET

	if x1 - x0 <= RING_THICKNESS * 2:
		return false
	if y1 - y0 <= RING_THICKNESS * 2:
		return false

	# ------------------------------------------------------------
	# Costruzione ring pieno
	# ------------------------------------------------------------

	var rects := [
		# top
		Rect2i(Vector2i(x0, y0), Vector2i(x1 - x0, RING_THICKNESS)),
		# bottom
		Rect2i(Vector2i(x0, y1 - RING_THICKNESS), Vector2i(x1 - x0, RING_THICKNESS)),
		# left
		Rect2i(Vector2i(x0, y0), Vector2i(RING_THICKNESS, y1 - y0)),
		# right
		Rect2i(Vector2i(x1 - RING_THICKNESS, y0), Vector2i(RING_THICKNESS, y1 - y0))
	]

	for r in rects:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if mask.is_solid(x, y):
					continue
				changed.append(Vector2i(x, y))
				mask.set_solid(x, y)

	# ------------------------------------------------------------
	# Apertura accessi nel ring
	# ------------------------------------------------------------

	var gate_count := rng.randi_range(MIN_GATES, MAX_GATES)

	for _i in range(gate_count):
		_open_random_gate(mask, rng, x0, y0, x1, y1, changed)
		
	return true


# ---------------------------------------------------------------------------
# Apertura varchi
# ---------------------------------------------------------------------------

func _open_random_gate(
	mask: RoomLayoutMask,
	rng: RandomNumberGenerator,
	x0: int,
	y0: int,
	x1: int,
	y1: int,
	changed: Array[Vector2i]
) -> void:

	var side := rng.randi_range(0, 3) # 0=N 1=S 2=W 3=E

	match side:
		0: # NORTH
			var x := rng.randi_range(x0 + RING_THICKNESS, x1 - RING_THICKNESS - GATE_WIDTH)
			_carve_rect(mask,
				Rect2i(Vector2i(x, y0), Vector2i(GATE_WIDTH, RING_THICKNESS)),
				changed)

		1: # SOUTH
			var x := rng.randi_range(x0 + RING_THICKNESS, x1 - RING_THICKNESS - GATE_WIDTH)
			_carve_rect(mask,
				Rect2i(Vector2i(x, y1 - RING_THICKNESS), Vector2i(GATE_WIDTH, RING_THICKNESS)),
				changed)

		2: # WEST
			var y := rng.randi_range(y0 + RING_THICKNESS, y1 - RING_THICKNESS - GATE_WIDTH)
			_carve_rect(mask,
				Rect2i(Vector2i(x0, y), Vector2i(RING_THICKNESS, GATE_WIDTH)),
				changed)

		3: # EAST
			var y := rng.randi_range(y0 + RING_THICKNESS, y1 - RING_THICKNESS - GATE_WIDTH)
			_carve_rect(mask,
				Rect2i(Vector2i(x1 - RING_THICKNESS, y), Vector2i(RING_THICKNESS, GATE_WIDTH)),
				changed)


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

func _carve_rect(mask: RoomLayoutMask, rect: Rect2i, changed: Array[Vector2i]) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if mask.is_solid(x, y):
				changed.append(Vector2i(x, y))
				mask.set_empty(x, y)

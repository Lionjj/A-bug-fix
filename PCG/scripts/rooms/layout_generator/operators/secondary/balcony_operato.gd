# ============================================================================
# BalconyOperator
# ============================================================================
## Operatore SECONDARIO che scava una camera laterale
## a partire da un corridoio esistente.
##
## RESPONSABILITÀ:
## - Individuare una cella EMPTY del backbone
## - Scegliere un lato valido
## - Scavare una stanza rettangolare connessa
##
## NON FA:
## - Non modifica il perimetro
## - Non rompe la connettività primaria
## ============================================================================

class_name BalconyOperator
extends LayoutOperator


func _init() -> void:
	#type = Type.DEFAULT
	weight = 0.35
	role = Role.SECONDARY


# ---------------------------------------------------------------------------
# APPLY
# ---------------------------------------------------------------------------

func apply(
	mask: RoomLayoutMask,
	context: LayoutContext,
	params: Dictionary = {}
) -> bool:

	var rng: RandomNumberGenerator = context.rng

	var width: int = params.get("balcony_width", 6)
	var height: int = params.get("balcony_height", 4)

	var corridor_cells := mask.get_all_empty_cells()
	if corridor_cells.is_empty():
		return false

	var attempts := 25

	while attempts > 0:
		attempts -= 1

		var pivot: Vector2i = corridor_cells[rng.randi() % corridor_cells.size()]

		var dir := _pick_valid_direction(mask, pivot, rng)
		if dir == Vector2i.ZERO:
			continue

		if _try_carve_balcony(mask, pivot, dir, width, height):
			return true

	return false


# ---------------------------------------------------------------------------
# TROVA DIREZIONE VALIDA
# ---------------------------------------------------------------------------

static func _pick_valid_direction(
	mask: RoomLayoutMask,
	pos: Vector2i,
	rng: RandomNumberGenerator
) -> Vector2i:

	var dirs = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN
	]

	dirs.shuffle()

	for d in dirs:
		var p :Vector2i	= pos + d
		if mask.in_bounds(p.x, p.y) and mask.is_solid(p.x, p.y):
			return d

	return Vector2i.ZERO


# ---------------------------------------------------------------------------
# SCAVO BALCONE
# ---------------------------------------------------------------------------

static func _try_carve_balcony(
	mask: RoomLayoutMask,
	origin: Vector2i,
	dir: Vector2i,
	width: int,
	height: int
) -> bool:

	var wall := mask.wall_thickness

	var rect: Rect2i

	match dir:

		Vector2i.LEFT:
			rect = Rect2i(
				Vector2i(origin.x - width, origin.y - height/2),
				Vector2i(width, height)
			)

		Vector2i.RIGHT:
			rect = Rect2i(
				Vector2i(origin.x + 1, origin.y - height/2),
				Vector2i(width, height)
			)

		Vector2i.UP:
			rect = Rect2i(
				Vector2i(origin.x - width/2, origin.y - height),
				Vector2i(width, height)
			)

		Vector2i.DOWN:
			rect = Rect2i(
				Vector2i(origin.x - width/2, origin.y + 1),
				Vector2i(width, height)
			)

		_:
			return false


	# ------------------------------------------------------------------
	# VALIDAZIONE
	# ------------------------------------------------------------------

	# 1) Non deve toccare il perimetro
	if rect.position.x < wall:
		return false
	if rect.position.y < wall:
		return false
	if rect.end.x >= mask.size.x - wall:
		return false
	if rect.end.y >= mask.size.y - wall:
		return false

	# 2) Deve scavare SOLO solid
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not mask.in_bounds(x, y):
				return false
			if not mask.is_solid(x, y):
				return false


	# ------------------------------------------------------------------
	# SCAVO
	# ------------------------------------------------------------------

	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			mask.set_empty(x, y)

	return true

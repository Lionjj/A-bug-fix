# ============================================================================
# BackboneOperator
# ============================================================================
## Operatore strutturale principale.
##
## RESPONSABILITÀ:
## - Costruire la struttura portante interna della stanza.
## - Collegare i connettori tramite corridoi.
## - Definire la macro-topologia del layout.
##
## STRATEGIE SUPPORTATE:
## - CENTRAL      → tutti convergono a un pivot centrale
## - LINEAR       → collegamenti sequenziali
## - MULTI_PIVOT  → doppio hub con smistamento
##
## Questo operatore:
## - Modifica direttamente la mask
## - Deve essere applicato DOPO il ConnectorOperator
# ============================================================================

class_name BackboneOperator
extends LayoutOperator


# ----------------------------------------------------------------------------
# METADATI STATICI
# ----------------------------------------------------------------------------

static func get_weight() -> float:
	return 1.0


# ----------------------------------------------------------------------------
# MODALITÀ STRUTTURALI
# ----------------------------------------------------------------------------

enum Mode {
	CENTRAL,
	LINEAR,
	MULTI_PIVOT
}


# ----------------------------------------------------------------------------
# COSTRUTTORE
# ----------------------------------------------------------------------------

func _init(_context: OperatorContext, _params: Dictionary = {}):
	super(_context, _params)
	type = Type.BACKBONE


# ----------------------------------------------------------------------------
# APPLY
# ----------------------------------------------------------------------------

func apply() -> bool:

	# Backbone richiede un connector_plan già definito
	if context.connector_plan == null:
		return false

	var mask := context.mask
	var rng := context.rng

	var mode: int = params.get("mode", Mode.CENTRAL)
	var allow_loops: bool = params.get("allow_loops", false)
	var width: int = params.get(
		"width",
		context.size_profile.min_width_back_bone
	)
	var jitter: float = params.get("jitter", 0.0)

	var changed: Array[Vector2i] = []

	match mode:
		Mode.CENTRAL:
			changed += _apply_central(width, jitter)

		Mode.LINEAR:
			changed += _apply_linear(width, jitter)

		Mode.MULTI_PIVOT:
			changed += _apply_multi_pivot(width, jitter)

	if allow_loops:
		changed += _inject_loop(width)

	return not changed.is_empty()


# ----------------------------------------------------------------------------
# PARAMETRI GENETICI
# ----------------------------------------------------------------------------

func create_random_params() -> Dictionary:
	var rng := context.rng
	var profile := context.size_profile
	
	return {
		"mode": rng.randi() % Mode.size(),
		"allow_loops": rng.randf() < profile.threshold_loop_back_bone,
		"width": rng.randi_range(
			profile.min_width_back_bone,
			profile.max_width_back_bone
		),
		"jitter": rng.randf_range(
			profile.min_jitter_back_bone,
			profile.max_jitter_back_bone
		)
	}


func mutate_params() -> void:
	var rng := context.rng
	var profile := context.size_profile
	
	params["mode"] = clampi(
		params["mode"] + rng.randi_range(-1, 1),
		0,
		Mode.size() - 1
	)

	params["allow_loops"] = rng.randf() < profile.threshold_loop_back_bone

	params["width"] = clampi(
		params["width"] + rng.randi_range(-1, 1),
		profile.min_width_back_bone,
		profile.max_width_back_bone
	)

	params["jitter"] = clampf(
		params["jitter"] + rng.randf_range(-0.1, 0.1),
		profile.min_jitter_back_bone,
		profile.max_jitter_back_bone
	)


# ----------------------------------------------------------------------------
# CENTRAL MODE
# ----------------------------------------------------------------------------

func _apply_central(width: int, jitter: float) -> Array[Vector2i]:

	var changed: Array[Vector2i] = []
	var pivot := _pick_pivot()

	for d in Dir4.ORDER:
		var start := _internal_spawn(d)
		if not context.mask.in_bounds(start.x, start.y):
			continue

		changed += _carve_corridor(start, pivot, width, jitter)

	return changed


# ----------------------------------------------------------------------------
# LINEAR MODE
# ----------------------------------------------------------------------------

func _apply_linear(width: int, jitter: float) -> Array[Vector2i]:

	var changed: Array[Vector2i] = []
	var points := []

	for d in Dir4.ORDER:
		var p := _internal_spawn(d)
		if context.mask.in_bounds(p.x, p.y):
			points.append(p)

	if points.size() < 2:
		return changed

	points.sort_custom(func(a,b): return a.x < b.x)

	for i in range(points.size() - 1):
		changed += _carve_corridor(points[i], points[i+1], width, jitter)

	return changed


# ----------------------------------------------------------------------------
# MULTI PIVOT MODE
# ----------------------------------------------------------------------------

func _apply_multi_pivot(width: int, jitter: float) -> Array[Vector2i]:

	var changed: Array[Vector2i] = []
	var pivot_a := _pick_pivot()
	var pivot_b := _pick_pivot()

	for d in Dir4.ORDER:

		var start := _internal_spawn(d)
		if not context.mask.in_bounds(start.x, start.y):
			continue

		var target := pivot_a
		if start.distance_squared_to(pivot_b) < start.distance_squared_to(pivot_a):
			target = pivot_b

		changed += _carve_corridor(start, target, width, jitter)

	changed += _carve_corridor(pivot_a, pivot_b, width, jitter)

	return changed


# ----------------------------------------------------------------------------
# CORRIDOR CARVING
# ----------------------------------------------------------------------------

func _carve_corridor(
	from: Vector2i,
	to: Vector2i,
	width: int,
	jitter: float
) -> Array[Vector2i]:

	var changed: Array[Vector2i] = []
	var rng := context.rng
	var current := from

	while current != to:

		if current.x != to.x:
			current.x += sign(to.x - current.x)
		elif current.y != to.y:
			current.y += sign(to.y - current.y)

		if rng.randf() < jitter:
			if rng.randf() < 0.5:
				current.x += rng.randi_range(-1,1)
			else:
				current.y += rng.randi_range(-1,1)

		changed += _carve_with_width(current, width)

	return changed


# ----------------------------------------------------------------------------
# LOOP INJECTION
# ----------------------------------------------------------------------------

func _inject_loop(width: int) -> Array[Vector2i]:

	var changed: Array[Vector2i] = []
	var empties: Array[Vector2i] = []
	var mask := context.mask

	for x in range(mask.size.x):
		for y in range(mask.size.y):
			if mask.is_empty(x,y):
				empties.append(Vector2i(x,y))

	if empties.size() < 2:
		return changed

	var rng := context.rng
	var a: Vector2i = empties[rng.randi() % empties.size()]
	var b: Vector2i = empties[rng.randi() % empties.size()]

	if a.distance_to(b) < 3:
		return changed

	changed += _carve_corridor(a, b, width, 0.0)

	return changed


# ----------------------------------------------------------------------------
# UTILS
# ----------------------------------------------------------------------------

func _pick_pivot() -> Vector2i:

	var wall := context.mask.wall_thickness
	var size := context.mask.size

	return Vector2i(
		context.rng.randi_range(wall+2, size.x-wall-3),
		context.rng.randi_range(wall+2, size.y-wall-3)
	)


func _internal_spawn(dir: int) -> Vector2i:

	var wall := context.mask.wall_thickness
	var size := context.mask.size
	var coord := context.connector_plan.get_coord(dir)

	match dir:
		Dir4.D.N: return Vector2i(coord, wall+1)
		Dir4.D.S: return Vector2i(coord, size.y-wall-2)
		Dir4.D.W: return Vector2i(wall+1, coord)
		Dir4.D.E: return Vector2i(size.x-wall-2, coord)

	return Vector2i.ZERO


func _carve_with_width(center: Vector2i, width: int) -> Array[Vector2i]:

	var changed: Array[Vector2i] = []
	var mask := context.mask
	var wall := mask.wall_thickness
	var size := mask.size
	var half := width / 2

	for dx in range(-half, half+1):
		for dy in range(-half, half+1):

			var p := Vector2i(center.x+dx, center.y+dy)

			if p.x < wall: continue
			if p.y < wall: continue
			if p.x >= size.x-wall: continue
			if p.y >= size.y-wall: continue

			if mask.is_solid(p.x,p.y):
				mask.set_empty(p.x,p.y)
				changed.append(p)

	return changed

# ============================================================================
# RingOperator
# ============================================================================
## Operatore di layout per la creazione di un anello solido interno alla stanza.
##
## RESPONSABILITÀ:
## - Costruire un ring solido completamente interno
## - Aprire uno o più varchi (gate) sul ring
##
## CARATTERISTICHE:
## - Tutte le misure derivano dal RoomSizeProfile
## - Usa Dir4 come sistema direzionale unico
## - Fallisce se collide con SOLID esistenti
## - Nessuna modifica parziale
##
## ORDINE CONSIGLIATO:
## Divider → Indent → Platform → Ring → Connector → Score
# ============================================================================

class_name RingOperator
extends LayoutOperator


func _init() -> void:
	type = Type.RING
	weight = 0.3
	role = Role.PRIMARY

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func apply(
	mask: RoomLayoutMask, 
	context: LayoutContext, 
	params:Dictionary = {}
) -> bool:
	var profile: RoomSizeProfile = context.size_profile
	var rng: RandomNumberGenerator = context.rng

	# -----------------------------------------------------------------------
	# Parametri evolvibili
	# -----------------------------------------------------------------------
	
	var offset: int = params.get("ring_offset", profile.min_ring_offset)
	var thickness: int = params.get("ring_thickness", profile.min_ring_thickness)
	var gate_width: int = params.get("ring_gate_width", profile.min_ring_gate_width)
	var margin: int = params.get("ring_gate_count", profile.min_ring_gate_count)


	# -----------------------------------------------------------------------
	# Calcolo bounds ring
	# -----------------------------------------------------------------------

	var x0: int = margin + offset
	var y0: int = margin + offset
	var x1: int = mask.size.x - margin - offset
	var y1: int = mask.size.y - margin - offset

	if x1 - x0 <= thickness * 2:
		return false
	if y1 - y0 <= thickness * 2:
		return false

	# -----------------------------------------------------------------------
	# Rettangoli del ring
	# -----------------------------------------------------------------------

	var ring_rects: Array[Rect2i] = [
		Rect2i(Vector2i(x0, y0), Vector2i(x1 - x0, thickness)),             # TOP
		Rect2i(Vector2i(x0, y1 - thickness), Vector2i(x1 - x0, thickness)), # BOTTOM
		Rect2i(Vector2i(x0, y0), Vector2i(thickness, y1 - y0)),             # LEFT
		Rect2i(Vector2i(x1 - thickness, y0), Vector2i(thickness, y1 - y0))  # RIGHT
	]

	# -----------------------------------------------------------------------
	# VALIDAZIONE: il ring non deve toccare SOLID esistenti
	# -----------------------------------------------------------------------

	for r in ring_rects:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if mask.is_solid(x, y):
					return false

	# -----------------------------------------------------------------------
	# SCRITTURA ring
	# -----------------------------------------------------------------------

	for r in ring_rects:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				mask.set_solid(x, y)

	# -----------------------------------------------------------------------
	# Apertura varchi usando Dir4
	# -----------------------------------------------------------------------

	var gate_count := rng.randi_range(1, 2)
	var available_dirs: Array[int] = []
	for d in Dir4.ORDER:
		available_dirs.append(d)
	
	available_dirs.shuffle()

	for i in range(min(gate_count, available_dirs.size())):
		_open_gate_dir(
			mask,
			rng,
			available_dirs[i],
			x0, y0, x1, y1,
			thickness,
			gate_width
		)

	return true


func create_random_params(rng: RandomNumberGenerator, profile: RoomSizeProfile) -> Dictionary:
	return {
		"ring_offset": rng.randi_range(
			profile.min_ring_offset,
			profile.max_ring_offset
		),
		
		"ring_thickness": rng.randi_range(
			profile.min_ring_thickness,
			profile.max_ring_thickness
		),
		
		"ring_gate_width": rng.randi_range(
			profile.min_ring_gate_width,
			profile.max_ring_gate_width
		),
		
		"ring_gate_count": rng.randi_range(
			profile.min_ring_gate_count,
			profile.max_ring_gate_count
		)
	}

func mutate_params(params: Dictionary, rng: RandomNumberGenerator, profile: RoomSizeProfile) -> void:
	
	params["ring_offset"] = clamp( 
			params["ring_offset"] + rng.randi_range(-1, 1),
			profile.min_ring_offset,
			profile.max_ring_offset
	)
	
	params["ring_thickness"] = clamp(
		params["ring_thickness"] + rng.randi_range(-1, 1),
		profile.min_ring_thickness,
		profile.max_ring_thickness
	)
	
	params["ring_gate_width"] = clamp(
		params["ring_gate_width"] + rng.randi_range(-1, 1),
		profile.min_ring_gate_width,
		profile.max_ring_gate_width
	)
	
	params["ring_gate_width"] = clamp(
		params["ring_gate_width"] + rng.randi_range(-1, 1),
		profile.min_ring_gate_count,
		profile.max_ring_gate_count
	)

# ---------------------------------------------------------------------------
# Apertura varco su direzione Dir4
# ---------------------------------------------------------------------------

static func _open_gate_dir(
	mask: RoomLayoutMask,
	rng: RandomNumberGenerator,
	d: int,
	x0: int,
	y0: int,
	x1: int,
	y1: int,
	thickness: int,
	gate_width: int
) -> void:

	match d:
		Dir4.D.N:
			var x := rng.randi_range(x0 + thickness, x1 - thickness - gate_width)
			_carve(mask, Rect2i(Vector2i(x, y0), Vector2i(gate_width, thickness)))

		Dir4.D.S:
			var x := rng.randi_range(x0 + thickness, x1 - thickness - gate_width)
			_carve(mask, Rect2i(Vector2i(x, y1 - thickness), Vector2i(gate_width, thickness)))

		Dir4.D.W:
			var y := rng.randi_range(y0 + thickness, y1 - thickness - gate_width)
			_carve(mask, Rect2i(Vector2i(x0, y), Vector2i(thickness, gate_width)))

		Dir4.D.E:
			var y := rng.randi_range(y0 + thickness, y1 - thickness - gate_width)
			_carve(mask, Rect2i(Vector2i(x1 - thickness, y), Vector2i(thickness, gate_width)))


# ---------------------------------------------------------------------------
# Utility: scavo rettangolare
# ---------------------------------------------------------------------------

static func _carve(mask: RoomLayoutMask, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			mask.set_empty(x, y)

# ============================================================================
# ConnectorOperator
# ============================================================================
## Operatore strutturale globale.
##
## RESPONSABILITÀ:
## - Definire le aperture N / E / S / W della stanza.
## - Generare parametri coerenti con dimensione e vincoli.
## - Mutare posizione e larghezza delle aperture.
## - Applicare il ConnectorPlan al contesto.
##
## IMPORTANTE:
## - create_random_params() NON usa la mask.
## - mutate_params() NON usa la mask.
## - apply() è l'unica funzione che usa la mask.
##
## Questo operatore NON carva direttamente.
## Si limita a generare un ConnectorPlan.
# ============================================================================

class_name ConnectorOperator
extends LayoutOperator


# ----------------------------------------------------------------------------
# METADATI STATICI
# ----------------------------------------------------------------------------

static func get_weight() -> float:
	## Peso massimo: operatore strutturale obbligatorio.
	return 1.0


# ----------------------------------------------------------------------------
# COSTRUTTORE
# ----------------------------------------------------------------------------

func _init(_context: OperatorContext, _params: Dictionary = {}) -> void:
	super(_context, _params)
	type = LayoutOperator.Type.CONNECTOR


# ----------------------------------------------------------------------------
# APPLY
# ----------------------------------------------------------------------------

## Costruisce il ConnectorPlan a partire dai parametri genetici.
## Non modifica direttamente la mask.
func apply() -> bool:

	if not params.has("openings"):
		push_error("ConnectorOperator: params missing")
		return false
	
	var plan := ConnectorPlan.new()
	var openings: Dictionary = params["openings"]

	for dir in openings.keys():

		var data: Dictionary = openings[dir]
		var coord: int = data["coord"]
		var width: int = data["width"]
		
		plan.set_opening(dir, coord, width)
	
	context.connector_plan = plan
	return true


# ----------------------------------------------------------------------------
# GENERAZIONE PARAMETRI
# ----------------------------------------------------------------------------

## Genera aperture valide per ogni lato.
##
## Usa SOLO:
## - context.size
## - context.size_profile
## - context.rng
##
## Non usa la mask.
func create_random_params() -> Dictionary:

	var rng: RandomNumberGenerator = context.rng
	var profile: RoomSizeProfile = context.size_profile

	var result: Dictionary = {
		"openings": {}
	}

	for dir in Dir4.ORDER:

		var max_w := _max_width(dir)
		var width := rng.randi_range(
			profile.min_width_tiles,
			max_w
		)

		var bounds := _coord_bounds(dir, width)
		var coord := rng.randi_range(bounds.x, bounds.y)

		result["openings"][dir] = {
			"coord": coord,
			"width": width
		}

	return result


# ----------------------------------------------------------------------------
# MUTAZIONE PARAMETRI
# ----------------------------------------------------------------------------

## Modifica casualmente:
## - larghezza
## - coordinata
##
## Non usa la mask.
func mutate_params() -> void:

	if not params.has("openings"):
		return

	var openings: Dictionary = params["openings"]
	var rng: RandomNumberGenerator = context.rng
	var profile: RoomSizeProfile = context.size_profile

	var dir: int = Dir4.ORDER[
		rng.randi() % Dir4.ORDER.size()
	]

	var data: Dictionary = openings[dir]

	match rng.randi_range(0, 1):

		# ----------------------
		# Mutazione larghezza
		# ----------------------
		0:
			var max_w: int = _max_width(dir)

			data["width"] = clamp(
				data["width"] + rng.randi_range(-2, 2),
				profile.min_width_tiles,
				max_w
			)

		# ----------------------
		# Mutazione coordinata
		# ----------------------
		1:
			var bounds: Vector2i = _coord_bounds(dir, data["width"])

			data["coord"] = clamp(
				data["coord"] + rng.randi_range(-3, 3),
				bounds.x,
				bounds.y
			)


# ----------------------------------------------------------------------------
# HELPER GEOMETRICI (FASE GENETICA)
# ----------------------------------------------------------------------------

## Calcola lo spazio utile su un lato,
## escludendo muri e margini agli angoli.
func _useful_space(dir: int) -> int:

	var size: Vector2i = context.size
	var profile: RoomSizeProfile = context.size_profile
	
	var wall: int = profile.wall_thickness
	var margin: int = profile.corner_margin_tiles

	if dir == Dir4.D.N or dir == Dir4.D.S:
		return size.x - 2 * (wall + margin)
	else:
		return size.y - 2 * (wall + margin)


## Calcola la larghezza massima consentita
## in base a:
## - ratio percentuale
## - limite assoluto
func _max_width(dir: int) -> int:

	var useful: int = _useful_space(dir)
	var profile: RoomSizeProfile = context.size_profile

	var ratio_width: int = int(useful * profile.max_width_ratio)
	var max_width: int = min(profile.max_width_abs, ratio_width)

	return max(max_width, profile.min_width_tiles)


## Calcola il range valido per la coordinata
## dell'apertura lungo il lato.
func _coord_bounds(dir: int, width: int) -> Vector2i:
	
	var size: Vector2i = context.size
	var profile: RoomSizeProfile = context.size_profile

	var wall: int = profile.wall_thickness
	var margin: int = profile.corner_margin_tiles

	var min_c: int = wall + margin
	var max_c: int

	if dir == Dir4.D.N or dir == Dir4.D.S:
		max_c = size.x - wall - margin - width
	else:
		max_c = size.y - wall - margin - width

	return Vector2i(min_c, max_c)


# ----------------------------------------------------------------------------
# CARVE (FASE APPLICATIVA)
# ----------------------------------------------------------------------------

## Esegue il carve fisico sulla mask.
## NON viene chiamato direttamente qui,
## ma dal sistema di generazione finale.
func _carve(
	mask: RoomLayoutMask,
	dir: int,
	coord: int,
	width: int
) -> void:

	var wall: int = mask.wall_thickness

	match dir:

		Dir4.D.N:
			for x in range(coord, coord + width):
				for y in range(0, wall):
					if mask.in_bounds(x, y):
						mask.set_empty(x, y)

		Dir4.D.S:
			for x in range(coord, coord + width):
				for y in range(mask.size.y - wall, mask.size.y):
					if mask.in_bounds(x, y):
						mask.set_empty(x, y)

		Dir4.D.W:
			for y in range(coord, coord + width):
				for x in range(0, wall):
					if mask.in_bounds(x, y):
						mask.set_empty(x, y)

		Dir4.D.E:
			for y in range(coord, coord + width):
				for x in range(mask.size.x - wall, mask.size.x):
					if mask.in_bounds(x, y):
						mask.set_empty(x, y)

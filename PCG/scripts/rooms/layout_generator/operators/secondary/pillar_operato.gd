# ============================================================================
# PillarOperator
# ============================================================================
## Operatore SECONDARIO per l’inserimento di colonne solide isolate.
##
## RESPONSABILITÀ:
## - Inserire rettangoli solidi verticali interni alla stanza.
## - Mantenere distanza minima dai muri.
## - Garantire spazio laterale di passaggio.
##
## FILOSOFIA IMPLEMENTATIVA:
## - Nessun retry loop.
## - Nessuna scansione casuale delle celle.
## - Si calcolano prima tutte le posizioni valide.
## - Si sceglie casualmente tra esse.
##
## COMPLESSITÀ:
## - Deterministica O(n)
## - Nessuna crescita esponenziale
# ============================================================================

class_name PillarOperator
extends LayoutOperator


# ----------------------------------------------------------------------------
# METADATO STATICO
# ----------------------------------------------------------------------------

## Peso di selezione evolutiva.
static func get_weight() -> float:
	return 0.25


# ----------------------------------------------------------------------------
# COSTRUTTORE
# ----------------------------------------------------------------------------

func _init(_context: OperatorContext, _params: Dictionary = {}) -> void:
	super(_context, _params)
	type = Type.PILLAR


# ----------------------------------------------------------------------------
# APPLY
# ----------------------------------------------------------------------------

## Applica le colonne richieste dal genome.
##
## return: true se almeno una colonna è stata inserita.
func apply() -> bool:

	var count: int = params.get(
		"pillar_count",
		context.size_profile.min_pillar_count
	)

	var width: int = params.get(
		"pillar_width",
		context.size_profile.min_pillar_width
	)

	var height: int = params.get(
		"pillar_height",
		context.size_profile.min_pillar_height
	)

	var placed := 0

	for i in range(count):

		var candidates := _compute_valid_rects(width, height)

		if candidates.is_empty():
			break

		var rng := context.rng
		var rect := candidates[rng.randi_range(0, candidates.size() - 1)]

		_write_rect(rect)
		placed += 1

	return placed > 0


# ----------------------------------------------------------------------------
# PARAMETRI GENETICI
# ----------------------------------------------------------------------------

## Genera parametri random coerenti con il profilo stanza.
##
## return: Dictionary con parametri genetici.
func create_random_params() -> Dictionary:

	var rng := context.rng
	var profile := context.size_profile

	return {
		"pillar_count": rng.randi_range(
			profile.min_pillar_count,
			profile.max_pillar_count
		),

		"pillar_width": rng.randi_range(
			profile.min_pillar_width,
			profile.max_pillar_width
		),

		"pillar_height": rng.randi_range(
			profile.min_pillar_height,
			profile.max_pillar_height
		)
	}


## Mutazione controllata dei parametri genetici.
func mutate_params() -> void:

	var rng := context.rng
	var profile := context.size_profile

	params["pillar_count"] = clampi(
		params.get("pillar_count", profile.min_pillar_count)
		+ rng.randi_range(-1, 1),
		profile.min_pillar_count,
		profile.max_pillar_count
	)

	params["pillar_width"] = clampi(
		params.get("pillar_width", profile.min_pillar_width)
		+ rng.randi_range(-1, 1),
		profile.min_pillar_width,
		profile.max_pillar_width
	)

	params["pillar_height"] = clampi(
		params.get("pillar_height", profile.min_pillar_height)
		+ rng.randi_range(-1, 1),
		profile.min_pillar_height,
		profile.max_pillar_height
	)


# ----------------------------------------------------------------------------
# CALCOLO POSIZIONI VALIDE
# ----------------------------------------------------------------------------

## Calcola tutte le posizioni valide per un pillar.
##
## [param width]: larghezza del pillar.
## [param height]: altezza del pillar.
##
## return: Array di Rect2i validi.
func _compute_valid_rects(width: int, height: int) -> Array[Rect2i]:

	var result: Array[Rect2i] = []

	var mask := context.mask
	var profile := context.size_profile
	var bounds := mask.get_operable_bounds(profile)

	# Spazio laterale minimo richiesto per garantire passaggio
	var lateral_clear := profile.min_passage_tiles

	for y in range(bounds.position.y, bounds.end.y - height):
		for x in range(bounds.position.x, bounds.end.x - width):

			var rect := Rect2i(
				Vector2i(x, y),
				Vector2i(width, height)
			)

			if not bounds.encloses(rect):
				continue

			if _can_place(rect, lateral_clear):
				result.append(rect)

	return result


# ----------------------------------------------------------------------------
# VALIDAZIONE POSIZIONAMENTO
# ----------------------------------------------------------------------------

## Verifica se il rettangolo può essere inserito.
##
## [param rect]: area candidata.
## [param lateral_clear]: spazio minimo laterale richiesto.
##
## return: true se posizionabile.
func _can_place(rect: Rect2i, lateral_clear: int) -> bool:

	var mask := context.mask

	# Area pillar deve essere vuota
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if mask.is_solid(x, y):
				return false

	# Spazio laterale sinistro
	for x in range(rect.position.x - lateral_clear, rect.position.x):
		for y in range(rect.position.y, rect.end.y):
			if mask.in_bounds(x, y) and mask.is_solid(x, y):
				return false

	# Spazio laterale destro
	for x in range(rect.end.x, rect.end.x + lateral_clear):
		for y in range(rect.position.y, rect.end.y):
			if mask.in_bounds(x, y) and mask.is_solid(x, y):
				return false

	return true


# ----------------------------------------------------------------------------
# SCRITTURA MASK
# ----------------------------------------------------------------------------

## Scrive il rettangolo nella mask.
##
## [param rect]: area da rendere solida.
func _write_rect(rect: Rect2i) -> void:

	var mask := context.mask

	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			mask.set_solid(x, y)

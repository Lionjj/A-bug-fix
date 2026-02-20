# ============================================================================
# PlatformOperator
# ============================================================================
## Operatore SECONDARIO per l’inserimento di piattaforme sospese.
##
## RESPONSABILITÀ:
## - Inserire rettangoli solidi interni alla stanza.
## - Garantire spazio libero sopra, sotto e lateralmente.
## - Rispettare i margini strutturali globali.
##
## FILOSOFIA IMPLEMENTATIVA:
## - Nessun retry loop.
## - Nessuna scansione ripetuta.
## - Si calcolano prima tutte le posizioni valide.
## - Si sceglie casualmente tra esse.
##
## COMPLESSITÀ:
## - Deterministica O(n)
## - Nessun comportamento esplosivo
# ============================================================================

class_name PlatformOperator
extends LayoutOperator


# ----------------------------------------------------------------------------
# METADATO STATICO
# ----------------------------------------------------------------------------

## Peso di selezione evolutiva.
static func get_weight() -> float:
	return 0.5


# ----------------------------------------------------------------------------
# COSTRUTTORE
# ----------------------------------------------------------------------------

func _init(_context: OperatorContext, _params: Dictionary = {}) -> void:
	super(_context, _params)
	type = Type.PLATFORM


# ----------------------------------------------------------------------------
# APPLY
# ----------------------------------------------------------------------------

## Applica le piattaforme richieste dal genome.
##
## return: true se almeno una piattaforma è stata inserita.
func apply() -> bool:

	var count: int = params.get(
		"platform_count",
		context.size_profile.min_platform_count
	)

	var width: int = params.get(
		"platform_width",
		context.size_profile.min_width_platform
	)

	var thickness: int = params.get(
		"platform_thickness",
		context.size_profile.min_thickness_platform
	)

	var placed := 0

	for i in range(count):

		var candidates := _compute_valid_rects(width, thickness)

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
		"platform_count": rng.randi_range(
			profile.min_platform_count,
			profile.max_platform_count
		),

		"platform_width": rng.randi_range(
			profile.min_width_platform,
			profile.max_width_platform
		),

		"platform_thickness": rng.randi_range(
			profile.min_thickness_platform,
			profile.max_thickness_platform
		)
	}


## Mutazione controllata dei parametri genetici.
func mutate_params() -> void:

	var rng := context.rng
	var profile := context.size_profile

	params["platform_count"] = clampi(
		params.get("platform_count", profile.min_platform_count)
		+ rng.randi_range(-1, 1),
		profile.min_platform_count,
		profile.max_platform_count
	)

	params["platform_width"] = clampi(
		params.get("platform_width", profile.min_width_platform)
		+ rng.randi_range(-1, 1),
		profile.min_width_platform,
		profile.max_width_platform
	)

	params["platform_thickness"] = clampi(
		params.get("platform_thickness", profile.min_thickness_platform)
		+ rng.randi_range(-1, 1),
		profile.min_thickness_platform,
		profile.max_thickness_platform
	)


# ----------------------------------------------------------------------------
# CALCOLO POSIZIONI VALIDE
# ----------------------------------------------------------------------------

## Calcola tutte le posizioni valide per una piattaforma
## con dimensioni specificate.
##
## [param width]: larghezza piattaforma.
## [param thickness]: spessore verticale.
##
## return: Array di Rect2i validi.
func _compute_valid_rects(width: int, thickness: int) -> Array[Rect2i]:

	var result: Array[Rect2i] = []

	var mask := context.mask
	var profile := context.size_profile
	var bounds := mask.get_operable_bounds(profile)

	for y in range(bounds.position.y, bounds.end.y - thickness):
		for x in range(bounds.position.x, bounds.end.x - width):

			var rect := Rect2i(
				Vector2i(x, y),
				Vector2i(width, thickness)
			)

			if not bounds.encloses(rect):
				continue

			if _can_place(rect):
				result.append(rect)

	return result


# ----------------------------------------------------------------------------
# VALIDAZIONE POSIZIONAMENTO
# ----------------------------------------------------------------------------

## Verifica se un rettangolo può essere inserito.
##
## [param rect]: area candidata.
##
## return: true se posizionabile.
func _can_place(rect: Rect2i) -> bool:

	var mask := context.mask
	var profile := context.size_profile

	var vertical_clear := profile.border_margin_ceil_flor
	var horizontal_clear := profile.border_margin_wall

	# Area piattaforma deve essere vuota
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if mask.is_solid(x, y):
				return false

	# Spazio sopra
	for y in range(rect.position.y - vertical_clear, rect.position.y):
		for x in range(rect.position.x, rect.end.x):
			if not mask.in_bounds(x, y):
				return false
			if mask.is_solid(x, y):
				return false

	# Spazio sotto
	for y in range(rect.end.y, rect.end.y + vertical_clear):
		for x in range(rect.position.x, rect.end.x):
			if not mask.in_bounds(x, y):
				return false
			if mask.is_solid(x, y):
				return false

	# Spazio sinistra
	for x in range(rect.position.x - horizontal_clear, rect.position.x):
		for y in range(rect.position.y, rect.end.y):
			if mask.in_bounds(x, y) and mask.is_solid(x, y):
				return false

	# Spazio destra
	for x in range(rect.end.x, rect.end.x + horizontal_clear):
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

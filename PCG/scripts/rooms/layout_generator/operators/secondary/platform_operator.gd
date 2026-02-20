# ============================================================================
# PlatformOperator
# ============================================================================
## Operatore SECONDARIO per la generazione di piattaforme sospese.
##
## RESPONSABILITÀ:
## - Inserire superfici solide rettangolari interne.
## - Garantire spazio libero sopra e sotto.
## - Rispettare margini da pareti e pavimento.
##
## VINCOLI:
## - Non modifica macro-topologia.
## - Non interagisce con Connector o Backbone.
## - Non crea rollback complessi.
##
## RUOLO NEL SISTEMA:
## - Introduce verticalità e varietà.
## - Aumenta complessità di navigazione.
# ============================================================================

class_name PlatformOperator
extends LayoutOperator


# ----------------------------------------------------------------------------
# METADATO STATICO
# ----------------------------------------------------------------------------

static func get_weight() -> float:
	## Peso medio → più frequente del Pillar.
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

func apply() -> bool:

	var profile := context.size_profile
	var rng := context.rng
	
	var count: int = params.get(
		"platform_count",
		profile.min_platform_count
	)

	var width: int = params.get(
		"platform_width",
		profile.min_width_platform
	)

	var thickness: int = params.get(
		"platform_thickness",
		profile.min_thickness_platform
	)

	var placed: int = 0
	var attempts: int = count * 20

	while placed < count and attempts > 0:
		attempts -= 1
		if _try_place_platform(width, thickness):
			placed += 1

	return placed > 0


# ----------------------------------------------------------------------------
# PARAMETRI GENETICI
# ----------------------------------------------------------------------------

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
# PLACEMENT LOGIC
# ----------------------------------------------------------------------------

func _try_place_platform(width: int, thickness: int) -> bool:

	var rng := context.rng
	var profile := context.size_profile
	var mask := context.mask

	var wall_margin := profile.border_margin_wall
	var floor_margin := profile.border_margin_ceil_flor
	var spacing := profile.min_passage_tiles

	var empty_cells := mask.get_all_empty_cells()
	if empty_cells.is_empty():
		return false
	
	empty_cells.shuffle()

	for cell in empty_cells:

		var x0 := cell.x
		var y0 := cell.y

		# ----------------------------
		# Boundaries rispetto ai muri
		# ----------------------------
		if x0 < wall_margin:
			continue
		if x0 + width >= mask.size.x - wall_margin:
			continue

		# ----------------------------
		# Boundaries verticali
		# ----------------------------
		if y0 < floor_margin + spacing:
			continue
		if y0 + thickness >= mask.size.y - floor_margin - spacing:
			continue

		var rect := Rect2i(
			Vector2i(x0, y0),
			Vector2i(width, thickness)
		)

		if _can_place_platform(rect):

			# Scrittura effettiva
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					mask.set_solid(x, y)

			return true

	return false


# ----------------------------------------------------------------------------
# VALIDAZIONE POSIZIONAMENTO
# ----------------------------------------------------------------------------

func _can_place_platform(rect: Rect2i) -> bool:

	var mask := context.mask
	var vertical_clear := context.size_profile.border_margin_ceil_flor
	var horizontal_clear := context.size_profile.border_margin_wall

	# Area piattaforma deve essere vuota
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not mask.in_bounds(x, y):
				return false
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

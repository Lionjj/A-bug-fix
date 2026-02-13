# ============================================================================
# PillarOperator
# ============================================================================
## Operatore di layout SECONDARIO.
##
## RESPONSABILITÀ:
## - Inserire colonne solide isolate all’interno della stanza
##
## GARANZIE:
## - NON modifica la forma globale
## - NON divide la stanza
## - NON crea regioni isolate
## - NON tocca i muri perimetrali
##
## FILOSOFIA:
## - Geometria semplice
## - Distanza minima da SOLID esistenti
## - Tutto derivato dal RoomSizeProfile
##
## ORDINE CONSIGLIATO:
## PrimaryShape → Indent → Platform → Pillar → Connector → Score
# ============================================================================

class_name PillarOperator
extends LayoutOperator


func _init() -> void:
	type = Type.PILLAR
	weight = 0.25
	weight = Role.SECONDARY

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func apply(
	mask: RoomLayoutMask, 
	context: LayoutContext,
	params: Dictionary = {}
) -> bool:
	var profile: RoomSizeProfile = context.size_profile
	var rng: RandomNumberGenerator = context.rng
	
	var count: int = params.get("pillar_count", profile.min_pillar_count)
	var width: int = params.get("pillar_width", profile.min_pillar_width)
	var height: int = params.get("pillar_height", profile.min_pillar_height)

	var placed: int = 0
	var attempts: int = count * 6

	while placed < count and attempts > 0:
		attempts -= 1
		if _try_place_pillar(mask, profile, rng, width, height):
			placed += 1

	return placed > 0


func create_random_params(rng: RandomNumberGenerator, profile: RoomSizeProfile) -> Dictionary:
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
		),
	}

func mutate_params(params: Dictionary, rng: RandomNumberGenerator, profile: RoomSizeProfile) -> void:
	params["pillar_count"] = clamp(
		rng.randi_range(-1, 1),
		profile.min_pillar_count, 
		profile.max_pillar_count
	)
	
	params["pillar_width"] = clamp(
		rng.randi_range(-1, 1),
		profile.min_pillar_width, 
		profile.max_pillar_width
	)
	
	params["pillar_height"] = clamp(
		rng.randi_range(-1, 1),
		profile.min_pillar_height, 
		profile.max_pillar_height
	)


# ---------------------------------------------------------------------------
# Placement singolo pilastro
# ---------------------------------------------------------------------------

static func _try_place_pillar(
	mask: RoomLayoutMask,
	profile: RoomSizeProfile,
	rng: RandomNumberGenerator,
	width: int,
	height: int
) -> bool:
	var spacing: int = profile.min_passage_tiles
	var margin: int = profile.border_margin_wall

	# area disponibile
	var x_min := margin + spacing
	var x_max := mask.size.x - margin - spacing - width
	if x_min >= x_max:
		return false

	var y_min := margin + spacing
	var y_max := mask.size.y - margin - spacing - height
	if y_min >= y_max:
		return false

	var x0 := rng.randi_range(x_min, x_max)
	var y0 := rng.randi_range(y_min, y_max)

	var rect := Rect2i(Vector2i(x0, y0), Vector2i(width, height))

	# -----------------------------------------------------------------------
	# VALIDAZIONE
	# -----------------------------------------------------------------------

	# 1) il pilastro deve scavare SOLO EMPTY
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not mask.in_bounds(x, y):
				return false
			if mask.is_solid(x, y):
				return false

	# 2) distanza minima da SOLID esistenti
	for y in range(rect.position.y - spacing, rect.end.y + spacing):
		for x in range(rect.position.x - spacing, rect.end.x + spacing):
			if not mask.in_bounds(x, y):
				continue
			if mask.is_solid(x, y):
				return false

	# -----------------------------------------------------------------------
	# SCRITTURA
	# -----------------------------------------------------------------------

	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			mask.set_solid(x, y)

	return true

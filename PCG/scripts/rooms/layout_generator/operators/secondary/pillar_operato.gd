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


func _init(_context: OperatorContext, _params: Dictionary = {}) -> void:
	super._init(_context, _params)
	type = Type.PILLAR
	weight = 0.25
	role = Role.SECONDARY

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func apply() -> bool:
	var profile: RoomSizeProfile = context.size_profile
	var rng: RandomNumberGenerator = context.rng
	
	var count: int = params.get("pillar_count", profile.min_pillar_count)
	var width: int = params.get("pillar_width", profile.min_pillar_width)
	var height: int = params.get("pillar_height", profile.min_pillar_height)

	var placed: int = 0
	var attempts: int = count * 6

	while placed < count and attempts > 0:
		attempts -= 1
		if _try_place_pillar(width, height):
			placed += 1

	return placed > 0


func create_random_params() -> Dictionary:
	var rng: RandomNumberGenerator = context.rng
	var profile: RoomSizeProfile = context.size_profile
	
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

func mutate_params() -> void:
	var rng: RandomNumberGenerator = context.rng
	var profile: RoomSizeProfile = context.size_profile
	
	params["pillar_count"] = clamp(
		params["pillar_count"] + rng.randi_range(-1, 1),
		profile.min_pillar_count, 
		profile.max_pillar_count
	)
	
	params["pillar_width"] = clamp(
		params["pillar_width"] + rng.randi_range(-1, 1),
		profile.min_pillar_width, 
		profile.max_pillar_width
	)
	
	params["pillar_height"] = clamp(
		params["pillar_height"] + rng.randi_range(-1, 1),
		profile.min_pillar_height, 
		profile.max_pillar_height
	)


# ---------------------------------------------------------------------------
# Placement singolo pilastro
# ---------------------------------------------------------------------------

func _try_place_pillar(width: int, height: int) -> bool:
	var rng := context.rng
	var profile := context.size_profile
	var mask := context.mask

	var margin := profile.border_margin_wall
	var spacing := profile.min_passage_tiles

	var empty_cells := mask.get_all_empty_cells()
	if empty_cells.is_empty():
		return false

	empty_cells.shuffle()

	var candidates: Array[Vector2i] = []

	for cell in empty_cells:

		var x0 := cell.x
		var y0 := cell.y

		# bounds base
		if x0 < margin + spacing:
			continue
		if x0 + width >= mask.size.x - margin - spacing:
			continue

		if y0 < margin + spacing:
			continue
		if y0 + height >= mask.size.y - margin - spacing:
			continue

		var rect := Rect2i(Vector2i(x0, y0), Vector2i(width, height))

		if _can_place_pillar(rect):
			candidates.append(Vector2i(x0, y0))

	if candidates.is_empty():
		return false

	var chosen := candidates[rng.randi() % candidates.size()]
	var rect := Rect2i(chosen, Vector2i(width, height))

	# scrittura
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			mask.set_solid(x, y)

	return true

func _can_place_pillar(rect: Rect2i) -> bool:
	var mask := context.mask
	var lateral_clear := 3

	# area deve essere vuota
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not mask.in_bounds(x, y):
				return false
			if mask.is_solid(x, y):
				return false

	# distanza laterale minima (evita cluster)
	for x in range(rect.position.x - lateral_clear, rect.position.x):
		for y in range(rect.position.y, rect.end.y):
			if mask.in_bounds(x, y) and mask.is_solid(x, y):
				return false

	for x in range(rect.end.x, rect.end.x + lateral_clear):
		for y in range(rect.position.y, rect.end.y):
			if mask.in_bounds(x, y) and mask.is_solid(x, y):
				return false

	return true

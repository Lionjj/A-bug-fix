# ============================================================================
# PlatformOperator
# ============================================================================
## Operatore di layout per la creazione di piattaforme sospese.
##
## Inserisce superfici SOLID rettangolari interne alla stanza,
## rispettando le distanze minime definite nel RoomSizeProfile.
##
## Non introduce:
## - scoring
## - rollback complessi
## - dipendenze da player / connector
##
## Ordine consigliato:
## Divider → Indent → Platform → Connector
# ============================================================================

class_name PlatformOperator
extends LayoutOperator

func _init(_context: OperatorContext, _params: Dictionary = {}) -> void:
	super._init(_context, _params)
	type = Type.PLATFORM
	weight = 0.5
	role = Role.SECONDARY

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func apply() -> bool:
	var profile: RoomSizeProfile = context.size_profile
	var rng: RandomNumberGenerator = context.rng
	
	# -----------------------------------------------------------------------
	# Parametri evolvibili
	# -----------------------------------------------------------------------
	var count: int = params.get("platform_count", profile.min_platform_count)
	var width: int = params.get("platform_width", profile.min_width_platform)
	var thickness: int = params.get("platform_thickness", profile.min_thickness_platform)

	var placed: int = 0
	var attempts: int = count * 20

	while placed < count and attempts > 0:
		attempts -= 1
		if _try_place_platform(width, thickness):
			placed += 1

	return placed > 0


func create_random_params() -> Dictionary:
	var rng: RandomNumberGenerator = context.rng
	var profile: RoomSizeProfile = context.size_profile
	
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
		),
	}

func mutate_params() -> void:
	var rng: RandomNumberGenerator = context.rng
	var profile: RoomSizeProfile = context.size_profile
	
	params["platform_count"] = clamp(
		params.get("platform_count", profile.min_platform_count) + rng.randi_range(-1, 1),
		profile.min_platform_count,
		profile.max_platform_count
	)

	params["platform_width"] = clamp(
		params.get("platform_width", profile.min_width_platform) + rng.randi_range(-1, 1),
		profile.min_width_platform,
		profile.max_width_platform
	)

	params["platform_thickness"] = clamp(
		params.get("platform_thickness", profile.min_thickness_platform) + rng.randi_range(-1, 1),
		profile.min_thickness_platform,
		profile.max_thickness_platform
	)

# ---------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------

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

		# controlli base bounds
		if x0 < wall_margin:
			continue
		if x0 + width >= mask.size.x - wall_margin:
			continue

		if y0 < floor_margin + spacing:
			continue
		if y0 + thickness >= mask.size.y - floor_margin - spacing:
			continue

		var rect := Rect2i(Vector2i(x0, y0), Vector2i(width, thickness))

		if _can_place_platform(rect):
			
			# scrittura finale
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					mask.set_solid(x, y)

			return true

	return false


func _can_place_platform(rect: Rect2i) -> bool:
	var mask := context.mask

	var vertical_clear := context.size_profile.border_margin_ceil_flor
	var horizontal_clear := context.size_profile.border_margin_wall

	# 1) area piattaforma deve essere vuota
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not mask.in_bounds(x, y):
				return false
			if mask.is_solid(x, y):
				return false

	# 2) spazio sopra
	for y in range(rect.position.y - vertical_clear, rect.position.y):
		for x in range(rect.position.x, rect.end.x):
			if not mask.in_bounds(x, y):
				return false
			if mask.is_solid(x, y):
				return false

	# 3) spazio sotto
	for y in range(rect.end.y, rect.end.y + vertical_clear):
		for x in range(rect.position.x, rect.end.x):
			if not mask.in_bounds(x, y):
				return false
			if mask.is_solid(x, y):
				return false

	# 4) spazio sinistra
	for x in range(rect.position.x - horizontal_clear, rect.position.x):
		for y in range(rect.position.y, rect.end.y):
			if not mask.in_bounds(x, y):
				return false
			if mask.is_solid(x, y):
				return false

	# 5) spazio destra
	for x in range(rect.end.x, rect.end.x + horizontal_clear):
		for y in range(rect.position.y, rect.end.y):
			if not mask.in_bounds(x, y):
				return false
			if mask.is_solid(x, y):
				return false

	return true

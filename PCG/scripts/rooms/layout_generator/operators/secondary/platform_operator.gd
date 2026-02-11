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


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

static func apply(
	mask: RoomLayoutMask, 
	context: LayoutContext,
	params: Dictionary = {}
) -> bool:
	var profile: RoomSizeProfile = context.size_profile
	var rng: RandomNumberGenerator = context.rng
	
	# -----------------------------------------------------------------------
	# Parametri evolvibili
	# -----------------------------------------------------------------------
	var count: int = params.get("platform_count", 0)
	var width: int = params.get("platform_width", 0)
	var thickness: int = params.get("platform_thickness", 0)

	var placed: int = 0
	var attempts: int = count * 6

	while placed < count and attempts > 0:
		attempts -= 1
		if _try_place_platform(mask, profile, rng, width, thickness):
			placed += 1

	return placed > 0


# ---------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------

static func _try_place_platform(
	mask: RoomLayoutMask,
	profile: RoomSizeProfile,
	rng: RandomNumberGenerator,
	width: int,
	thickness: int
) -> bool:


	# limiti orizzontali
	var x_min: int = profile.border_margin_wall
	var x_max: int = mask.size.x - profile.border_margin_wall - width
	if x_min >= x_max:
		return false

	# limiti verticali (aria sopra/sotto)
	var y_min: int = profile.border_margin_ceil_flor + profile.min_passage_tiles
	var y_max: int = mask.size.y \
		- profile.border_margin_ceil_flor \
		- profile.min_passage_tiles \
		- thickness

	if y_min >= y_max:
		return false

	var x0: int = rng.randi_range(x_min, x_max)
	var y0: int = rng.randi_range(y_min, y_max)

	var rect := Rect2i(
		Vector2i(x0, y0),
		Vector2i(width, thickness)
	)

	# 1) tutte le celle devono essere EMPTY
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if mask.is_solid(x, y):
				return false

	# 2) distanza minima da SOLID esistenti
	var spacing := profile.min_passage_tiles
	for y in range(rect.position.y - spacing, rect.end.y + spacing):
		for x in range(rect.position.x - spacing, rect.end.x + spacing):
			if not mask.in_bounds(x, y):
				continue
			if mask.is_solid(x, y):
				return false

	# 3) scrittura finale (atomica)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			mask.set_solid(x, y)

	return true

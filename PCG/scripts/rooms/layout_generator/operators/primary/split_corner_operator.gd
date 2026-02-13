# ============================================================================
# SplitCornerOperator
# ============================================================================
## Operatore di layout PRIMARIO (non divisivo).
##
## RESPONSABILITÀ:
## - Taglia un angolo della stanza con una massa solida
## - Genera forme a L / Γ / C
##
## GARANZIE:
## - NON divide la stanza
## - NON crea varchi passanti
## - NON modifica la connettività globale
## - Opera solo da angoli
##
## FILOSOFIA:
## - Usa RoomSizeProfile
## - Usa Dir4 per la scelta dell’angolo
## - Fallisce se collide con SOLID esistenti
##
## ORDINE CONSIGLIATO:
## Size → PrimaryShape (Divider / Ring / SplitCorner) → Indent → Platform → Connector
# ============================================================================

class_name SplitCornerOperator
extends LayoutOperator


func _init() -> void:
	type = Type.SPLIT_CORNER
	weight = 0.3
	role = Role.PRIMARY

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

	# larghezza del taglio
	var width: int = params.get("corner_width", profile.min_width_split_corner)
	
	# profondità del taglio
	var depth: int = params.get("corner_depth", profile.min_depth_split_corner) 
	
	var corner_index: int = params.get("corner_count", profile.min_split_corner_count)


	# scelta angolo usando Dir4 (coppie)
	var corners := [
		[Dir4.D.N, Dir4.D.W], # Nord-Ovest
		[Dir4.D.N, Dir4.D.E], # Nord-Est
		[Dir4.D.S, Dir4.D.W], # Sud-Ovest
		[Dir4.D.S, Dir4.D.E], # Sud-Est
	]

	corner_index = clamp(corner_index, 0, corners.size() - 1)
	
	var corner: Array = corners[corner_index]

	return _apply_corner(mask, profile, corner[0], corner[1], width, depth)


func create_random_params(rng: RandomNumberGenerator, profile: RoomSizeProfile) -> Dictionary:

	return {
		"corner_width": rng.randi_range(
			profile.min_width_split_corner,
			profile.max_width_split_corner
		),
		
		"corner_depth": rng.randi_range(
			profile.min_depth_split_corner,
			profile.max_depth_split_corner
		),
		
		"corner_count": rng.randi_range(
			profile.min_split_corner_count,
			profile.max_split_corner_count
		),
	}

func mutate_params(params: Dictionary, rng: RandomNumberGenerator, profile: RoomSizeProfile) -> void:
	params["corner_width"] = clamp(
		params["corner_width"] + rng.randi_range(-1, 1),
		profile.min_width_split_corner,
		profile.max_width_split_corner
	)
	
	params["corner_depth"] = clamp(
		params["corner_depth"] + rng.randi_range(-1, 1),
		profile.min_depth_split_corner,
		profile.max_depth_split_corner
	)
	
	params["corner_count"] = clamp(
		params["corner_count"] + rng.randi_range(-1, 1),
		profile.min_split_corner_count,
		profile.max_split_corner_count
	)

# ---------------------------------------------------------------------------
# Applicazione angolo
# ---------------------------------------------------------------------------

static func _apply_corner(
	mask: RoomLayoutMask,
	profile: RoomSizeProfile,
	d1: int,
	d2: int,
	width: int,
	depth: int
) -> bool:
	var margin := profile.border_margin_wall
	var t := profile.wall_thickness

	var rects: Array[Rect2i] = []

	match [d1, d2]:
		# N + W
		[Dir4.D.N, Dir4.D.W]:
			rects.append(
				Rect2i(
					Vector2i(margin, margin),
					Vector2i(width, depth)
				)
			)
			rects.append(
				Rect2i(
					Vector2i(margin, margin),
					Vector2i(depth, width)
				)
			)

		# N + E
		[Dir4.D.N, Dir4.D.E]:
			rects.append(
				Rect2i(
					Vector2i(mask.size.x - margin - width, margin),
					Vector2i(width, depth)
				)
			)
			rects.append(
				Rect2i(
					Vector2i(mask.size.x - margin - depth, margin),
					Vector2i(depth, width)
				)
			)

		# S + W
		[Dir4.D.S, Dir4.D.W]:
			rects.append(
				Rect2i(
					Vector2i(margin, mask.size.y - margin - depth),
					Vector2i(width, depth)
				)
			)
			rects.append(
				Rect2i(
					Vector2i(margin, mask.size.y - margin - width),
					Vector2i(depth, width)
				)
			)

		# S + E
		[Dir4.D.S, Dir4.D.E]:
			rects.append(
				Rect2i(
					Vector2i(mask.size.x - margin - width, mask.size.y - margin - depth),
					Vector2i(width, depth)
				)
			)
			rects.append(
				Rect2i(
					Vector2i(mask.size.x - margin - depth, mask.size.y - margin - width),
					Vector2i(depth, width)
				)
			)

		_:
			return false

	# -----------------------------------------------------------------------
	# VALIDAZIONE: tutte le celle devono essere EMPTY
	# -----------------------------------------------------------------------

	for r in rects:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if not mask.in_bounds(x, y):
					return false
				if mask.is_solid(x, y):
					return false

	# -----------------------------------------------------------------------
	# SCRITTURA SOLIDI
	# -----------------------------------------------------------------------

	for r in rects:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				mask.set_solid(x, y)

	return true

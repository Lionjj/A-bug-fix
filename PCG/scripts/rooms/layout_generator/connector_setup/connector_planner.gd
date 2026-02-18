# ============================================================================
# ConnectorPlanner
# ============================================================================
## Pianifica le posizioni logiche dei 4 connettori (N/E/S/W)
## sul bordo esterno della stanza.
##
## VERSIONE BACKBONE-MODE:
## - NON dipende da celle EMPTY esistenti
## - NON modifica la mask
## - NON valida traversal
## - NON apre varchi
##
## Il planner decide SOLO:
## - coordinata centrale del connettore
## - larghezza del connettore
##
## La geometria verrà scavata successivamente dal BackboneBuilder.
# ============================================================================

class_name ConnectorPlanner
extends RefCounted


# ============================================================================
# API PUBBLICA
# ============================================================================

static func build(
	mask: RoomLayoutMask,
	rng: RandomNumberGenerator
) -> ConnectorPlan:

	var plan := ConnectorPlan.new()
	var profile:= ConnectorProfile.new()

	for d in Dir4.ORDER:

		var coord := _pick_coord(mask, profile, rng, d)
		var width := _compute_width(mask, profile, d)

		plan.set_opening(d, coord, width)

	return plan


# ============================================================================
# COORDINATA CENTRALE DEL CONNETTORE
# ============================================================================
## Seleziona una coordinata valida sul lato esterno,
## rispettando:
## - wall_thickness
## - corner_margin
##
## NON controlla se la zona è scavata (non è suo compito).
# ============================================================================

static func _pick_coord(
	mask: RoomLayoutMask,
	profile: ConnectorProfile,
	rng: RandomNumberGenerator,
	dir: int
) -> int:

	var wall := mask.wall_thickness
	var margin := profile.corner_margin_tiles

	match dir:

		Dir4.D.N, Dir4.D.S:
			var min_x := wall + margin
			var max_x := mask.size.x - wall - margin - 1
			return rng.randi_range(min_x, max_x)

		Dir4.D.W, Dir4.D.E:
			var min_y := wall + margin
			var max_y := mask.size.y - wall - margin - 1
			return rng.randi_range(min_y, max_y)

	return 0


# ============================================================================
# CALCOLO WIDTH
# ============================================================================
## Determina la larghezza del connettore rispettando:
## - min_width_tiles
## - max_width_abs
## - max_width_ratio
##
## NOTA:
## La larghezza è indipendente dallo stato della mask.
# ============================================================================

static func _compute_width(
	mask: RoomLayoutMask,
	profile: ConnectorProfile,
	dir: int
) -> int:

	var useful_space: int

	if dir == Dir4.D.N or dir == Dir4.D.S:
		useful_space = mask.size.x - 2 * (mask.wall_thickness + profile.corner_margin_tiles)
	else:
		useful_space = mask.size.y - 2 * (mask.wall_thickness + profile.corner_margin_tiles)

	var max_ratio_width := int(useful_space * profile.max_width_ratio)
	var max_width: int = min(profile.max_width_abs, max_ratio_width)

	return clamp(
		profile.min_width_tiles,
		profile.min_width_tiles,
		max_width
	)

# ============================================================================
# ConnectorPlanner
# ============================================================================
## Pianifica le posizioni dei 4 connettori (N/E/S/W) sul bordo esterno.
##
## RESPONSABILITÀ:
## - Individuare segmenti interni validi dietro il bordo
## - Applicare i vincoli di ConnectorProfile
## - Restituire un ConnectorPlan completo
##
## NON FA:
## - Non apre varchi
## - Non modifica la mask
## - Non valida traversal
##
## Se anche un solo lato non trova segmento valido → ritorna null
# ============================================================================

class_name ConnectorPlanner
extends RefCounted


# ============================================================================
# API PUBBLICA
# ============================================================================

static func build(
	mask: RoomLayoutMask
) -> ConnectorPlan:

	var plan := ConnectorPlan.new()
	var profile := ConnectorProfile.new()

	for d in Dir4.ORDER:

		var result := _plan_for_direction(mask, profile, d)
		if result == null:
			return null

		plan.set_opening(d, result.coord, result.width)

	return plan


# ============================================================================
# DIREZIONE SINGOLA
# ============================================================================

static func _plan_for_direction(
	mask: RoomLayoutMask,
	profile: ConnectorProfile,
	dir: int
) -> Dictionary:

	var segments: Array = _collect_internal_segments(mask, profile, dir)
	if segments.is_empty():
		return {}

	# deterministico: scegli il segmento più lungo
	segments.sort_custom(func(a,b): return a.length > b.length)
	var segment = segments[0]

	var width: int = _compute_width(mask, profile, dir, segment.length)

	# centrato nel segmento
	var coord: int = segment["start"] + width / 2

	return {
		"coord": coord,
		"width": width
	}


# ============================================================================
# RACCOLTA SEGMENTI INTERNI
# ============================================================================

static func _collect_internal_segments(
	mask: RoomLayoutMask,
	profile: ConnectorProfile,
	dir: int
) -> Array:

	var segments := []

	var wall := mask.wall_thickness
	var margin := profile.corner_margin_tiles
	var min_w := profile.min_width_tiles

	match dir:

		Dir4.D.N:
			var y := wall
			segments = _scan_horizontal(mask, y, wall + margin, mask.size.x - wall - margin, min_w)

		Dir4.D.S:
			var y := mask.size.y - wall - 1
			segments = _scan_horizontal(mask, y, wall + margin, mask.size.x - wall - margin, min_w)

		Dir4.D.W:
			var x := wall
			segments = _scan_vertical(mask, x, wall + margin, mask.size.y - wall - margin, min_w)

		Dir4.D.E:
			var x := mask.size.x - wall - 1
			segments = _scan_vertical(mask, x, wall + margin, mask.size.y - wall - margin, min_w)

	return segments


# ============================================================================
# SCAN ORIZZONTALE
# ============================================================================

static func _scan_horizontal(
	mask: RoomLayoutMask,
	y: int,
	from_x: int,
	to_x: int,
	min_w: int
) -> Array:

	var segments := []
	var start := -1

	for x in range(from_x, to_x):

		if mask.is_empty(x, y):
			if start == -1:
				start = x
		else:
			if start != -1:
				var length := x - start
				if length >= min_w:
					segments.append({ "start": start, "length": length })
				start = -1

	if start != -1:
		var length := to_x - start
		if length >= min_w:
			segments.append({ "start": start, "length": length })

	return segments


# ============================================================================
# SCAN VERTICALE
# ============================================================================

static func _scan_vertical(
	mask: RoomLayoutMask,
	x: int,
	from_y: int,
	to_y: int,
	min_w: int
) -> Array:

	var segments: Array = []
	var start: int = -1

	for y in range(from_y, to_y):

		if mask.is_empty(x, y):
			if start == -1:
				start = y
		else:
			if start != -1:
				var length: int= y - start
				if length >= min_w:
					segments.append({ "start": start, "length": length })
				start = -1

	if start != -1:
		var length: int = to_y - start
		if length >= min_w:
			segments.append({ "start": start, "length": length })

	return segments


# ============================================================================
# CALCOLO WIDTH (VINCOLI PROFILO)
# ============================================================================

static func _compute_width(
	mask: RoomLayoutMask,
	profile: ConnectorProfile,
	dir: int,
	segment_length: int
) -> int:

	var useful_space: int

	if dir == Dir4.D.N or dir == Dir4.D.S:
		useful_space = mask.size.x - 2 * (mask.wall_thickness + profile.corner_margin_tiles)
	else:
		useful_space = mask.size.y - 2 * (mask.wall_thickness + profile.corner_margin_tiles)

	var max_ratio_width: int = int(useful_space * profile.max_width_ratio)
	var max_width: int = min(profile.max_width_abs, max_ratio_width)

	return clamp(segment_length, profile.min_width_tiles, max_width)

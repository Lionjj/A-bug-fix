class_name OpeningPolicy
extends Resource

var profile: ConnectorProfile = ConnectorProfile.new()

# ----- API principale -----

func usable_span(mask_size: Vector2i, wall_thickness: int, dir: int) -> int:
	# spazio utile lungo il bordo, tolti muri e corner margin
	var base: int
	
	var corner_margin_tiles: int = profile.corner_margin_tiles
	var min_width_tiles: int = profile.min_width_tiles
	
	if dir == Dir4.D.N or dir == Dir4.D.S:
		base = mask_size.x
	else:
		base = mask_size.y

	# tolgo: muri + margini corner
	var usable := base - 2 * wall_thickness - 2 * corner_margin_tiles
	return max(min_width_tiles, usable)


func max_width_for(mask_size: Vector2i, wall_thickness: int, dir: int) -> int:
	var usable: int = usable_span(mask_size, wall_thickness, dir)
	
	var max_width_ratio: float = profile.max_width_ratio
	var max_width_abs: int = profile.max_width_abs
	var min_width_tiles: int = profile.min_width_tiles

	var cap_ratio: int = int(floor(float(usable) * max_width_ratio))
	var cap: int = min(max_width_abs, cap_ratio)

	# clamp finale
	return clamp(cap, min_width_tiles, usable)


func pick_width(rng: RandomNumberGenerator, mask_size: Vector2i, wall_thickness: int, dir: int) -> int:
	var min_width_tiles: int = profile.min_width_tiles
	
	var lo: int = min_width_tiles
	var hi: int = max_width_for(mask_size, wall_thickness, dir)
	return rng.randi_range(lo, hi)


func margins_for(width_tiles: int) -> Vector2i:
	# (neg, pos) = metà sinistra / metà destra (o up/down)
	var min_width_tiles: int = profile.min_width_tiles
	
	width_tiles = max(min_width_tiles, width_tiles)
	var neg: int = width_tiles / 2
	var pos: int = width_tiles - neg
	return Vector2i(neg, pos)


func pick_coord(
	rng: RandomNumberGenerator,
	mask_size: Vector2i,
	wall_thickness: int,
	dir: int,
	width_tiles: int
) -> int:
	var m: Vector2i = margins_for(width_tiles)
	
	var corner_margin_tiles: int = profile.corner_margin_tiles

	if dir == Dir4.D.N or dir == Dir4.D.S:
		var min_x: int = wall_thickness + corner_margin_tiles + m.x
		var max_x: int = mask_size.x - wall_thickness - corner_margin_tiles - 1 - m.y
		return rng.randi_range(min_x, max_x)
	else:
		var min_y: int = wall_thickness + corner_margin_tiles + m.x
		var max_y: int = mask_size.y - wall_thickness - corner_margin_tiles - 1 - m.y
		return rng.randi_range(min_y, max_y)


func build_plan(
	mask: RoomLayoutMask,
	rng: RandomNumberGenerator,
	required_mask: int
) -> ConnectorPlan:
	var plan := ConnectorPlan.new()

	var sz: Vector2i = mask.size
	var t: int = mask.wall_thickness

	# iterazione stabile: N,E,S,W
	for d in Dir4.ORDER:
		if not Dir4.has(required_mask, d):
			continue

		var w: int = pick_width(rng, sz, t, d)
		var c: int = _pick_coord_safe(rng, sz, t, d, w)

		plan.set_opening(d, c, w)

	# opzionale: se vuoi spacing tra aperture su lati opposti
	# _enforce_spacing_if_needed(plan, rng, sz, t)

	return plan


# -------------------------------------------------------
# Helpers
# -------------------------------------------------------

func _pick_coord_safe(
	rng: RandomNumberGenerator,
	mask_size: Vector2i,
	wall_thickness: int,
	dir: int,
	width_tiles: int
) -> int:
	# stessa logica di pick_coord, ma con protezione se min>max
	var m: Vector2i = margins_for(width_tiles)
	var corner_margin_tiles: int = profile.corner_margin_tiles

	if dir == Dir4.D.N or dir == Dir4.D.S:
		var min_x: int = wall_thickness + corner_margin_tiles + m.x
		var max_x: int = mask_size.x - wall_thickness - corner_margin_tiles - 1 - m.y
		if min_x > max_x:
			# fallback: centro "clampato"
			return clampi(mask_size.x / 2, min_x, min_x)
		return rng.randi_range(min_x, max_x)
	else:
		var min_y: int = wall_thickness + corner_margin_tiles + m.x
		var max_y: int = mask_size.y - wall_thickness - corner_margin_tiles - 1 - m.y
		if min_y > max_y:
			return clampi(mask_size.y / 2, min_y, min_y)
		return rng.randi_range(min_y, max_y)

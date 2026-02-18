# ============================================================================
# DividerOperator
# ============================================================================
## Operatore di layout PRIMARIO.
##
## Inserisce uno o più divider (muri continui) lungo UN solo asse
## e genera passaggi completamente attraversabili.
##
## Comportamento IDENTICO al divider originale,
## ma con parametri derivati da RoomSizeProfile.
# ============================================================================

class_name DividerOperator
extends LayoutOperator


func _init(_context: OperatorContext, params: Dictionary = {}):
	super._init(_context, params)
	type = Type.DIVIDER
	weight = 0.3
	role = Role.PRIMARY

# ---------------------------------------------------------------------------
# API
# ---------------------------------------------------------------------------

func apply() -> bool:
	var profile: RoomSizeProfile = context.size_profile
	var rng: RandomNumberGenerator = context.rng
	
	# -----------------------------------------------------------------------
	# Parametri evolvibili
	# -----------------------------------------------------------------------
	var vertical: bool = params.get("is_vertical", false)
	
	var count: int = params.get("divider_count", 0)
	
	return _apply_multi(vertical, count)

func create_random_params() -> Dictionary:
	var profile := context.size_profile
	var rng := context.rng
	
	var vertical_bias: float = rng.randf_range(
			profile.min_divider_vertical,
			profile.max_divider_vertical
		)
	return {
		"divider_count": rng.randi_range(
			profile.min_divider_count,
			profile.max_divider_count
		),
		
		"vertical_bias": vertical_bias,
		
		"is_vertical": vertical_bias < profile.divider_threshold_vertical
	}

func mutate_params() -> void:
	var profile := context.size_profile
	var rng := context.rng
	
	params["divider_count"] = clamp(
		params["divider_count"] + rng.randi_range(-1, 1),
		profile.min_divider_count,
		profile.max_divider_count
	)
	
	params["vertical_bias"] = clamp(
		params["vertical_bias"] + rng.randf_range(-0.1, 0.1),
		profile.min_divider_vertical,
		profile.max_divider_vertical
	)
	
	params["is_vertical"] = params["vertical_bias"] < profile.divider_threshold_vertical


# ---------------------------------------------------------------------------
# Multi-divider (stesso asse)
# ---------------------------------------------------------------------------

func _apply_multi(vertical: bool, count: int) -> bool:
	var profile := context.size_profile
	var rng := context.rng

	var max_dividers := _max_dividers_for_size(vertical)
	if max_dividers <= 0:
		return false

	count = clamp(count, context.size_profile.min_divider_count, max_dividers)
	var positions := _pick_divider_positions(vertical, count)

	if positions.is_empty():
		return false

	for pos in positions:
		if vertical:
			_apply_vertical_at(pos)
		else:
			_apply_horizontal_at(pos)

	return true


# ---------------------------------------------------------------------------
# Divider verticale
# ---------------------------------------------------------------------------

func _apply_vertical_at(x0: int) -> void:
	var profile := context.size_profile
	var mask := context.mask
	
	var wt := profile.wall_thickness

	var margin := profile.border_margin_wall
	var y0 := margin
	var y1 := mask.size.y - margin - 1

	for y in range(y0, y1 + 1):
		for dx in range(wt):
			mask.set_solid(x0 + dx, y)

	var passages := _build_passages(
		y0, y1, x0, wt, true
	)

	_carve_passages(mask, passages)


# ---------------------------------------------------------------------------
# Divider orizzontale
# ---------------------------------------------------------------------------

func _apply_horizontal_at(
	y0: int
) -> void:
	var profile := context.size_profile
	var mask := context.mask
	
	var wt := profile.wall_thickness

	var margin := profile.border_margin_ceil_flor
	var x0 := margin
	var x1 := mask.size.x - margin - 1

	for x in range(x0, x1 + 1):
		for dy in range(wt):
			mask.set_solid(x, y0 + dy)

	var passages := _build_passages(
		x0, x1, y0, wt, false
	)

	_carve_passages(mask, passages)


# ---------------------------------------------------------------------------
# Costruzione passaggi (identica all'originale)
# ---------------------------------------------------------------------------

func _build_passages(
	main_min: int,
	main_max: int,
	fixed_pos: int,
	wall_thickness: int,
	vertical: bool
) -> Array[Rect2i]:
	var profile := context.size_profile
	var rng := context.rng

	var passages: Array[Rect2i] = []
	var gap_count := rng.randi_range(1, 2)

	var free_intervals: Array[Vector2i] = [Vector2i(main_min, main_max)]

	for _i in range(gap_count):
		if free_intervals.is_empty():
			break

		var idx := rng.randi_range(0, free_intervals.size() - 1)
		var iv := free_intervals[idx]

		var width := rng.randi_range(
			profile.opening_min_tiles,
			profile.opening_max_tiles
		)

		if iv.y - iv.x + 1 < width:
			free_intervals.remove_at(idx)
			continue

		var m := rng.randi_range(iv.x, iv.y - width + 1)

		var rect := (
			Rect2i(Vector2i(fixed_pos, m), Vector2i(wall_thickness, width))
			if vertical
			else Rect2i(Vector2i(m, fixed_pos), Vector2i(width, wall_thickness))
		)

		passages.append(rect)

		var dist := profile.min_passage_tiles
		var new_intervals: Array[Vector2i] = []

		if m > iv.x:
			new_intervals.append(Vector2i(iv.x, m - dist))
		if m + width <= iv.y:
			new_intervals.append(Vector2i(m + width + dist, iv.y))

		free_intervals = new_intervals

	return passages


# ---------------------------------------------------------------------------
# Scavo passaggi (semplice, come l'originale)
# ---------------------------------------------------------------------------

static func _carve_passages(mask: RoomLayoutMask, passages: Array[Rect2i]) -> void:
	for r in passages:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				mask.set_empty(x, y)


# ---------------------------------------------------------------------------
# Numero massimo divider (come prima)
# ---------------------------------------------------------------------------

func _max_dividers_for_size(vertical: bool) -> int:
	var mask := context.mask
	var profile := context.size_profile
	
	var axis := mask.size.x if vertical else mask.size.y
	var sep := profile.min_divider_separator

	if axis < sep * 2:
		return 1
	if axis < sep * 4:
		return 2
	return profile.max_divider_count


# ---------------------------------------------------------------------------
# Selezione posizioni divider
# ---------------------------------------------------------------------------

func _pick_divider_positions(vertical: bool, count: int) -> Array[int]:
	var mask := context.mask
	var profile := context.size_profile
	var rng := context.rng
	
	var axis := mask.size.x if vertical else mask.size.y

	var border := (
		profile.border_margin_wall
		if vertical
		else profile.border_margin_ceil_flor
	)

	# distanza minima dal muro
	var margin := border + profile.min_passage_tiles
	var max := axis - margin - profile.wall_thickness

	if margin >= max:
		return []

	var intervals: Array[Vector2i] = [Vector2i(margin, max)]
	var out: Array[int] = []

	# distanza minima TRA divider
	var sep := profile.min_divider_separator

	while not intervals.is_empty() and out.size() < count:
		var iv :Vector2i= intervals.pop_back()

		if iv.y - iv.x < profile.wall_thickness:
			continue

		var p := rng.randi_range(iv.x, iv.y)
		out.append(p)

		intervals.append(Vector2i(iv.x, p - sep))
		intervals.append(Vector2i(p + sep, iv.y))

	return out

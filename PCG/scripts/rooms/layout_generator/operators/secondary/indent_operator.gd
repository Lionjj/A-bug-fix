# ============================================================================
# IndentOperator
# ============================================================================
## Operatore di layout LOCALE (SECONDARIO).
##
## RESPONSABILITÀ:
## - Creare rientranze (indent) SOLO nei muri perimetrali
## - Aumentare la varietà spaziale senza dividere la stanza
##
## GARANZIE:
## - NON divide la stanza
## - NON crea varchi passanti
## - NON modifica la connettività globale
## - NON rompe Divider / Pillar / Platform / Ring
##
## FILOSOFIA:
## - Usa Dir4 come sistema direzionale unico
## - Tutte le misure derivano dal RoomSizeProfile
## - Se l'indent non è valido → fallisce silenziosamente
##
## ORDINE CONSIGLIATO:
## Divider → Indent → Platform → Ring → Connector → Score
# ============================================================================

class_name IndentOperator
extends LayoutOperator

func _init() -> void:
	type = Type.INDENT
	weight = 0.25
	role = Role.SECONDARY

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func apply(mask: RoomLayoutMask, context: LayoutContext, params: Dictionary = {}) -> bool:
	var profile: RoomSizeProfile = context.size_profile
	var rng: RandomNumberGenerator = context.rng
	
	# -----------------------------------------------------------------------
	# Parametri evolvibili
	# -----------------------------------------------------------------------
	var width: int = params.get("indet_width", profile.min_width_indent)
	
	var depth: int = params.get("indet_depth", profile.min_depth_indent)
	
	var count: int = params.get("indet_count", profile.min_indent_count)
	
	var side: Dir4.D = params.get("indet_side", 0)

	return _indent_from_dir(mask, profile, rng, side, width, depth)

func create_random_params(rng: RandomNumberGenerator, profile: RoomSizeProfile) -> Dictionary:
	var indent_count: int = rng.randi_range(
			profile.min_indent_count, 
			profile.max_indent_count
	)
	
	var mask: int = Dir4.get_random_mask(rng, indent_count)
		
	return {
		"indet_width": rng.randi_range(
			profile.min_width_indent, 
			profile.max_width_indent
		),
		
		"indet_depth": rng.randi_range(
			profile.min_depth_indent, 
			profile.max_depth_indent
		),
		
		"indet_count": indent_count,
		
		"indet_side": mask
	}

func mutate_params(params: Dictionary, rng: RandomNumberGenerator, profile: RoomSizeProfile) -> void:
	params["indet_width"] = clamp(
		params["indet_width"] + rng.randi_range(-1, 1),
		profile.min_width_indent,
		profile.max_width_indent
	)
	
	params["indet_depth"] = clamp(
		params["indet_depth"] + rng.randi_range(-1, 1),
		profile.min_depth_indent, 
		profile.max_depth_indent
	)
	
	params["indet_count"] = clamp(
		params["indet_count"] + rng.randi_range(-1, 1),
		profile.min_indent_count, 
		profile.max_indent_count
	)
	
	var mask: int = params["indet_side"]
	params["indet_side"] = _mute_mask(rng, mask)



# ---------------------------------------------------------------------------
# Single indent
# ---------------------------------------------------------------------------

#static func _apply_single(
	#mask: RoomLayoutMask,
	#profile: RoomSizeProfile,
	#rng: RandomNumberGenerator
#) -> bool:
	## copia DIREZIONI usando Dir4 (Array, non PackedInt32Array)
	#var dirs: Array[int] = []
	#for d in Dir4.ORDER:
		#dirs.append(d)
#
	## shuffle valido (Array.shuffle esiste)
	#dirs.shuffle()
#
	#for d in dirs:
		#if _indent_from_dir(mask, profile, rng, d):
			#return true
#
	#return false


# ---------------------------------------------------------------------------
# Indent per direzione
# ---------------------------------------------------------------------------

static func _indent_from_dir(
	mask: RoomLayoutMask,
	profile: RoomSizeProfile,
	rng: RandomNumberGenerator,
	side: int,
	width: int, 
	depth: int
) -> bool:
	var margin := profile.border_margin_wall

	match side:
		# ----------------------------
		# NORTH (soffitto)
		# ----------------------------
		Dir4.D.N:
			return _indent_rect(
				mask,
				Rect2i(
					Vector2i(
						rng.randi_range(margin, mask.size.x - margin - width),
						margin
					),
					Vector2i(width, depth)
				)
			)

		# ----------------------------
		# SOUTH (pavimento)
		# ----------------------------
		Dir4.D.S:
			return _indent_rect(
				mask,
				Rect2i(
					Vector2i(
						rng.randi_range(margin, mask.size.x - margin - width),
						mask.size.y - margin - depth
					),
					Vector2i(width, depth)
				)
			)

		# ----------------------------
		# WEST (muro sinistro)
		# ----------------------------
		Dir4.D.W:
			return _indent_rect(
				mask,
				Rect2i(
					Vector2i(
						margin,
						rng.randi_range(margin, mask.size.y - margin - width)
					),
					Vector2i(depth, width)
				)
			)

		# ----------------------------
		# EAST (muro destro)
		# ----------------------------
		Dir4.D.E:
			return _indent_rect(
				mask,
				Rect2i(
					Vector2i(
						mask.size.x - margin - depth,
						rng.randi_range(margin, mask.size.y - margin - width)
					),
					Vector2i(depth, width)
				)
			)

	return false


# ---------------------------------------------------------------------------
# Validazione + scavo (CRITICO)
# ---------------------------------------------------------------------------

static func _indent_rect(mask: RoomLayoutMask, rect: Rect2i) -> bool:
	# 1) validazione: SOLO muri perimetrali solidi
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not mask.in_bounds(x, y):
				return false
			if not mask.is_solid(x, y):
				return false

	# 2) scavo atomico (sicuro)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			mask.set_empty(x, y)

	return true
	

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

func _mute_mask(rng: RandomNumberGenerator, mask: int) -> int:
	var _mask: int = mask
	match rng.randi_range(0, 2):

		0:
			# aggiungi lato
			var side: int = Dir4.get_random_side_not_in_mask(rng, mask)
			_mask = Dir4.add(mask, side)

		1:
			# rimuovi lato (solo se >1)
			if Dir4.bit_count(mask) > 1:
				var side: int = Dir4.get_random_side_in_mask(rng, mask)
				_mask = Dir4.remove(mask, side)

		2:
			# toggle lato
			var side: int = Dir4.get_random_side(rng)
			if Dir4.has(mask, side):
				_mask = Dir4.remove(mask, side)
			else:
				_mask = Dir4.add(mask, side)
	
	return _mask

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


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

static func apply(mask: RoomLayoutMask, context: LayoutContext, params: Dictionary = {}) -> bool:
	var profile: RoomSizeProfile = context.size_profile
	var rng: RandomNumberGenerator = context.rng
	
	# -----------------------------------------------------------------------
	# Parametri evolvibili
	# -----------------------------------------------------------------------
	var width: int = params.get("width", 0)
	
	var depth: int = params.get("depth", 0)
	
	var side: Dir4.D = params.get("side", 0)

	return _indent_from_dir(mask, profile, rng, side, width, depth)


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

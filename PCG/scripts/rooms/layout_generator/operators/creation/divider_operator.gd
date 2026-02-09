# ============================================================================
# DividerOperator
# ============================================================================
## Operatore di layout primario per la generazione procedurale delle stanze.
##
## [b]Responsabilità[/b]:[br]
## - Inserisce un muro continuo che divide la stanza in due regioni.[br]
## - Genera uno o più passaggi rettangolari completamente aperti.[br]
##
## [b]Garanzie[/b]:[br]
## - clearance globale tra superfici create e bordi stanza.[br]
## - distanza minima tra i varchi.[br]
## - varchi sempre completamente scavati (nessun muro residuo).[br]
##
## [b]Note di design[/b]:[br]
## - La connettività globale è mantenuta tramite i passaggi.[br]
## - I connettori N/E/S/W NON vengono gestiti qui.[br]
##
## Ordine consigliato nella pipeline:[br]
## Size → Divider → Indent → Connector → Platform
# ============================================================================

class_name DividerOperator
extends LayoutOperator


# ---------------------------------------------------------------------------
# Policy globale
# ---------------------------------------------------------------------------

## distanza minima dai bordi stanza.[br]
## Protegge:[br]
## - angoli[br]
## - spazio per connettori futuri[br]
## - leggibilità topologica
const BORDER_MARGIN := 3

## distanza minima globale tra divider orizzontale[br]
## e pavimento/soffitto della stanza.
const MIN_FLOOR_CLEARANCE := 4   # divider orizzontale

## distanza minima globale tra divider verticale[br]
## e muri laterali della stanza.
const MIN_WALL_CLEARANCE  := 4   # divider verticale


# ---------------------------------------------------------------------------
# Varchi
# ---------------------------------------------------------------------------

## numero minimo di passaggi.
const MIN_GAPS := 1

## numero massimo di passaggi.
const MAX_GAPS := 2

## larghezza minima del passaggio (asse principale).
const GAP_MIN_WIDTH := 4

## larghezza massima del passaggio (asse principale).
const GAP_MAX_WIDTH := 6

## profondità del passaggio oltre lo spessore del muro.
const GAP_PASSAGE_SIZE := 4

## distanza minima tra due passaggi distinti.
const GAP_MIN_DISTANCE := 3


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

## Applica un Divider alla stanza.[br]
##
## Sceglie casualmente tra:[br]
## - divider verticale[br]
## - divider orizzontale[br]
##
## [param mask]: maschera logica della stanza.[br]
## [param rng]: generatore random deterministico.[br]
##
## [return]:[br]
## - true se il divider è stato applicato.[br]
## - false se non c’è spazio sufficiente.
func apply(mask: RoomLayoutMask, rng: RandomNumberGenerator) -> bool:
	var vertical := rng.randf() < 0.5
	return _apply_multi(mask, rng, vertical)


# ---------------------------------------------------------------------------
# Divider verticale
# ---------------------------------------------------------------------------

## Inserisce un muro verticale con passaggi.[br]
##
## Vincoli:[br]
## - distanza minima dai muri laterali[br]
## - passaggi non sovrapposti[br]
## - clearance globale rispettata
func _apply_vertical(mask: RoomLayoutMask, rng: RandomNumberGenerator) -> bool:
	var wt := mask.wall_thickness

	var x_min := BORDER_MARGIN + MIN_WALL_CLEARANCE
	var x_max := mask.size.x - BORDER_MARGIN - MIN_WALL_CLEARANCE - wt
	if x_min >= x_max:
		return false

	var x0 := rng.randi_range(x_min, x_max)

	var y0 := BORDER_MARGIN
	var y1 := mask.size.y - BORDER_MARGIN - 1

	# 1) costruzione muro completo
	for y in range(y0, y1 + 1):
		for dx in range(wt):
			mask.set_solid(x0 + dx, y)

	# 2) generazione passaggi
	var passages := _build_passages(
		y0, y1, x0, wt, rng, true
	)

	# 3) scavo passaggi
	_carve_passages(mask, passages)

	return true


# ---------------------------------------------------------------------------
# Divider orizzontale
# ---------------------------------------------------------------------------

## Inserisce un muro orizzontale con passaggi.[br]
##
## Vincoli:[br]
## - distanza minima da pavimento e soffitto[br]
## - passaggi non sovrapposti[br]
## - clearance globale rispettata
func _apply_horizontal(mask: RoomLayoutMask, rng: RandomNumberGenerator) -> bool:
	var wt := mask.wall_thickness

	var y_min := BORDER_MARGIN + MIN_FLOOR_CLEARANCE
	var y_max := mask.size.y - BORDER_MARGIN - MIN_FLOOR_CLEARANCE - wt
	if y_min >= y_max:
		return false

	var y0 := rng.randi_range(y_min, y_max)

	var x0 := BORDER_MARGIN
	var x1 := mask.size.x - BORDER_MARGIN - 1

	# 1) costruzione muro completo
	for x in range(x0, x1 + 1):
		for dy in range(wt):
			mask.set_solid(x, y0 + dy)

	# 2) generazione passaggi
	var passages := _build_passages(
		x0, x1, y0, wt, rng, false
	)

	# 3) scavo passaggi
	_carve_passages(mask, passages)

	return true


# ---------------------------------------------------------------------------
# Divider multiplo
# ---------------------------------------------------------------------------

func _apply_multi(
	mask: RoomLayoutMask,
	rng: RandomNumberGenerator,
	vertical: bool
) -> bool:
	var max_dividers := _max_dividers_for_size(mask, vertical)
	if max_dividers <= 0:
		return false

	var count := rng.randi_range(1, max_dividers)

	var positions := _pick_divider_positions(mask, rng, vertical, count)
	if positions.is_empty():
		return false

	for pos in positions:
		if vertical:
			_apply_vertical_at(mask, rng, pos)
		else:
			_apply_horizontal_at(mask, rng, pos)

	return true


# ---------------------------------------------------------------------------
# Builder passaggi
# ---------------------------------------------------------------------------

## Costruisce i passaggi come Rect2i assoluti.[br]
##
## [param main_min]: inizio asse principale.[br]
## [param main_max]: fine asse principale.[br]
## [param fixed_pos]: coordinata fissa del muro.[br]
## [param wall_thickness]: spessore del muro.[br]
## [param rng]: generatore random.[br]
## [param vertical]: true se divider verticale.[br]
##
## [return]: array di Rect2i pronti per lo scavo.
func _build_passages(
	main_min: int,
	main_max: int,
	fixed_pos: int,
	wall_thickness: int,
	rng: RandomNumberGenerator,
	vertical: bool
) -> Array[Rect2i]:

	var passages: Array[Rect2i] = []
	var gap_count := rng.randi_range(MIN_GAPS, MAX_GAPS)

	var free_intervals : Array[Vector2i] = [Vector2i(main_min, main_max)]

	for _i in range(gap_count):
		if free_intervals.is_empty():
			break

		var idx := rng.randi_range(0, free_intervals.size() - 1)
		var iv := free_intervals[idx]

		var width := rng.randi_range(GAP_MIN_WIDTH, GAP_MAX_WIDTH)
		if iv.y - iv.x + 1 < width:
			free_intervals.remove_at(idx)
			continue

		var m := rng.randi_range(iv.x, iv.y - width + 1)

		var rect: Rect2i
		if vertical:
			rect = Rect2i(
				Vector2i(fixed_pos, m),
				Vector2i(wall_thickness + GAP_PASSAGE_SIZE, width)
			)
		else:
			rect = Rect2i(
				Vector2i(m, fixed_pos),
				Vector2i(width, wall_thickness + GAP_PASSAGE_SIZE)
			)

		passages.append(rect)

		var new_intervals: Array[Vector2i] = []
		if m > iv.x:
			new_intervals.append(Vector2i(iv.x, m - GAP_MIN_DISTANCE - 1))
		if m + width <= iv.y:
			new_intervals.append(Vector2i(m + width + GAP_MIN_DISTANCE, iv.y))

		free_intervals = new_intervals

	return passages


# ---------------------------------------------------------------------------
# Scavo passaggi
# ---------------------------------------------------------------------------

## Scava fisicamente i passaggi nella maschera.[br]
##
## [param mask]: maschera logica stanza.[br]
## [param passages]: array di Rect2i da scavare.
func _carve_passages(mask: RoomLayoutMask, passages: Array[Rect2i]) -> void:
	for r in passages:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				mask.set_empty(x, y)

# ============================================================================
# IndentOperator
# ============================================================================
## Operatore di layout locale per la generazione procedurale delle stanze.[br]
##
## [b]Responsabilità[/b]:[br]
## - Crea rientranze (indent) nei muri perimetrali.[br]
## - Aumenta la varietà spaziale senza dividere la stanza.[br]
##[br]
## [b]Garanzie[/b]:[br]
## - NON divide la stanza.[br]
## - NON crea varchi passanti.[br]
## - NON modifica la connettività globale.[br]
##[br]
## [b]Uso[/b] tipico:[br]
## - nicchie visive[br]
## - prep choke point[br]
## - prep piattaforme / appigli[br]
##[br]
## Ordine consigliato nella pipeline:[br]
## Size → Divider → Indent → Connector → Platform
# ============================================================================

class_name IndentOperator
extends LayoutOperator


# ---------------------------------------------------------------------------
# Policy
# ---------------------------------------------------------------------------

## distanza minima dai bordi stanza.[br]
## Protegge:[br]
## - angoli[br]
## - futuri connettori[br]
## - leggibilità topologica
const BORDER_MARGIN := 3

## numero minimo di rientranze tentate per stanza.
const MIN_INDENTS := 1

## numero massimo di rientranze tentate per stanza.
const MAX_INDENTS := 2

## larghezza minima dell’indent (asse principale).
const INDENT_MIN_WIDTH := 4

## larghezza massima dell’indent (asse principale).
const INDENT_MAX_WIDTH := 8

## profondità minima dell’indent (quanto entra nella stanza).
const INDENT_MIN_DEPTH := 4

## profondità massima dell’indent.
const INDENT_MAX_DEPTH := 8

## distanza minima tra due indents.[br]
## Nota: placeholder per estensione futura.
const MIN_DISTANCE_BETWEEN_INDENTS := 4


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

## Applica uno o più indents alla RoomLayoutMask.[br]
##
## [param mask]: maschera logica della stanza.[br]
## [param rng]: generatore random deterministico.[br]
##
## [return]:[br]
## - true se almeno un indent è stato applicato.[br]
## - false se nessuna operazione ha avuto successo.
func apply(mask: RoomLayoutMask, rng: RandomNumberGenerator) -> bool:
	var count := rng.randi_range(MIN_INDENTS, MAX_INDENTS)
	var success := false

	for _i in range(count):
		success = _apply_single(mask, rng) or success

	return success


# ---------------------------------------------------------------------------
# Single indent
# ---------------------------------------------------------------------------

## Applica un singolo indent scegliendo casualmente il lato.[br]
##
## Lati:[br]
## - 0 = Nord (soffitto)[br]
## - 1 = Sud (pavimento)[br]
## - 2 = Ovest (muro sinistro)[br]
## - 3 = Est  (muro destro)
func _apply_single(mask: RoomLayoutMask, rng: RandomNumberGenerator) -> bool:
	var side := rng.randi_range(0, 3)

	match side:
		0: return _indent_from_north(mask, rng)
		1: return _indent_from_south(mask, rng)
		2: return _indent_from_west(mask, rng)
		3: return _indent_from_east(mask, rng)

	return false


# ---------------------------------------------------------------------------
# Vertical indents (W / E)
# ---------------------------------------------------------------------------

## Indent scavato dal muro Ovest.[br]
##
## Forma:[br]
## - rettangolo che entra nella stanza verso Est[br]
## - larghezza verticale casuale[br]
## - profondità orizzontale casuale
func _indent_from_west(mask: RoomLayoutMask, rng: RandomNumberGenerator) -> bool:
	var y_min := BORDER_MARGIN
	var y_max := mask.size.y - BORDER_MARGIN - 1

	var width := rng.randi_range(INDENT_MIN_WIDTH, INDENT_MAX_WIDTH)
	var depth := rng.randi_range(INDENT_MIN_DEPTH, INDENT_MAX_DEPTH)

	if y_max - y_min + 1 < width:
		return false

	var y0 := rng.randi_range(y_min, y_max - width + 1)
	var x0 := BORDER_MARGIN

	_carve_rect(mask, Rect2i(
		Vector2i(x0, y0),
		Vector2i(depth, width)
	))

	return true


## Indent scavato dal muro Est.
func _indent_from_east(mask: RoomLayoutMask, rng: RandomNumberGenerator) -> bool:
	var y_min := BORDER_MARGIN
	var y_max := mask.size.y - BORDER_MARGIN - 1

	var width := rng.randi_range(INDENT_MIN_WIDTH, INDENT_MAX_WIDTH)
	var depth := rng.randi_range(INDENT_MIN_DEPTH, INDENT_MAX_DEPTH)

	if y_max - y_min + 1 < width:
		return false

	var y0 := rng.randi_range(y_min, y_max - width + 1)
	var x0 := mask.size.x - BORDER_MARGIN - depth

	_carve_rect(mask, Rect2i(
		Vector2i(x0, y0),
		Vector2i(depth, width)
	))

	return true


# ---------------------------------------------------------------------------
# Horizontal indents (N / S)
# ---------------------------------------------------------------------------

## Indent scavato dal soffitto (Nord).
func _indent_from_north(mask: RoomLayoutMask, rng: RandomNumberGenerator) -> bool:
	var x_min := BORDER_MARGIN
	var x_max := mask.size.x - BORDER_MARGIN - 1

	var width := rng.randi_range(INDENT_MIN_WIDTH, INDENT_MAX_WIDTH)
	var depth := rng.randi_range(INDENT_MIN_DEPTH, INDENT_MAX_DEPTH)

	if x_max - x_min + 1 < width:
		return false

	var x0 := rng.randi_range(x_min, x_max - width + 1)
	var y0 := BORDER_MARGIN

	_carve_rect(mask, Rect2i(
		Vector2i(x0, y0),
		Vector2i(width, depth)
	))

	return true


## Indent scavato dal pavimento (Sud).
func _indent_from_south(mask: RoomLayoutMask, rng: RandomNumberGenerator) -> bool:
	var x_min := BORDER_MARGIN
	var x_max := mask.size.x - BORDER_MARGIN - 1

	var width := rng.randi_range(INDENT_MIN_WIDTH, INDENT_MAX_WIDTH)
	var depth := rng.randi_range(INDENT_MIN_DEPTH, INDENT_MAX_DEPTH)

	if x_max - x_min + 1 < width:
		return false

	var x0 := rng.randi_range(x_min, x_max - width + 1)
	var y0 := mask.size.y - BORDER_MARGIN - depth

	_carve_rect(mask, Rect2i(
		Vector2i(x0, y0),
		Vector2i(width, depth)
	))

	return true


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

## Scava un rettangolo rendendo vuote le celle.[br]
##
## [param mask]: maschera logica stanza.[br]
## [param rect]: area rettangolare da scavare.[br]
##
## Nota:[br]
## - non effettua controlli di validità[br]
## - assume che il chiamante garantisca i vincoli
func _carve_rect(mask: RoomLayoutMask, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			mask.set_empty(x, y)

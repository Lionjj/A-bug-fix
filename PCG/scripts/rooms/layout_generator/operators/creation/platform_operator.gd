# ============================================================================
# PlatformOperator
# ============================================================================
## Operatore di layout per la creazione di piattaforme sospese.[br]
##
## Responsabilità:[br]
## - Inserisce superfici calpestabili interne alla stanza.[br]
## - Aggiunge verticalità e multi-layer di gameplay.[br]
##
## Garanzie:[br]
## - Piattaforme sempre piene e rettangolari.[br]
## - Rispetto delle distanze da SOLID esistenti.[br]
## - Nessuna modifica parziale della maschera.[br]
##
## Ordine consigliato:[br]
## Divider → Indent → Platform → (Ring) → Connector → Score
# ============================================================================

class_name PlatformOperator
extends LayoutOperator


# ---------------------------------------------------------------------------
# Policy
# ---------------------------------------------------------------------------

const BORDER_MARGIN := 3

const MIN_PLATFORMS := 1
const MAX_PLATFORMS := 3

const PLATFORM_MIN_WIDTH := 5
const PLATFORM_MAX_WIDTH := 10

const PLATFORM_MIN_THICKNESS := 2
const PLATFORM_MAX_THICKNESS := 3

const MIN_DISTANCE_FROM_FLOOR := 4
const MIN_DISTANCE_FROM_CEILING := 4

## distanza minima da QUALSIASI SOLID già presente
const MIN_SOLID_SPACING := 3


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func apply(mask: RoomLayoutMask, rng: RandomNumberGenerator) -> bool:
	var target := rng.randi_range(MIN_PLATFORMS, MAX_PLATFORMS)
	var placed := 0
	var attempts := target * 6

	while placed < target and attempts > 0:
		attempts -= 1
		if _try_place_platform(mask, rng):
			placed += 1

	return placed > 0


# ---------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------

func _try_place_platform(mask: RoomLayoutMask, rng: RandomNumberGenerator) -> bool:
	var width := rng.randi_range(PLATFORM_MIN_WIDTH, PLATFORM_MAX_WIDTH)
	var thicknes := rng.randi_range(PLATFORM_MIN_THICKNESS, PLATFORM_MAX_THICKNESS)

	var x_min := BORDER_MARGIN
	var x_max := mask.size.x - BORDER_MARGIN - width
	if x_min >= x_max:
		return false

	var y_min := BORDER_MARGIN + MIN_DISTANCE_FROM_CEILING
	var y_max := mask.size.y - BORDER_MARGIN - MIN_DISTANCE_FROM_FLOOR - thicknes
	if y_min >= y_max:
		return false

	var x0 := rng.randi_range(x_min, x_max)
	var y0 := rng.randi_range(y_min, y_max)

	var rect := Rect2i(
		Vector2i(x0, y0),
		Vector2i(width, thicknes)
	)

	# 1) tutte le celle devono essere EMPTY
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if mask.is_solid(x, y):
				return false

	# 2) spacing globale rispetto ai SOLID esistenti
	var spacing_rule := SolidSpacingRule.new(MIN_SOLID_SPACING)
	if not spacing_rule.passes_rect(mask, rect):
		return false

	# 3) scrittura finale (atomica)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			mask.set_solid(x, y)

	return true

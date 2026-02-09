# ============================================================================
# SolidSpacingRule
# ============================================================================
## Regola di validazione per evitare sovrapposizioni e collisioni
## tra nuove forme e celle SOLID già presenti.[br]
##
## Verifica che un rettangolo candidato sia ad almeno N celle
## di distanza da QUALSIASI altra cella SOLID nella maschera.
##
## - NON modifica la maschera
## - Riutilizzabile da tutti gli operatori
## - Semplice e prevedibile
# ============================================================================

class_name SolidSpacingRule
extends RefCounted


## [param min_spacing]: distanza minima richiesta in celle
var min_spacing: int


func _init(_min_spacing: int) -> void:
	min_spacing = _min_spacing


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

## Verifica che il rettangolo sia distante abbastanza
## da tutte le celle SOLID già presenti.[br]
##
## [param mask]: RoomLayoutMask corrente.[br]
## [param rect]: rettangolo candidato (NON ancora scritto).[br]
##
## [return]: true se il piazzamento è valido.
func passes_rect(mask: RoomLayoutMask, rect: Rect2i) -> bool:
	for y in range(rect.position.y - min_spacing, rect.end.y + min_spacing):
		for x in range(rect.position.x - min_spacing, rect.end.x + min_spacing):

			# fuori bounds → ignora
			if not mask.in_bounds(x, y):
				continue

			# ignora le celle che appartengono al rettangolo stesso
			if rect.has_point(Vector2i(x, y)):
				continue

			# qualsiasi SOLID troppo vicino → FAIL
			if mask.is_solid(x, y):
				return false

	return true

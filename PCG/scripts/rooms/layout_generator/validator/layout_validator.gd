# ============================================================================
# LayoutValidator
# ============================================================================
## Verifica se un layout è GIOCABILE
##
## RESPONSABILITÀ:
## - Validare la stanza secondo il player reale
# ============================================================================

class_name LayoutValidator
extends RefCounted

# ---------------------------------------------------------------------------
# ENTRY POINT
# ---------------------------------------------------------------------------

static func validate(context: LayoutValidatorContext, profile: PlayerTraversalProfile) -> bool:
	var mask := context.mask
	var plan := context.plan
	
	# ------------------------------------------------------------
	# Controlli base
	# ------------------------------------------------------------

	if mask == null:
		return false

	if mask.size.x <= 0 or mask.size.y <= 0:
		return false
	
	if plan == null:
		return false

	# ------------------------------------------------------------
	# Analisi traversal
	# ------------------------------------------------------------
	
	if not TraversalAnalyzer.are_floor_tile_reacable(mask, profile):
		printerr("LayoutValidator: le celle pavimento non sono tutte raggiungibili!")
		return false

	var mask_copy := mask.duplicate()
	if not TraversalAnalyzer.are_connectors_reacable(mask_copy, plan, profile):
		printerr("LayoutValidator: Uno dei connettori non è raggiungibile!")
		return false
		
	return true
	

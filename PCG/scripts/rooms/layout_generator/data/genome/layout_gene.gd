# ============================================================================
# LayoutGene
# ============================================================================
## Un singolo step di trasformazione del layout.
# ============================================================================

class_name LayoutGene
extends RefCounted

## Identificatore operatore (es. "divider", "indent", "platform")
var operator_id: String

## Parametri specifici dell’operatore
## (contenuto libero, dipende dall’operatore)
var params: Dictionary = {}

func _init(_operator_id: String, _params: Dictionary = {}):
	operator_id = _operator_id
	params = _params

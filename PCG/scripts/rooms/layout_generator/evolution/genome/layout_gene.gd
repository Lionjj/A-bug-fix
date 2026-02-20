# ============================================================================
# LayoutGene
# ============================================================================
## Un singolo step di trasformazione del layout.
# ============================================================================

class_name LayoutGene
extends RefCounted

## Identificatore operatore
var type: LayoutOperator.Type

## Parametri specifici dell’operatore
## (contenuto libero, dipende dall’operatore)
var params: Dictionary = {}

func _init(_type: LayoutOperator.Type, _params: Dictionary = {}):
	type = _type
	params = _params

func clone() -> LayoutGene:
	return LayoutGene.new(
		type,
		params.duplicate(true)
	)

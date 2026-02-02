## Direttive logiche usate per gestire lo spawn delle trappole nei MissionNode.
extends Resource
class_name TrapDirective

enum TrapType {NO_TRAPS, STATIC}

## Moltiplicatore del budget (valori consigliati tra 0.5 e 2.5).
@export var budget_mult: float = 1.0

## Tipo di gestione trappole nella stanza.
@export var trap_type: TrapType = TrapType.NO_TRAPS

func _init(_budget_mult: float = 1.0, _trap_type: TrapType = TrapType.NO_TRAPS) -> void:
	budget_mult = _budget_mult
	trap_type = _trap_type

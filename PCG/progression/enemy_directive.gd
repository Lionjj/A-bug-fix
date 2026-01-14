## Modulo contenente le informazioni sui nemici per i nodi [class MissionNode] del grafo [class MissionGraph].
extends Resource
class_name EnemyDirective

enum CombatType {NO_COMBAT, WAVES, BOSS}

## Moltiplicatore del budget (valori consigliati tra 0.5 e 2.5).
@export var budget_mult: float = 1.0
## Numero di ondate di nemici che avra la stanza.
@export var waves: int = 1
## Indica il tipo di combattimenti che ci saranno nella stanza.
@export var combat_type: CombatType = CombatType.NO_COMBAT

func _init(_budget_mult: float = 1.0, _waves: int = 1, _combat_type: CombatType = CombatType.NO_COMBAT) -> void:
	budget_mult = _budget_mult
	waves = _waves
	combat_type = _combat_type
	

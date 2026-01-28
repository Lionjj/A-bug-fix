## Modulo contenente i dati logicici condivise da tutte le decorazioni.
extends Resource
class_name Decoration

enum DECO_TYPE {GROUND, WALL, CEILING}

## Identificativo univoco della decorazione nel gioco.
@export var id: DecorationsRegistry.ID
## Tipo di decorazione.
@export var type: DECO_TYPE
## Quanto costa inserire il nemico nella stanza rispetto al suo budget.
@export var cost: int = 1
## Scena usata per istanziare l'oggetto in seguito
@export var scene: PackedScene
## Probabilità relativà che ha il nemico di essere isnerito nella stanza.
@export var weight: float = 1.0
## Numero massimo di nemici per stanza.
@export var max_per_room: int = 99

func _init(
	_id: DecorationsRegistry.ID = DecorationsRegistry.ID.DEFAULT,
	_type: DECO_TYPE = DECO_TYPE.GROUND,
	_cost: int = 1, 
	_scene: PackedScene = null,
	_weight: float = 1.0,
	_max_per_room: int = 99
) -> void:
		id = _id
		type = _type
		cost = _cost
		scene = _scene
		weight = _weight
		max_per_room = _max_per_room
		

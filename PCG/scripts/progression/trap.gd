extends Resource
class_name Trap

## Identificativo univoco della trappola nel gioco.
@export var id: TrapRegistry.ID
## Quanto costa inserire la trappola nella stanza rispetto al suo budget.
@export var cost: int = 1
## Scena usata per istanziare l'oggetto in seguito
@export var scene: PackedScene
## Probabilità relativà che ha la trappola di essere isnerita nella stanza.
@export var weight: float = 1.0
## Limite inferiore che stabilisce entro quali limiti di difficolta la trappola può apparire.
@export var min_difficulty: float = 0.0
## Limite superiore che stabilisce entro quali limiti di difficolta la trappola può apparire.
@export var max_difficulty: float = 9999.0
## Numero massimo di trappole per stanza.
@export var max_per_room: int = 99

func _init(
	_id: TrapRegistry.ID = TrapRegistry.ID.DEFAULT,
	_cost: int = 1, 
	_scene: PackedScene = null,
	_weight: float = 1.0,
	_min_difficulty: float = 0.0,
	_max_difficulty: float = 9999.0,
	_max_per_room: int = 99
) -> void:
		id = _id
		cost = _cost
		scene = _scene
		weight = _weight
		min_difficulty = _min_difficulty
		max_difficulty = _max_difficulty
		max_per_room = _max_per_room

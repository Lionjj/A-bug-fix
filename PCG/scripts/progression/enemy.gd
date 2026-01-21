## Modulo contenente i dati logicici condivisi da tutti i nemici dle gioco.
extends Resource
class_name Enemy

## Identificativo univoco del nemico nel gioco.
@export var id: EnemiesRegistry.ID
## Quanto costa inserire il nemico nella stanza rispetto al suo budget.
@export var cost: int = 1
## Scena usata per istanziare l'oggetto in seguito
@export var scene: PackedScene
## Probabilità relativà che ha il nemico di essere isnerito nella stanza.
@export var weight: float = 1.0
## Limite inferiore che stabilisce entro quali limiti di difficolta il nemico può apparire.
@export var min_difficulty: float = 0.0
## Limite superiore che stabilisce entro quali limiti di difficolta il nemico può apparire.
@export var max_difficulty: float = 9999.0
#@export var tags: Array[Enemy.kind]
## Numero massimo di nemici per stanza.
@export var max_per_room: int = 99

func _init(
	_id: EnemiesRegistry.ID = EnemiesRegistry.ID.DEFAULT,
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
		

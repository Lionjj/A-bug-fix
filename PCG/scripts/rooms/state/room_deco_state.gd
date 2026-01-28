## Modulo usato per gestire le decorazioni presenti in una stanza.
extends Node
class_name RoomDecoState

## Punti di spawn disponibili.
var spawn_points: Array[Vector2i] = []

## Coda di ID di decorazioni che devono essere istanziati.
var queue: Array[EnemiesRegistry.ID] = []

## Lista di riferimenti alle decorazioni della stanza corrente, 
## variabile di utilità per semplificarne il loro accesso e la loro gestione.
var deco_references: Array[DecorationEntity] = []

func _init(
	_spawn_points: Array[Vector2i] = [], 
	_queue: Array[EnemiesRegistry.ID] = [], 
	_deco_references: Array[DecorationEntity] = [] 
) -> void:
	spawn_points = _spawn_points
	queue = _queue
	deco_references = _deco_references

## Modulo usato per gestire le trappole presenti in una stanza.
extends Node
class_name RoomTrapState

## Punti di spawn disponibili.
var spawn_points: Array[Vector2i] = []

## Lista di ID di trappole che devono essere istanziati.
var traps: Array[TrapRegistry.ID] = []

## Lista di riferimenti alle trappole della stanza corrente, variabile di utilità per semplificarne 
## il loro accesso e la loro gestione.
var traps_references: Array[TrapEntity] = []

## Flag: ho già spawnato / preparato le trappole per questa stanza.
var spawned: bool = false

func _init(
_spawn_points: Array[Vector2i] = [],
_traps: Array[TrapRegistry.ID] = [],
_traps_references: Array[TrapEntity] = [],
_spawned: bool = false
) -> void:
	spawn_points = _spawn_points
	traps = _traps
	traps_references = _traps_references
	spawned = _spawned

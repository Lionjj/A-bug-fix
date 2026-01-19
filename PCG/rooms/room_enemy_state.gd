## Modulo usato per gestire i nemici presenti in una stanza.
extends Node
class_name RoomEnemyState

## Punti di spawn disponibili.
var spawn_points: Array[Vector2i] = []

## Numero di nemici per ondata che la stanza deve gestire, il numero di elementi della lista 
## rappresenta inoltre quante ondate ci sono.
var wave_plan: Array[int] = []
## Indice utilizzato per scorrere il numero di nemici presente in [meber wave_plan].
var wave_index: int = 0

## Coda di ID di nemici che devono essere istanziati.
var queue: Array[EnemiesRegistry.ID] = []

## Lista di riferimenti ai nemici della stanza corrente, variabile di utilità per semplificarne 
## il loro accesso e la loro gestione.
var enemies_references: Array[EnemyEntity] = []
## Indice utilizzato per scorrere i nemici presente in [meber enemies_references].
var enemy_index: int = 0

## Nemici effettivamente istanziati nella stanza.
var enemies_alive: Array[EnemyEntity] = []

## Totale dei nemici che devono essere sconfitti per "superare" la stanza.
var to_eliminate: int = 0

## Idica quando il combattimento ha inizio.s
var started: bool = false

## Indica quando è possibile fa inizizare il combattimento.
var prepared: bool = false


func _init(
_spawn_points: Array[Vector2i] = [],
_wave_plan: Array[int] = [],
_queue: Array[EnemiesRegistry.ID] = [],
_enemies_references: Array[EnemyEntity] = [],
_enemies_alive: Array[EnemyEntity] = [],
_to_eliminate: int = 0,
_started: bool = false,
_prepared: bool = false
) -> void:
	spawn_points = _spawn_points
	wave_plan = _wave_plan
	queue = _queue
	enemies_references = _enemies_references
	enemies_alive = _enemies_alive
	started = _started
	prepared = _prepared
	to_eliminate = _to_eliminate

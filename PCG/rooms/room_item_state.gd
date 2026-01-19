## Modulo utilizzato per gestire gli items che dovrano essere istanziati in una stanza.
extends Node
class_name RoomItemState

## Dizionario contenente il nome dell'oggetto e la quantità di oggetti che devono 
## essere istanziati.
var items : Dictionary[ItemRegistry.ID, int] = {}

## Lista di riferimenti agli oggetti della stanza corrente, variabile di utilità per semplificarne 
## il loro accesso e la loro gestione.
var items_references: Array[ItemEntity] = []

## Elenco di punti disponibili per lo spawn di oggetti.
var item_spawn_points: Array[Vector2i] = []

var spawned: bool = false

func _init(_items: Dictionary[ItemRegistry.ID, int] = {}, _items_references: Array[ItemEntity] = [], _item_spawn_points: Array[Vector2i] = []) -> void:
	items = _items
	items_references = _items_references
	item_spawn_points = _item_spawn_points

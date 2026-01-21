## Questo modulo globale viene utilizzato per gestire un seplice inventario per il giocatore
extends Node

## Queste due componenti sono utilizzate per gestire la quantità di oggetti posseduta dal giocatore
## e gli oggetti veri e propri.
var inventory: Dictionary[ItemRegistry.ID, int] = {}
var item_db: Dictionary[ItemRegistry.ID, Item] = {}

## Segnale emesso quando la quantià dell'oggetto cambia
signal item_quantity_changed(id: ItemRegistry.ID, quantity: int)

func add_item(item: Item, quantity: int = 1) -> void:
	inventory[item.id] = inventory.get(item.id, 0) + quantity
	item_db[item.id] = item
	
	item_quantity_changed.emit(item.id, inventory.get(item.id, 0))

func has_item(id: ItemRegistry.ID) -> bool:
	return inventory.get(id, 0) > 0

func get_quantity(id: ItemRegistry.ID) -> int:
	return inventory.get(id, 0)

func consume_item(id: ItemRegistry.ID, quantity: int = 1) -> void:
	if !has_item(id): return
	
	inventory[id] = inventory.get(id) - quantity
	
	if inventory.get(id) <= 0: inventory.erase(id)
	
	item_quantity_changed.emit(id, inventory.get(id, 0))

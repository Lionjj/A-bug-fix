## Questo modulo globale viene utilizzato per gestire un seplice inventario per il giocatore
extends Node

## Queste due componenti sono utilizzate per gestire la quantità di oggetti posseduta dal giocatore
## e gli oggetti veri e propri.
var inventory: Dictionary[ItemRegistry.ID, int] = {}
var item_db: Dictionary[ItemRegistry.ID, Item] = {}

func add_item(item: Item, quantity: int = 1) -> void:
	inventory[item.id] = inventory.get(item.id, 0) + quantity
	item_db[item.id] = item

func has_item(id: ItemRegistry.ID) -> bool:
	return inventory.get(id, 0) > 0

func get_quantity(id: ItemRegistry.ID) -> bool:
	return inventory.get(id, 0)

func consume_item(id: ItemRegistry.ID, quantity: int = 1) -> void:
	if !has_item(id): return
	
	inventory[id] = inventory.get(id) - quantity
	
	if inventory.get(id) <= 0: inventory.erase(id)

## Catalogo di oggetti.
class_name NodeCatalogue

## Lista di [Item] del catalogo.
var items: Array[Item] = []

func _init(_items: Array[Item]) -> void: 
	items = _items
	if items.is_empty(): return
	items.sort_custom(func(a:Item, b:Item): return a.priority < b.priority)

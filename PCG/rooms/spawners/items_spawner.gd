## Questo modulo si occupa di ricavare il catalogo di oggetti dai nodi logici, eseguire un binding
## tra essi e gli oggetti "fisici" di gioco e le istanzia nelle poszioni valide.
extends Node

class_name ItemsSpawner

## Lista di scene che rappresentano gli oggetti fisici in gioco
@export var item_table: Dictionary[ItemRegistry.ID, PackedScene] = {
	ItemRegistry.ID.HEART : load("res://Scenes/Interactable/Heart.tscn"),
	ItemRegistry.ID.KEY : load("res://Scenes/Interactable/Key.tscn")
}

var items_count: int = 0

## Binding tra oggetti logici e scene che devono essere istanziate.[br]
## Il parametro [param items] rappresenta una lista di oggeti logici.[br]
## Vedi [method get_catalog].
func _compute_items(items: Array[Item]) -> Dictionary[ItemRegistry.ID, int] :
	# Pulisco il numero di itme
	items_count = 0
	var out: Dictionary[ItemRegistry.ID, int] = {}
	
	for item in items:
		## Gli oggetti con priorità [b]MANDATORY[/b] vengono obbligatoriamente
		## aggiunti al dizionario restituito con la quantià di quanti ne bisogna
		## istanziare.
		if item.priority == Item.Priority.MANDATORY: 
			out[item.id] = item.max_quantity
			items_count += item.max_quantity
			continue
		
		## Gli altri oggetti vengono aggiunti al dizionario in base al loro spwan rate
		for max_istance in item.max_quantity: 
			if Rng.randf() <= item.spawn_rate:
				out[item.id] = max_istance
				items_count += max_istance

	return out

## La lista di oggetti [param items] viene istanziata nelle posizioni [param positions]
## interne delle stanza [param room].
func istanziate_in_position(positions: Array[Vector2i], items : Dictionary[ItemRegistry.ID, int], room: RoomTemplateMeta, room_item_state: RoomItemState) -> void:
	var pos : Array[Vector2i] = positions.duplicate()
		
	for i in items.keys():
		var count: int = items[i]
			
		while count > 0:
			var current : PackedScene = item_table.get(i)

			var new_item : ItemEntity = current.instantiate()
			## TODO: Calcolare un ofset verso l'alto in base alla grandezza dell'oggetto [Vector2(0,16)]
			#var cell_center : Vector2 = room.to_local((pos.pop_front() as Vector2) - Vector2(0,16))
			#new_item.position = cell_center
			room.add_child(new_item)
			new_item.global_position = SmartPlacement.cell_to_world_position(room.collision, pos.pop_front(), new_item.spawn_offset)
			
			## Aggiungi l'oggetto alla lista di porte della stanza
			room_item_state.items_references.append(new_item)
			## Se per qualsiasi motivo l'oggetto viene eliminata dalla scena, viene eliminato anche il 
			## suo riferimento alla lista di oggetti.
			new_item.tree_exited.connect(func(): room_item_state.items_references.erase(new_item))
			
			count -= 1
			
			if pos.is_empty(): return

## Sono calcolate le posizioni valide in cui inserire gli [member items_count] all'interno della stanza
## [param room].
func get_spawn_points(room: RoomTemplateMeta) -> Array[Vector2i]:
	## Individuo un insieme di punti validi (Validi = all'interno della stanza e che siano sul pavimento)
	#var smart : SmartPlacement = SmartPlacement.new()
	#var internal_position : Array[Vector2i] = smart.compute_internal_cells(room)
	#if internal_position.is_empty(): return internal_position
	#var internal_position : Array[Vector2i] = room.spawn_points
	#if internal_position.is_empty(): return internal_position
	#
	#var raw_positions : Array[Vector2i] = SmartPlacement.find_positions(room, internal_position)
	#if raw_positions.is_empty(): return raw_positions
	#
	### Uso Voronoi per selezionare delle are macro aree e utilizzo i centroidi delle 
	### macro are per selesionare dei punti esteticamente belli
	#var smart_position : Array[Vector2i] = SmartPlacement.beautify(raw_positions, items_count)
	#
	#return smart_position
	
	var inner_cells: Array[Vector2i] = room.spawn_points
	if inner_cells.is_empty(): return []
	
	var spawnable_air_cells: Array[Vector2i] = SmartPlacement.get_floor_air_cells(room, inner_cells)
	if spawnable_air_cells.is_empty(): return []
	
	return SmartPlacement.beautify(spawnable_air_cells, items_count)
	
	

## Viene individuato il catalogo di oggetti che il nodo logico [param node] contiene.
func get_catalog(node: MissionNode) -> Dictionary[ItemRegistry.ID, int]:
	if node == null: return {}
	## Vedo se il node: MissionNode ha oggetti da piazzare
	var catalog : NodeCatalogue = node.catalog
	if catalog.items.is_empty(): return {}
	
	## Binding tra oggetti logici del node e scene da piazzare
	var items : Dictionary[ItemRegistry.ID, int] = _compute_items(catalog.items)
	return items

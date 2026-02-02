# ============================================================================
# ItemsSpawner
# ============================================================================
## Modulo che si occupa di:[br]
## - Ricavare il catalogo di item dai nodi logici (MissionNode / NodeCatalogue).[br]
## - Eseguire il binding tra item logici ([Item]) e oggetti fisici (scene).[br]
## - Istanziare gli item in posizioni valide all'interno della stanza.[br]
##
## Il piazzamento avviene SEMPRE tramite [member RoomTemplateMeta.placement] ([RoomPlacementManager]),
## così da rispettare:[br]
## - geometria (celle spawnabili)[br]
## - occupazione (celle bloccate)[br]
## - distanza minima globale (buffer)[br]
##
## Coordinate:[br]
## - Tutto in CELLE ([Vector2i]) per scelta/filtri/validazione.[br]
## - Conversione cella → world via [method SmartPlacement.cell_to_world_position].[br]
# ============================================================================

extends Node
class_name ItemsSpawner

# ---------------------------------------------------------------------------
# Tabella item (binding id → scena)
# ---------------------------------------------------------------------------

## Catalogo delle scene fisiche per ogni [ItemRegistry.ID].[br]
## - Chiave: [ItemRegistry.ID].[br]
## - Valore: [PackedScene] dell'oggetto fisico in gioco.[br]
@export var item_table: Dictionary[ItemRegistry.ID, PackedScene] = {
	ItemRegistry.ID.HEART: load("res://Scenes/Interactable/Heart.tscn"),
	ItemRegistry.ID.KEY: load("res://Scenes/Interactable/Key.tscn"),
	ItemRegistry.ID.CHECKPOINT: load("res://Scenes/Interactable/checkpoint.tscn")
}

# ---------------------------------------------------------------------------
# Stato / configurazione
# ---------------------------------------------------------------------------

## Numero totale di item che il catalogo corrente richiede di spawnare.[br]
## Viene aggiornato da [method _compute_items] e usato da [method get_spawn_points].
var items_count: int = 0

## Distanza minima (in pixel) tra un item e QUALSIASI altra cosa piazzata tramite PlacementManager
## (item, deco, nemici, trappole, ecc.).[br]
## Se la metti a 0, gli item possono spawnare appiccicati alle decorazioni.
const MIN_DIST_ITEMS_PX: float = 32.0

# ---------------------------------------------------------------------------
# Catalog building (logico → quantità)
# ---------------------------------------------------------------------------

## Esegue il binding tra la lista di item logici e la quantità da spawnare.[br]
##
## Regole:[br]
## - Se l'item è [code]MANDATORY[/code], viene aggiunto sempre con [code]max_quantity[/code].[br]
## - Altrimenti, ogni “slot” fino a [code]max_quantity[/code] viene aggiunto in base a [code]spawn_rate[/code].[br]
## - Aggiorna [member items_count] con il totale risultante.[br]
##
## [param items] Lista di item logici provenienti dal catalogo del nodo.[br]
## [param rng] Generatore randomico basato sul seed del livello.[br]
##
## @return Dizionario [code]ItemRegistry.ID -> count[/code] con le quantità finali da spawnare.
func _compute_items(items: Array[Item], rng: RandomNumberGenerator) -> Dictionary[ItemRegistry.ID, int]:
	## Reset conteggio totale
	items_count = 0
	var out: Dictionary[ItemRegistry.ID, int] = {}

	for item: Item in items:
		## Gli oggetti MANDATORY vengono sempre aggiunti
		if item.priority == Item.Priority.MANDATORY:
			out[item.id] = item.max_quantity
			items_count += item.max_quantity
			continue

		## Gli altri item vengono aggiunti secondo spawn_rate
		for _i: int in range(item.max_quantity):
			if rng.randf() <= item.spawn_rate:
				out[item.id] = out.get(item.id, 0) + 1
				items_count += 1

	return out

# ---------------------------------------------------------------------------
# Spawn
# ---------------------------------------------------------------------------

## Istanzia gli item nelle celle candidate, rispettando:[br]
## - geometria: la cella (e il footprint) deve essere spawnabile.[br]
## - occupazione: nessuna intersezione con celle bloccate.[br]
## - distanza minima: buffer globale in celle.[br]
##
## Nota importante:[br]
## Le celle candidate arrivano già “belle” (Voronoi/beautify), ma NON sono garantite
## libere: potrebbero essere state bloccate da decorazioni o altri sistemi.
##
## [param candidates] Lista di celle candidate (pool di partenza) in cui provare a spawnare.[br]
## [param items] Dizionario [code]ItemRegistry.ID -> count[/code] con le quantità da spawnare.[br]
## [param room] Stanza target (tilemap collision + placement manager).[br]
## [param room_item_state] Stato runtime dove tracciare le reference alle istanze.[br]
## [param rng] Generatore randomico basato sul seed del livello.[br]
func istanziate_in_position(
	candidates: Array[Vector2i],
	items: Dictionary[ItemRegistry.ID, int],
	room: RoomTemplateMeta,
	room_item_state: RoomItemState,
	rng: RandomNumberGenerator
) -> void:
	if candidates.is_empty():
		return
	if items.is_empty():
		return

	## Pool modificabile: scartiamo candidate “cattive” finché troviamo spawn validi
	var remaining_candidates: Array[Vector2i] = candidates.duplicate()

	## Buffer distanza globale (in celle)
	var gap_cells: int = _min_gap_cells(room)

	for item_id: ItemRegistry.ID in items.keys():
		var remaining_count: int = items[item_id]

		while remaining_count > 0:
			if remaining_candidates.is_empty():
				return

			var scene: PackedScene = item_table.get(item_id)
			if scene == null:
				## Se manca la scena, non posso spawnare questo item
				remaining_count -= 1
				continue

			## 1) Istanzia: serve per leggere footprint/spawn_offset
			var new_item: ItemEntity = scene.instantiate() as ItemEntity
			if new_item == null:
				remaining_count -= 1
				continue

			## 2) Trova una cella valida per QUESTO item (footprint variabile)
			## Nota: footprint_width_cells è inteso come “larghezza footprint in celle”.
			var footprint_cells: int = max(1, new_item.footprint_width_cells)

			var picked_cell: Vector2i = Vector2i.ZERO
			var found: bool = false

			while not remaining_candidates.is_empty():
				var idx: int = rng.randi() % remaining_candidates.size()
				var cell: Vector2i = remaining_candidates[idx]

				## Se non posso piazzare qui (spawnable + non bloccato + gap), scarto la candidata
				if not room.placement.can_place(cell, footprint_cells, gap_cells):
					remaining_candidates.remove_at(idx)
					continue

				picked_cell = cell
				found = true
				break

			if not found:
				## Non ho trovato alcuna cella valida per questo item
				new_item.queue_free()
				return

			## 3) Piazza in world-space
			room.add_child(new_item)
			new_item.global_position = SmartPlacement.cell_to_world_position(
				room.collision,
				picked_cell,
				new_item.spawn_offset
			)

			## 4) Riserva celle nel PlacementManager (footprint + buffer distanza)
			room.placement.reserve(picked_cell, footprint_cells, gap_cells)

			## 5) Track reference
			room_item_state.items_references.append(new_item)
			new_item.tree_exited.connect(func() -> void:
				room_item_state.items_references.erase(new_item)
			)

			remaining_count -= 1

# ---------------------------------------------------------------------------
# Candidate points
# ---------------------------------------------------------------------------

## Calcola le posizioni candidate in cui inserire gli item all'interno della stanza.[br]
## Usa le celle “aria su pavimento” cache-ate dal [RoomPlacementManager] e le “abbellisce”
## tramite [method SmartPlacement.beautify].[br]
##
## [param room] Stanza target da cui leggere [code]room.placement.floor_air_cells[/code].[br]
## [param rng] Generatore randomico basato sul seed del livello.[br]
##
## @return Array di celle candidate per lo spawn degli item.
func get_spawn_points(room: RoomTemplateMeta, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var spawnable_air_cells: Array[Vector2i] = room.placement.floor_air_cells
	if spawnable_air_cells.is_empty():
		return []

	return SmartPlacement.beautify(spawnable_air_cells, rng, items_count)

# ---------------------------------------------------------------------------
# Catalogue extraction
# ---------------------------------------------------------------------------

## Ricava il catalogo item dal nodo logico e lo converte in quantità spawnabili.[br]
##
## [param node] Nodo logico della missione da cui estrarre [member NodeCatalogue.items].[br]
## [param rng] Generatore randomico basato sul seed del livello.[br]
##
## @return Dizionario [code]ItemRegistry.ID -> count[/code] da passare allo spawn.
func get_catalog(node: MissionNode, rng: RandomNumberGenerator) -> Dictionary[ItemRegistry.ID, int]:
	if node == null:
		return {}

	var catalog: NodeCatalogue = node.catalog
	if catalog.items.is_empty():
		return {}

	return _compute_items(catalog.items, rng)

# ---------------------------------------------------------------------------
# Gap conversion
# ---------------------------------------------------------------------------

## Converte la distanza minima degli item da pixel a celle.[br]
##
## [param room] Stanza (serve per tile_size).[br]
##
## @return Gap minimo in CELLE (arrotondato per eccesso).
func _min_gap_cells(room: RoomTemplateMeta) -> int:
	var tile_size_x: int = room.collision.tile_set.tile_size.x
	return RoomPlacementManager.px_to_cells(MIN_DIST_ITEMS_PX, tile_size_x)

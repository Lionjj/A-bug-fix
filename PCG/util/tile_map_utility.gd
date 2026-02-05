# ============================================================================
# TileMapUtility
# ============================================================================
## Utility stateless per operazioni comuni sui [TileMapLayer] del livello.[br]
##
##[br]
## [b]Responsabilità principali[/b]:[br]
## - Raccogliere i [TileMapLayer] sorgenti delle stanze (collision) e dei corridoi.[br]
## - Creare o recuperare un [TileMapLayer] finale unico e fondervi le celle usate.[br]
## - Gestire il merge in coordinate world per evitare problemi di offset/trasformazioni.[br]
## - Fornire helper di allineamento dei [TileMapLayer] all’interno di una stanza.[br]
##[br]
## [b]Cosa NON fa[/b]:[br]
## - Non costruisce stanze o corridoi.[br]
## - Non decide la topologia del livello.[br]
## - Non risolve conflitti avanzati tra TileSet diversi (assume coerenza).[br]
##[br]
## [b]Flusso tipico[/b]:[br]
## 1) Stanze e corridoi vengono istanziati.[br]
## 2) [method merge_tile_map_layer] viene chiamato una sola volta.[br]
## 3) I layer sorgenti vengono nascosti e si lavora solo sul layer finale.[br]
##[br]
## [b]Dipendenze[/b]:[br]
## - [RoomTemplateMeta]: espone il [TileMapLayer] di collisione.[br]
## - [CorridorBuilder]: fornisce il [NodePath] di fallback del layer corridoi.[br]
##[br]
## [b]Note architetturali[/b]:[br]
## - Il merge avviene sempre cella → world → cella finale.[br]
## - Questo rende il sistema robusto a offset, parent diversi e trasformazioni.[br]
# ============================================================================

class_name TileMapUtility


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Fonde i [TileMapLayer] delle stanze e dei corridoi in un unico layer finale.[br]
##[br]
## [param level]: nodo root del livello, usato per trovare gruppi e creare il layer finale.[br]
## [param rooms]: lista opzionale di RoomTemplateMeta; se vuota, le stanze vengono recuperate dal gruppo "rooms".[br]
##[br]
## Ritorna:[br]
## - [TileMapLayer] finale (creato o recuperato). In caso di errore può essere vuoto o parziale.[br]
##[br]
## Effetti collaterali:[br]
## - Il layer finale viene sempre svuotato e ricostruito.[br]
## - Tutti i layer sorgenti utilizzati vengono impostati `visible = false`.[br]
static func merge_tile_map_layer(
	level: Node,
	rooms: Array[RoomTemplateMeta] = []
) -> TileMapLayer:
	# Copia difensiva: evitiamo di modificare l’array del chiamante.
	var rooms_copy: Array[RoomTemplateMeta] = rooms.duplicate()

	# Se non vengono fornite stanze, le recuperiamo automaticamente.
	if rooms.is_empty():
		rooms_copy = get_rooms(level)

	# Recupero o creazione del layer finale.
	var final: TileMapLayer = _get_or_create_final_layer(level)

	# Raccolta dei layer collision delle stanze.
	var sources: Array[TileMapLayer] = _get_all_collison(rooms_copy)
	if sources.is_empty():
		push_error("TileMapUtility: nessun layer di collision trovato nelle stanze.")
		return final

	# Recupero del layer dei corridoi (obbligatorio per una mappa coerente).
	var corridor: TileMapLayer = _get_corriodr(level)
	if corridor == null:
		push_error("TileMapUtility: layer corridoi non trovato nello scene tree.")
		return final

	sources.append(corridor)

	# Il merge ricostruisce sempre da zero.
	final.clear()

	# Assunzione: tutte le sorgenti condividono lo stesso TileSet.
	if final.tile_set == null:
		final.tile_set = sources[0].tile_set

	_merge_tile(sources, final)

	return final


# ---------------------------------------------------------------------------
# Layer discovery / creation
# ---------------------------------------------------------------------------

## Recupera o crea il [TileMapLayer] finale.[br]
##[br]
## [param level]: nodo a cui il layer finale viene cercato o aggiunto.[br]
## [param final_layer_name]: NodePath del layer finale (default "Final").[br]
##[br]
## Ritorna:[br]
## - [TileMapLayer] pronto all’uso.[br]
static func _get_or_create_final_layer(
	level: Node,
	final_layer_name: NodePath = "Final"
) -> TileMapLayer:
	var out: TileMapLayer = level.get_node_or_null(final_layer_name) as TileMapLayer
	if out != null:
		return out

	out = TileMapLayer.new()
	out.name = String(final_layer_name)

	level.add_child(out)
	out.owner = level

	return out


## Estrae i [TileMapLayer] di collisione da una lista di stanze.[br]
##[br]
## [param rooms]: array di RoomTemplateMeta già istanziate.[br]
##[br]
## Ritorna:[br]
## - Array di [TileMapLayer] di collisione.[br]
static func _get_all_collison(rooms: Array[RoomTemplateMeta]) -> Array[TileMapLayer]:
	var out: Array[TileMapLayer] = []
	for room: RoomTemplateMeta in rooms:
		out.append(room.collision)
	return out


## Recupera tutte le stanze presenti nel livello tramite gruppo.[br]
##[br]
## [param level]: nodo livello da cui accedere allo SceneTree.[br]
## [param room_group]: gruppo usato per identificare le stanze (default "rooms").[br]
##[br]
## Ritorna:[br]
## - Array di [RoomTemplateMeta] validi.[br]
static func get_rooms(
	level: Node,
	room_group: StringName = &"rooms"
) -> Array[RoomTemplateMeta]:
	var out: Array[RoomTemplateMeta] = []

	for node: Node in level.get_tree().get_nodes_in_group(room_group):
		var room: RoomTemplateMeta = node as RoomTemplateMeta
		if room == null:
			continue
		out.append(room)

	return out


## Recupera il [TileMapLayer] dei corridoi.[br]
##[br]
## Strategia di lookup:[br]
## 1) Primo nodo trovato nel gruppo `corridor_group`.[br]
## 2) Fallback su CorridorBuilder.TM_CORRIDOR.[br]
##[br]
## [param level]: nodo livello usato per query su SceneTree e get_node_or_null.[br]
## [param corridor_group]: gruppo associato al layer corridoi (default "corridor").[br]
##[br]
## Ritorna:[br]
## - [TileMapLayer] dei corridoi o null se non trovato.[br]
static func _get_corriodr(
	level: Node,
	corridor_group: StringName = &"corridor"
) -> TileMapLayer:
	var out: TileMapLayer = level.get_tree().get_first_node_in_group(corridor_group) as TileMapLayer
	if out != null:
		return out

	out = level.get_node_or_null(CorridorBuilder.TM_CORRIDOR) as TileMapLayer
	if out != null:
		return out

	return null


# ---------------------------------------------------------------------------
# Merge implementation
# ---------------------------------------------------------------------------

## Fonde più [TileMapLayer] sorgenti in un layer finale.[br]
##[br]
## [param sources]: lista di [TileMapLayer] sorgenti (stanze + corridoi).[br]
## [param final]: [TileMapLayer] destinazione già creato.[br]
## [param overwrite_existing]: se false, non sovrascrive celle già presenti nel final.[br]
##[br]
## Effetti collaterali:[br]
## - I layer sorgenti vengono resi invisibili dopo il merge.[br]
static func _merge_tile(
	sources: Array[TileMapLayer],
	final: TileMapLayer,
	overwrite_existing: bool = true
) -> void:
	for layer: TileMapLayer in sources:
		if layer == null or layer.tile_set == null:
			continue

		for src_cell: Vector2i in layer.get_used_cells():
			var src_id: int = layer.get_cell_source_id(src_cell)
			if src_id == -1:
				continue

			var atlas: Vector2i = layer.get_cell_atlas_coords(src_cell)
			var alt: int = layer.get_cell_alternative_tile(src_cell)

			# Conversione stabile: cella sorgente → world → cella finale.
			var src_local: Vector2 = layer.map_to_local(src_cell)
			var world: Vector2 = layer.to_global(src_local)

			var final_local: Vector2 = final.to_local(world)
			var dst_cell: Vector2i = final.local_to_map(final_local)

			if not overwrite_existing and final.get_cell_source_id(dst_cell) != -1:
				continue

			final.set_cell(dst_cell, src_id, atlas, alt)

		layer.visible = false


# ---------------------------------------------------------------------------
# Extra helpers
# ---------------------------------------------------------------------------

## Allinea tutti i [TileMapLayer] discendenti alla posizione della stanza.[br]
##[br]
## Utile quando una stanza viene spostata o istanziata e i layer figli risultano offsettati.[br]
##[br]
## [param room]: nodo root della stanza a cui allineare i [TileMapLayer].[br]
static func align_all_tilemap_layers(room: Node2D) -> void:
	if room == null:
		return

	# DFS iterativa sull’albero della stanza.
	var stack: Array[Node2D] = [room]
	while stack.size() > 0:
		var n: Node2D = stack.pop_back()
		for c in n.get_children():
			if c is Node2D:
				stack.append(c)

		var l: TileMapLayer = n as TileMapLayer
		if l:
			l.position = room.position

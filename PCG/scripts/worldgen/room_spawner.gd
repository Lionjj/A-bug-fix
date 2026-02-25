# ============================================================================
# RoomSpawner
# ============================================================================
## Modulo responsabile dell’istanziazione delle stanze fisiche 
## ([RoomTemplateMeta]) a partire dal risultato della fase di piazzamento su 
## griglia.[br]
##
## [b]Responsabilità principali[/b]:[br]
## - Scorrere i nodi logici posizionati sulla griglia ([member RoomSpawnContext.positions]).[br]
## - Derivare i requisiti dei connettori per ogni stanza (in base a vicini/occupied).[br]
## - Delegare a [RoomAssembler] la scelta del template compatibile.[br]
## - Instanziare [RoomTemplateMeta], posizionarla in world e inserirla nello scene tree.[br]
## - Agganciare il nodo logico ([MissionGraph]) alla stanza fisica.[br]
## - Creare e restituire lo stato runtime per stanza ([RoomState]).[br]
##[br]
## [b]Cosa NON fa[/b]:[br]
## - Non calcola il grafo né il placement: riceve dati già pronti nel context.[br]
## - Non costruisce corridoi: quello è compito di [CorridorBuilder].[br]
## - Non applica regole di selezione template: le delega a [RoomAssembler].[br]
##[br]
## [b]Dipendenze[/b]:[br]
## - [RoomSpawnContext]: input dati (root, graph, positions, occupied, rng, abilities, assembler, cell_tiles).[br]
## - [ConnectorRequirements]: calcolo requisiti connettori per stanza.[br]
## - [RoomAssembler]: selezione template + istanziazione concreta della stanza.[br]
## - [MissionGraph]: per collegare stanza fisica al nodo logico ([member RoomTemplateMeta.logic_node]).[br]
##[br]
## [b]Note architetturali[/b]:[br]
## - Stateless: non conserva stato tra run, produce solo istanze e un dizionario di stati runtime.[br]
## - L’ordine di spawn segue l’ordine delle keys del Dictionary (non garantito): se serve determinismo,[br]
##   ordina `ids` prima di iterare.[br]
# ============================================================================

extends RefCounted
class_name RoomSpawner


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

## Fallback dimensione tile (pixel) per convertire celle griglia → coordinate 
## world.[br]
## Idealmente: la tile size dovrebbe arrivare dal TileSet/TileMap o dal context 
## per evitare divergenze.[br]
const TILE_SIZE: Vector2i = Vector2i(16, 16)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Istanzia tutte le stanze fisiche del livello.[br]
##[br]
## [param "context"]: [RoomSpawnContext] con i dati necessari allo spawn.[br]
##[br]
## Ritorna:[br]
## - [code]Dizionario[RoomTemplateMeta,RoomState][/code] per tutte le stanze 
## effettivamente instanziate.[br]
## - Le stanze fallite (template nullo / instantiate_room fallito) vengono 
## semplicemente saltate.[br]
func spawn_all(context: RoomSpawnContext) -> Dictionary[RoomTemplateMeta, RoomState]:
	var out: Dictionary[RoomTemplateMeta, RoomState] = {}

	# -----------------------------------------------------------------------
	# Guard clauses: senza dati minimi non ha senso tentare lo spawn.
	# -----------------------------------------------------------------------
	if context == null:
		return out
	if context.root == null or context.assembler == null or context.graph == null:
		return out
	if context.positions.is_empty():
		return out

	# Context per RoomAssembler: precompila informazioni utili alla selezione template
	# (es. abilità, grafo, RNG, mapping posizioni).
	var assembler_ctx: RoomAssemblerContext = context.assembler.make_context(
		context.graph,
		context.positions,
		context.rng,
	)

	# Lista ID logici delle stanze da instanziare.
	var ids: Array[String] = context.positions.keys()

	for id: String in ids:
		var grid_cell: Vector2i = context.positions[id]

		# -------------------------------------------------------------------
		# Requisiti connettori: quali lati devono avere un'apertura
		# in base alle adiacenze del placer (occupied/positions).
		# -------------------------------------------------------------------
		var req: Dictionary[String, bool] = ConnectorRequirements.required_for(
			id,
			context.positions,
			context.occupied
		)

		# -------------------------------------------------------------------
		# Selezione template: delegata all’assembler (regole/tag/abilità/difficoltà).
		# -------------------------------------------------------------------
		var tmpl: PackedScene = context.assembler.pick_template_with_requirements(
			assembler_ctx,
			id,
			req
		)

		if tmpl == null:
			push_warning("RoomSpawner: template nullo per id=%s (req=%s)" % [id, str(req)])
			continue

		# -------------------------------------------------------------------
		# Istanziazione fisica: conversione grid_cell → world e setup dimensioni.
		# -------------------------------------------------------------------
		var room: RoomTemplateMeta = context.assembler.instantiate_room(
			tmpl,
			grid_cell,
			TILE_SIZE,
			context.cell_tiles
		)

		if room == null:
			push_warning("RoomSpawner: instantiate_room fallito per id=%s" % id)
			continue

		# -------------------------------------------------------------------
		# Collegamento logico: la stanza fisica punta al suo nodo nel grafo.
		# -------------------------------------------------------------------
		room.logic_node = context.graph.nodes.get(id)

		# -------------------------------------------------------------------
		# Registrazione scena: group + parent.
		# -------------------------------------------------------------------
		room.add_to_group("rooms")
		context.root.add_child(room)

		# Owner: serve solo se ti interessa che il nodo risulti "owned" e quindi
		# serializzabile/salvabile in editor. In runtime puro è spesso irrilevante.
		if context.root.owner != null:
			room.owner = context.root.owner

		# -------------------------------------------------------------------
		# Stato runtime: creato per ogni stanza instanziata con successo.
		# -------------------------------------------------------------------
		out[room] = RoomState.new()

	return out

# ============================================================================
# RoomSpawner
# ============================================================================
## Modulo responsabile dell’istanziazione delle stanze fisiche ([RoomTemplateMeta])
## a partire dal risultato della fase di piazzamento su griglia.[br]
##
## Responsabilità principali:[br]
## - Iterare le posizioni logiche calcolate dal placer.[br]
## - Calcolare i requisiti dei connettori per ogni stanza.[br]
## - Selezionare un template compatibile tramite [RoomAssembler].[br]
## - Istanziare le stanze fisiche e inserirle nel scene tree.[br]
## - Creare e restituire lo stato runtime associato a ciascuna stanza ([RoomState]).[br]
##
## Note architetturali:[br]
## - Il modulo è stateless: espone una singola funzione pubblica.[br]
## - Non dipende da WorldGen: riceve un context con i dati necessari.[br]
# ============================================================================

extends RefCounted
class_name RoomSpawner


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

## Fallback: dimensione tile usata per convertire celle -> world.
## Idealmente passala nel context, così rimane consistente in tutta la pipeline.
const TILE_SIZE: Vector2i = Vector2i(16, 16)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Istanzia tutte le stanze fisiche del livello.[br]
## [br]
## [param context] Contesto dati per spawn stanze.[br]
## [return] Dizionario {[RoomTemplateMeta] -> [RoomState]} per tutte le stanze spawnate.[br]
func spawn_all(context: RoomSpawnContext) -> Dictionary[RoomTemplateMeta, RoomState]:
	var out: Dictionary[RoomTemplateMeta, RoomState] = {}

	# Guard: context invalido
	if context == null:
		return out
	if context.root == null or context.assembler == null or context.graph == null:
		return out
	if context.positions.is_empty():
		return out

	var ids: Array[String] = context.positions.keys()

	for id: String in ids:
		var grid_cell: Vector2i = context.positions[id]

		# Requisiti connettori (O(1) usando occupied)
		var req: Dictionary[String, bool] = ConnectorRequirements.required_for(
			id,
			context.positions,
			context.occupied
		)

		# Selezione template compatibile
		var tmpl: PackedScene = context.assembler.pick_template_with_requirements(
			context,
			id,
			req
		)

		if tmpl == null:
			push_warning("RoomSpawner: template nullo per id=%s (req=%s)" % [id, str(req)])
			continue

		# Istanzia stanza fisica
		var room: RoomTemplateMeta = context.assembler.instantiate_room(
			tmpl,
			grid_cell,
			TILE_SIZE,
			context.cell_tiles
		)

		if room == null:
			push_warning("RoomSpawner: instantiate_room fallito per id=%s" % id)
			continue

		# Collega stanza al nodo logico del grafo
		room.logic_node = context.graph.nodes.get(id)

		# Registrazione scena
		room.add_to_group("rooms")
		context.root.add_child(room)

		# Owner: utile solo se vuoi che il nodo risulti "salvabile" nella scena
		if context.root.owner != null:
			room.owner = context.root.owner

		# Stato runtime stanza
		out[room] = RoomState.new()

	return out

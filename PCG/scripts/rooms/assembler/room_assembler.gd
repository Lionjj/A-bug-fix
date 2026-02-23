# ============================================================================
# RoomAssembler
# ============================================================================
## Orchestrator sottile tra catalogo e picker.[br]
##
## Responsabilità:[br]
## - Inizializzare e mantenere [RoomTemplateCatalog] e [RoomTemplatePicker].[br]
## - Esporre API di alto livello usate dalla pipeline di world generation
##   (tipicamente WorldGen -> RoomSpawner).[br]
## - Costruire un [RoomAssemblerContext] per una singola build, contenente
##   tutte le dipendenze necessarie al picker.[br]
## - Instanziare e posizionare fisicamente le stanze nello slot di griglia.[br]
##[br]
## Cosa NON fa:[br]
## - Non applica regole di filtro/scoring (delegato a [RoomTemplatePicker]).[br]
## - Non valida semanticamente template/nodi (delegato a [RoomTemplateRules]).[br]
## - Non gestisce ban list in modo “automatico” (eventuali policy restano esplicite).[br]
##[br]
## Note architetturali:[br]
## - Questo modulo è intenzionalmente “thin”: coordina e delega.[br]
## - Tiene stato minimo e riusabile (catalogo/picker).[br]
## - Il context è creato per build e passato downstream.[br]
# ============================================================================

extends RefCounted
class_name RoomAssembler



# ---------------------------------------------------------------------------
# Config (no magic numbers)
# ---------------------------------------------------------------------------

## Path di default per il catalogo template.[br]
## Fonte: [RoomTemplateCatalog.DEFAULT_PATH].
const DEFAULT_PATH: String = RoomTemplateCatalog.DEFAULT_PATH

## Default tile size (px) usato per calcolare l’offset in world-space.[br]
## Nota: il tile size reale delle TileMap può essere diverso, ma questo valore
## serve per posizionamento “in griglia” (layout canonico).
const DEFAULT_TILE_SIZE: Vector2i = Vector2i(16, 16)

## Dimensione canonica della cella griglia in tiles (slot logico del WorldGen).[br]
## Ogni stanza viene posizionata dentro una cella di questa dimensione.
const DEFAULT_CELL_TILES: Vector2i = Vector2i(80, 48)

## Convenzioni comuni (utility).
const EMPTY_STRING: String = ""

## Indice fallback (es. accesso “primo elemento” in array non vuoti).
const FALLBACK_INDEX: int = 0


# ---------------------------------------------------------------------------
# Core modules (shared, riusabili)
# ---------------------------------------------------------------------------

## Catalogo dei template stanza (PackedScene + cache metadati).
var _catalog: RoomTemplateCatalog

## Picker pesato che applica rules + scoring.
var _picker: RoomTemplatePicker


# ---------------------------------------------------------------------------
# Context per build corrente (cache / optional)
# ---------------------------------------------------------------------------

## Cache opzionale: può essere usata per evitare ricostruzioni ripetute.[br]
## Nota: in questo snippet non viene ancora sfruttata, ma è utile per future ottimizzazioni.
var _ctx: RoomAssemblerContext = null

var _ctx_graph: MissionGraph = null
var _ctx_rng: RandomNumberGenerator = null
var _ctx_positions: Dictionary = {}
var _ctx_abilities: Array = []


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

## Costruttore del RoomAssembler.[br]
##
## Inizializza:[br]
## - [RoomTemplateCatalog] caricando le scene dalla directory.[br]
## - [RoomTemplatePicker] per la selezione pesata.[br]
##
## [param path] Directory dei template (default: [constant DEFAULT_PATH]).[br]
func _init(path: String = DEFAULT_PATH) -> void:
	_catalog = RoomTemplateCatalog.new(path)
	_picker = RoomTemplatePicker.new()


# ---------------------------------------------------------------------------
# Public API - selection
# ---------------------------------------------------------------------------

## Sceglie un template stanza per un nodo logico, rispettando requisiti connettori.[br]
##
## Comportamento:[br]
## - Setta nel context i requisiti direzionali dei connettori (N/E/S/W).[br]
## - Delega la scelta al picker (che applica rules + scoring).[br]
## - Registra la scelta nel context per debug/telemetry.[br]
##
## Fail-first:[br]
## - Se il context è nullo o mancano dati essenziali -> null.[br]
## - Se il picker non trova alcuna stanza -> null.[br]
##
## [param spawn_ctx] Context della build corrente.[br]
## [param node_id] Id del nodo logico per cui scegliere la stanza.[br]
## [param req] Requisiti connettori richiesti dal grafo (subset di N/E/S/W).[br]
##[br]
## @return PackedScene scelto o null.
func pick_template_with_requirements(
	spawn_ctx: RoomAssemblerContext,
	node_id: String,
	req: Dictionary[String, bool]   # {"N":bool,"E":bool,"S":bool,"W":bool}
) -> PackedScene:
	if spawn_ctx == null or spawn_ctx.graph == null:
		return null
	if not spawn_ctx.positions.has(node_id):
		return null

	## Requisito connettori per questo nodo (il picker userà RoomTemplateRules.satisfies_req).
	spawn_ctx.connector_req = req

	## Scelta delegata al picker.
	var chosen: PackedScene = spawn_ctx.picker.pick(spawn_ctx, node_id)
	if chosen == null:
		return null

	## Info (facoltativo ma utile).
	var info: RoomTemplateInfo = _catalog.info_of_scene(chosen)
	if info != null:
		spawn_ctx.register_choice(node_id, chosen, info)

	## Policy opzionale: START one-shot.[br]
	## Nota: lasciata commentata perché richiede una decisione esplicita di design
	## (bannare per kind/tag_mask o leggere il nodo logico).
	#var node: MissionNode = spawn_ctx.graph.nodes.get(node_id, null)
	#if node != null and "kind" in node and String(node.kind) == "START":
	#	var key: String = _catalog.key_of_scene(chosen)
	#	if key != EMPTY_STRING:
	#		_catalog.ban_key(key)

	return chosen


# ---------------------------------------------------------------------------
# Public API - instantiation/placement
# ---------------------------------------------------------------------------

## Instanzia fisicamente una stanza e la posiziona nella griglia.[br]
##
## Semantica:[br]
## - [param grid_pos] è la posizione della cella logica nel layout del WorldGen.[br]
## - La stanza viene inserita dentro una cella canonica [param grid_cell_tiles].[br]
## - Se la stanza è più piccola della cella canonica, viene “allineata” tramite offset.[br]
## - L’allineamento tilemap viene normalizzato con [TileMapUtility.align_all_tilemap_layers].[br]
##
## Fail-first:[br]
## - packed nullo -> null.[br]
## - instantiate fallisce -> null.[br]
##
## [param packed] PackedScene del template stanza.[br]
## [param grid_pos] Coordinate della cella in griglia (Vector2i).[br]
## [param tile_size] Dimensione tile per conversione tiles->pixel (default: DEFAULT_TILE_SIZE).[br]
## [param grid_cell_tiles] Dimensione cella canonica in tiles (default: DEFAULT_CELL_TILES).[br]
##
## @return Istanza di [RoomTemplateMeta] posizionata o null.
func instantiate_room(
	packed: PackedScene,
	grid_pos: Vector2i,
	tile_size: Vector2i = DEFAULT_TILE_SIZE,
	grid_cell_tiles: Vector2i = DEFAULT_CELL_TILES
) -> RoomTemplateMeta:
	if packed == null:
		return null


	var room := packed.instantiate() as RoomTemplateMeta
	if room == null:
		return null

	# Dimensione cella canonica in pixel
	var cell_px := Vector2(
		float(grid_cell_tiles.x * tile_size.x),
		float(grid_cell_tiles.y * tile_size.y)
	)

	room.position = Vector2(
		float(grid_pos.x) * cell_px.x,
		float(grid_pos.y) * cell_px.y
	)

	return room


# ---------------------------------------------------------------------------
# Public API - utility
# ---------------------------------------------------------------------------

## Calcola la dimensione massima (in tiles) tra tutti i template nel catalogo.[br]
##
## Uso tipico:[br]
## - Derivare la dimensione della cella canonica di griglia in WorldGen.[br]
##
## Nota performance:[br]
## - Usa SOLO [RoomTemplateInfo] (cache), quindi evita instantiate delle scene.[br]
##
## [param padding] Padding extra da aggiungere al massimo (in tiles).[br]
## @return Vector2i(max_w, max_h) + padding.
func max_room_size_tiles(padding: Vector2i) -> Vector2i:
	var w: int = 0
	var h: int = 0

	for key: String in _catalog.keys():
		var info: RoomTemplateInfo = _catalog.info_of_key(key)
		if info == null:
			continue
		w = max(w, int(info.size_tiles.x))
		h = max(h, int(info.size_tiles.y))

	return Vector2i(w, h) + padding


# ---------------------------------------------------------------------------
# Context caching
# ---------------------------------------------------------------------------

## True se i parametri di build sono gli stessi dell'ultimo contesto creato.
## Nota: qui ci basiamo su IDENTITÀ (reference) perché hai detto che:
## - positions e abilities non vengono mutate in-place durante lo spawn
## - rng è sempre lo stesso oggetto per la build
func _can_reuse_context(
	graph: MissionGraph,
	positions: Dictionary[String, Vector2i],
	rng: RandomNumberGenerator,
	abilities: Array[Abilities.Ability]
) -> bool:
	if _ctx == null:
		return false

	return _ctx_graph == graph \
		and _ctx_positions == positions \
		and _ctx_rng == rng \
		and _ctx_abilities == abilities


## Resetta solo lo stato "runtime" del contesto (quello che cambia durante la build).
## NON tocca catalog/picker né i riferimenti a graph/positions/rng/abilities.
func _reset_context_runtime(ctx: RoomAssemblerContext) -> void:
	# requisiti connettori vengono settati per ogni pick
	ctx.connector_req.clear()

	# bookkeeping della build (debug/telemetry)
	ctx.placed_scenes.clear()
	ctx.placed_infos.clear()


## Costruisce o riusa il RoomAssemblerContext per la build corrente.
##
## Obiettivo:
## - Evitare nuove allocazioni se rigeneri più volte o fai più pass
## - Garantire che il contesto non contenga stato sporco da build precedenti
##
## Nota:
## - Usiamo caching per reference perché positions/abilities sono immutabili per build.
func make_context(
	graph: MissionGraph,
	positions: Dictionary[String, Vector2i],
	rng: RandomNumberGenerator,
	abilities: Array[Abilities.Ability]
) -> RoomAssemblerContext:
	# Fail-first
	if graph == null or rng == null:
		return null
	if positions.is_empty():
		return null

	# Riusa il context se i riferimenti sono gli stessi
	if _can_reuse_context(graph, positions, rng, abilities):
		_reset_context_runtime(_ctx)
		return _ctx

	# Altrimenti crea un nuovo context
	_ctx = RoomAssemblerContext.new(
		_catalog,
		_picker,
		graph,
		rng,
		abilities,
		positions
	)

	# Cache dei riferimenti per decidere se riusare in futuro
	_ctx_graph = graph
	_ctx_positions = positions
	_ctx_rng = rng
	_ctx_abilities = abilities

	# Stato runtime pulito (per coerenza)
	_reset_context_runtime(_ctx)

	return _ctx

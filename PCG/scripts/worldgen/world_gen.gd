# ============================================================================
# WorldGen
# ============================================================================
## Orchestrator della generazione del livello: compone i moduli della pipeline e[br]
## coordina i passaggi in ordine deterministico.[br]
##
##[br]
## [b]Responsabilità principali[/b]:[br]
## - Avviare la generazione all’ingresso nello scene tree.[br]
## - Costruire (o ricostruire) una run completa: grafo -> placement -> stanze -> corridoi -> merge -> spawn.[br]
## - Gestire il retry totale se il grafo prodotto non è solvibile.[br]
## - Esporre la [TileMapLayer] finale (`final`) e notificare quando è pronta.[br]
## - Inizializzare il runtime manager ([RoomsManager]) con i dati della run.[br]
##[br]
## [b]Cosa NON fa[/b]:[br]
## - Non decide come generare il grafo: delega a [GraphPipeline].[br]
## - Non implementa placement, selezione template, corridoi o merge tile: delega ai rispettivi moduli.[br]
## - Non gestisce la logica runtime delle stanze: delega a [RoomsManager].[br]
##[br]
## [b]Flusso (alto livello)[/b]:[br]
## 1) [mthod GraphPipeline.run] → seed/rng/graph + solvable[br]
## 2) [method GridPlacerBFS.place] → posizioni su griglia[br]
## 3) [method RoomSpawner.spawn_all] → istanzia stanze fisiche[br]
## 4) [method CorridorBuilder.connect_adjacent] → costruisce corridoi[br]
## 5) [method WorldFinalize.merge_and_spawn] → merge tilemap + spawn player[br]
## 6) [RoomsManager] → setup runtime[br]
##[br]
## [b]Dipendenze[/b]:[br]
## - [GraphPipeline]: produce grafo e RNG effettivi.[br]
## - [GridPlacerBFS]: traduce il grafo in coordinate su griglia.[br]
## - [RoomAssembler]/[RoomSpawner]: selezione template e instanziazione stanze.[br]
## - [CorridorBuilder]: collegamenti fisici tra stanze.[br]
## - [WorldFinalize]: merge tilemap e spawn player.[br]
## - [RoomsManager]: gestione runtime della run.[br]
##[br]
## [b]Note architetturali[/b]:[br]
## - Modulo volutamente “sottile”: qui si compone, altrove si calcola.[br]
## - I moduli ricevono Context per evitare coupling e favorire test/debug.[br]
## - In caso di grafo non solvibile: reload della scena e ripartenza completa.[br]
# ============================================================================

extends Node2D
class_name WorldGen


# ---------------------------------------------------------------------------
# Export / Config
# ---------------------------------------------------------------------------

## Budget massimo di nodi logici che la pipeline proverà a inserire nel grafo.[br]
## Aumentarlo tende a far crescere: dimensione missione, complessità e costo di generazione.[br]
@export var budget_nodes: int

## Seed “richiesto” (Inspector/callsite).[br]
## Dopo GraphPipeline viene allineato al seed effettivo usato, così la run è riproducibile.[br]
@export var seed: int

## Scena del player da instanziare durante il finalize.[br]
## La creazione effettiva e l’aggancio a GameManager avvengono in WorldFinalize.[br]
@export var player_scene: PackedScene

## Indice di run passato al runtime manager.[br]
## Tipicamente usato per scaling (difficoltà/loot/variazioni) o telemetria.[br]
@export var run_level: int = 1


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Padding (in tiles) tra bounding box di stanze adiacenti.[br]
## Serve a:[br]
## - evitare compenetrazioni tra geometrie di stanze diverse[br]
## - lasciare spazio utile per corridoi/aperture senza “mangiare” i bordi stanza[br]
const PADDING: Vector2i = Vector2i(4, 4)


# ---------------------------------------------------------------------------
# Scene refs
# ---------------------------------------------------------------------------

## Contenitore scene/nodi dedicati ad autotiling o utilities grafiche.[br]
## Viene passato al finalize perché possa aggiornare tile/caches dopo il merge.[br]
@onready var auto_tiles: Node = $AutoTiles

## [TileMapLayer] finale risultante dal merge.[br]
## - NULL finché [WorldFinalize] non ha completato il lavoro.[br]
## - Usata da sistemi che devono leggere la mappa finale (minimap, debug, path, ecc.).[br]
var final: TileMapLayer = null


# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------

## Abilità possedute dal player in questa run.[br]
## Input usato per gating e filtro dei template (es. stanze “ability/upgrade”).[br]
## Nota: qui è hard-coded per debug; in produzione può arrivare da progress/save.[br]
var abilities: Array[Abilities.Ability] = [
	Abilities.Ability.GRAPPLE,
	Abilities.Ability.DASH,
]

## RNG effettivo della run.[br]
## Viene prodotto da [GraphPipeline]: usarne un altro qui romperebbe 
## la determinismo della pipeline.[br]
var rng: RandomNumberGenerator = null

## Grafo logico della missione (fonte di verità topologica).[br]
## Viene consumato da: placement, corridoi e manager runtime.[br]
var graph: MissionGraph = null


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emesso quando `final` è pronto e valido.[br]
## Serve a sincronizzare chi deve lavorare sulla tilemap finale senza polling.[br]
signal final_layer_ready


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

## Entry point del modulo.[br]
func _ready() -> void:
	build()


# ---------------------------------------------------------------------------
# Build pipeline
# ---------------------------------------------------------------------------

## Esegue una run completa di generazione.[br]
##[br]
## Effetti collaterali rilevanti:[br]
## - Può ricaricare la scena se [GraphPipeline] segnala: [codeblock] solvable == false [/codeblock][br]
## - Aggiorna [member seed], [member rng], [member graph] con i valori effettivi della run.[br]
## - Assegna [member final] e emette [member final_layer_ready] quando il merge è completato.[br]
## - Instanzia [RoomsManager] come child per gestire la fase runtime.[br]
##[br]
func build() -> void:
	# --- 1) Graph pipeline (fail-fast) ---
	# Se la missione non è solvibile, interrompiamo subito: tutto il resto dipende da questo.
	var pipeline: GraphPipeline.Result = GraphPipeline.run(seed, budget_nodes)
	if not pipeline.solvable:
		get_tree().reload_current_scene()
		return

	# Da qui in poi usiamo SOLO i valori effettivi della run (per riproducibilità e debug).
	seed = pipeline.seed
	rng = pipeline.rng
	graph = pipeline.graph
	
	# --- 2) Grid placement ---
	# positions: node_id -> cella griglia
	# occupied : cella -> node_id (lookup inverso)
	var placer_result: GridPlacerBFS.Result = GridPlacerBFS.place(graph, rng)
	var positions: Dictionary[String, Vector2i] = placer_result.positions
	var occupied: Dictionary[Vector2i, String] = placer_result.occupied

	# --- 3) Room assembling ---
	# cell_tiles = “quanto grande è una cella logica” in tiles reali, inclusi i margini (PADDING).
	var assembler: RoomAssembler = RoomAssembler.new()
	var cell_tiles: Vector2i = assembler.max_room_size_tiles(PADDING)

	# --- 4) Spawn rooms ---
	# Istanzia fisicamente le stanze e produce la mappa di RoomState per il runtime manager.
	var spawner: RoomSpawner = RoomSpawner.new()
	var spawn_ctx: RoomSpawnContext = RoomSpawnContext.new(
		self,       # root: serve per add_child e riferimenti globali
		positions,  # dove piazzare ogni stanza logica
		occupied,   # occupazione griglia (collisione logica / lookup)
		rng,        # RNG condiviso
		abilities,  # gating e filtro template
		graph,      # topologia missione
		assembler,  # selezione template / utilità dimensioni
		cell_tiles  # scala griglia->tiles
	)
	var rooms: Dictionary[RoomTemplateMeta, RoomState] = spawner.spawn_all(spawn_ctx)

	# --- 5) Spawn point ---
	# Preso dalla start room instanziata (marker). Se manca, fallback a ZERO e log errore.
	var spawn_point: Vector2 = _get_spawn_point_from_start_room()

	# --- 6) Corridors ---
	# Collega le stanze secondo la topologia del grafo e la loro posizione su griglia.
	var corridor_ctx: CorridorBuildContext = CorridorBuildContext.new(self, graph, positions, cell_tiles)
	CorridorBuilder.connect_adjacent(corridor_ctx)

	# --- 7) Finalize (merge + player spawn) ---
	# Produciamo la tilemap finale e instanziamo il player nel punto di spawn.
	var fin_ctx := WorldFinalizeContext.new(self, seed, auto_tiles, player_scene, spawn_point)
	final = WorldFinalize.merge_and_spawn(fin_ctx)
	final_layer_ready.emit()

	# --- 8) Runtime manager ---
	# Avvio della fase runtime: gestione stati stanze, gating e integrazione col player.
	var rooms_ctx: RoomsManagerContext = RoomsManagerContext.new(
		graph,
		rooms,
		positions,
		GameManager.player,
		rng,
		run_level
	)
	add_child(RoomsManager.new(rooms_ctx))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Recupera lo spawn point dalla start room instanziata.[br]
##[br]
## Assunzioni:[br]
## - Le stanze instanziate entrano nel gruppo "rooms".[br]
## - La start room è recuperabile come “prima stanza” del gruppo (get_first_node_in_group).[br]
## - [RoomTemplateMeta] espone un marker di spawn tramite [method RoomTemplateMeta.get_spawn_point].[br]
##[br]
## Ritorna:[br]
## - Posizione globale del marker di spawn.[br]
## - [constant Vector2.ZERO] se non viene trovata una stanza valida.[br]
func _get_spawn_point_from_start_room() -> Vector2:
	var start_room := get_tree().get_first_node_in_group("rooms") as RoomTemplateMeta
	if start_room == null:
		push_error("Start room not found")
		return Vector2.ZERO

	return start_room.get_spawn_point().global_position

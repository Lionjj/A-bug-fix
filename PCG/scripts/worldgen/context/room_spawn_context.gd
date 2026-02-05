# ============================================================================
# RoomSpawnContext
# ============================================================================
## Contesto dati per la fase di spawn delle stanze fisiche.[br]
##
## [b]Responsabilità principali[/b]:[br]
## - Fornire a [RoomSpawner] tutti i riferimenti necessari per istanziare le stanze.[br]
## - Tenere la fase di spawn isolata dall’orchestratore ([WorldGen]).[br]
## - Trasportare in modo esplicito i dati “coerenti di run” (posizioni, rng, abilità, grafo).[br]
##[br]
## [b]Cosa NON fa[/b]:[br]
## - Non calcola placement, adiacenze o requisiti connettori: fornisce solo i dati.[br]
## - Non seleziona template: quella logica è del [RoomAssembler] e viene invocata da [RoomSpawner].[br]
## - Non istanzia nodi: è solo un contenitore di input.[br]
##[br]
## [b]Contenuto[/b]:[br]
## - [member root]: nodo root su cui aggiungere le stanze.[br]
## - [member positions]: mapping id logico → cella su griglia.[br]
## - [member occupied]: mapping inverso cella → id logico (lookup O(1) per adiacenze).[br]
## - [member rng]: RNG della run (deve essere quello della pipeline).[br]
## - [member abilities]: abilità possedute dal player (gating/filtro template).[br]
## - [member graph]: grafo logico della missione.[br]
## - [member assembler]: selezione template e instanziazione concreta.[br]
## - [member cell_tiles]: dimensione cella stanza in tile (grid spacing).[br]
##[br]
## [b]Note architetturali[/b]:[br]
## - Da trattare come immutabile dopo la costruzione: chi lo consuma deve leggerlo, non modificarlo.[br]
## - Va creato dopo la fase di placement su griglia (servono positions/occupied).[br]
## - [RoomSpawner] non deve leggere direttamente [WorldGen]: questo è il contratto tra i moduli.[br]
# ============================================================================

extends RefCounted
class_name RoomSpawnContext


# ---------------------------------------------------------------------------
# Core references
# ---------------------------------------------------------------------------

## Nodo root del livello.[br]
## Usato da [RoomSpawner] solo per add_child e (opzionalmente) ownership.[br]
var root: Node

## Mapping id nodo logico → posizione su griglia.[br]
var positions: Dictionary[String, Vector2i]

## Mapping inverso posizione su griglia → id nodo logico.[br]
## Serve a lookup rapidi per adiacenze senza scorrere tutte le posizioni.[br]
var occupied: Dictionary[Vector2i, String]

## RNG della run.[br]
## Deve essere quello derivato da [GraphPipeline] per mantenere determinismo/coerenza.[br]
var rng: RandomNumberGenerator

## Abilità possedute dal player.[br]
## Input usato per gating e filtro dei template durante la selezione.[br]
var abilities: Array[Abilities.Ability]

## Grafo logico della missione.[br]
## Serve per collegare la stanza fisica al nodo logico (es. room.logic_node).[br]
var graph: MissionGraph

## Assembler responsabile della selezione template e dell’istanza stanza.[br]
var assembler: RoomAssembler

## Dimensione della cella stanza in tile (grid spacing).[br]
## Serve a convertire coordinate logiche (Vector2i) in world space in modo consistente.[br]
var cell_tiles: Vector2i


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

## Costruisce il contesto per la fase di spawn.[br]
##[br]
## [param _root]: nodo root del livello.[br]
## [param _positions]: posizioni logiche su griglia (id → cella).[br]
## [param _occupied]: lookup inverso (cella → id).[br]
## [param _rng]: RNG della run.[br]
## [param _abilities]: abilità possedute dal player.[br]
## [param _graph]: grafo logico della missione.[br]
## [param _assembler]: [RoomAssembler] da usare per selezione e instanziazione template.[br]
## [param _cell_tiles]: dimensione cella stanza in tile.[br]
func _init(
	_root: Node,
	_positions: Dictionary[String, Vector2i],
	_occupied: Dictionary[Vector2i, String],
	_rng: RandomNumberGenerator,
	_abilities: Array[Abilities.Ability],
	_graph: MissionGraph,
	_assembler: RoomAssembler,
	_cell_tiles: Vector2i,
) -> void:
	root = _root
	positions = _positions
	occupied = _occupied
	rng = _rng
	abilities = _abilities
	graph = _graph
	assembler = _assembler
	cell_tiles = _cell_tiles

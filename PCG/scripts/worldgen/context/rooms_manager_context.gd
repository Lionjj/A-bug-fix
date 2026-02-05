# ============================================================================
# RoomsManagerContext
# ============================================================================
## Context runtime passato a [RoomsManager].[br]
##
## [b]Responsabilità principali[/b]:[br]
## - Fornire a [RoomsManager] tutti i riferimenti necessari per la gestione runtime.[br]
## - Disaccoppiare il manager dall’orchestratore ([WorldGen]) e dalla pipeline di build.[br]
## - Trasportare i dati di run (graph/rooms/player/rng/run_level) in modo esplicito.[br]
##[br]
## [b]Cosa NON fa[/b]:[br]
## - Non gestisce logica runtime: contiene solo dati.[br]
## - Non crea stanze o stati: riceve oggetti già costruiti dalla fase di build.[br]
## - Non valida coerenza tra mappe (graph/rooms/positions): quella è responsabilità del chiamante.[br]
##[br]
## [b]Contenuto[/b]:[br]
## - [member graph]: grafo logico della missione.[br]
## - [member rooms]: mapping stanza fisica → stato runtime.[br]
## - [member positions]: mapping id logico → posizione su griglia.[br]
## - [member player]: riferimento al player runtime.[br]
## - [member rng]: RNG della run (coerente con il seed di generazione).[br]
## - [member run_level]: livello run/difficoltà corrente.[br]
##[br]
## [b]Note architetturali[/b]:[br]
## - Da trattare come immutabile dopo la costruzione.[br]
## - Va creato una sola volta al termine della build del livello.[br]
## - [RoomsManager] non deve conoscere [WorldGen]: questo context è il confine tra build e runtime.[br]
# ============================================================================

extends RefCounted
class_name RoomsManagerContext


# ---------------------------------------------------------------------------
# Runtime references
# ---------------------------------------------------------------------------

## Grafo logico della missione.[br]
## Usato da [RoomsManager] per connessioni logiche e progressione (visitato, completato, gating, ecc.).[br]
var graph: MissionGraph

## Mapping stanza fisica → stato runtime.[br]
## Ogni [RoomState] contiene informazioni dinamiche (clear, nemici vivi, trigger, ecc.).[br]
var rooms: Dictionary[RoomTemplateMeta, RoomState]

## Mapping id nodo logico → posizione su griglia.[br]
## Serve per correlare eventi logici con stanze fisiche e per supportare debug/minimap.[br]
var positions: Dictionary[String, Vector2i]

## Player runtime attualmente attivo nel livello.[br]
var player: Player

## RNG della run.[br]
## Deve essere lo stesso usato in build per mantenere coerenza e determinismo dove richiesto.[br]
var rng: RandomNumberGenerator

## Livello di run / difficoltà corrente.[br]
## Input usato per scaling (spawn/AI/ricompense) a discrezione di [RoomsManager].[br]
var run_level: int


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

## Costruisce il context runtime per [RoomsManager].[br]
##[br]
## [param _graph]: grafo logico della missione.[br]
## [param _rooms]: mapping stanze fisiche → [RoomState].[br]
## [param _positions]: posizioni logiche su griglia (id → cella).[br]
## [param _player]: player runtime.[br]
## [param _rng]: RNG della run.[br]
## [param _run_level]: livello run/difficoltà corrente.[br]
func _init(
	_graph: MissionGraph,
	_rooms: Dictionary[RoomTemplateMeta, RoomState],
	_positions: Dictionary[String, Vector2i],
	_player: Player,
	_rng: RandomNumberGenerator,
	_run_level: int,
) -> void:
	graph = _graph
	rooms = _rooms
	positions = _positions
	player = _player
	rng = _rng
	run_level = _run_level

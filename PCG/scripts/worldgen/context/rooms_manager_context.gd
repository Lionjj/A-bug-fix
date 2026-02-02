# ============================================================================
# RoomsManagerContext
# ============================================================================
## Context runtime passato a [RoomsManager].[br]
##
## Responsabilità:[br]
## - Fornire al RoomsManager tutti i riferimenti necessari per gestire
##   il comportamento runtime delle stanze.[br]
## - Disaccoppiare il manager dal nodo WorldGen e dalla pipeline di build.[br]
##
## Contenuto:[br]
## - Grafo logico della missione (per stato e progressione).[br]
## - Mapping stanze fisiche -> stato runtime.[br]
## - Posizioni logiche delle stanze su griglia.[br]
## - Riferimento al player runtime.[br]
## - RNG del livello (coerente con il seed di generazione).[br]
## - Run level corrente (difficoltà / progressione).[br]
##
## Note architetturali:[br]
## - Oggetto immutabile dopo l’inizializzazione.[br]
## - Deve essere creato una sola volta al termine della build del livello.[br]
## - RoomsManager non deve mai leggere direttamente WorldGen.[br]
# ============================================================================

extends RefCounted
class_name RoomsManagerContext


# ---------------------------------------------------------------------------
# Runtime references
# ---------------------------------------------------------------------------

## Grafo logico della missione (MissionGraph).
## Usato per:
## - determinare connessioni logiche
## - stato dei nodi (visitato, completato, ecc.)
var graph: MissionGraph

## Mapping stanza fisica -> stato runtime.
## Ogni RoomState contiene informazioni dinamiche (nemici vivi, clear, trigger, ecc.)
var rooms: Dictionary[RoomTemplateMeta, RoomState]

## Mapping id nodo logico -> posizione su griglia.
## Utile per:
## - correlare eventi logici con stanze fisiche
## - debug / minimap / navigazione
var positions: Dictionary[String, Vector2i]

## Player runtime attualmente attivo nel livello.
var player: Player

## RNG del livello.
## Deve essere lo stesso usato nella generazione per garantire coerenza.
var rng: RandomNumberGenerator

## Livello di run / difficoltà corrente.
## Può influenzare spawn, scaling, comportamento nemici.
var run_level: int


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

## Costruisce il context runtime per il RoomsManager.[br]
## [br]
## [param _graph] Grafo logico della missione.[br]
## [param _rooms] Mapping stanze -> RoomState.[br]
## [param _positions] Posizioni logiche su griglia.[br]
## [param _player] Player runtime.[br]
## [param _rng] RNG del livello.[br]
## [param _run_level] Livello di run / difficoltà.[br]
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

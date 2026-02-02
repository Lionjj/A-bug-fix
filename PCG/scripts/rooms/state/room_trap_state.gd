# ============================================================================
# RoomTrapState
# ============================================================================
## Modulo che gestisce lo **stato runtime delle trappole** presenti in una stanza.[br]
##
## Responsabilità:[br]
## - Memorizzare i punti di spawn validi.[br]
## - Tracciare quali trappole devono essere istanziate.[br]
## - Conservare i riferimenti alle istanze create.[br]
## - Segnalare se le trappole sono già state spawnate/preparate.[br]
##
## Note architetturali:[br]
## - Non decide *quali* trappole spawnare (compito di [TrapsSpawner]).[br]
## - Non gestisce la logica delle trappole (attivazione/danno).[br]
## - È puramente uno **state container**.[br]
## - È contenuto all’interno di [RoomState].[br]
# ============================================================================

extends Node
class_name RoomTrapState


# ---------------------------------------------------------------------------
# Spawn data
# ---------------------------------------------------------------------------

## Lista di celle ([Vector2i]) utilizzate come punti di spawn per le trappole.[br]
##
## I punti sono calcolati dallo spawner tenendo conto di:[br]
## - geometria della stanza[br]
## - protezione da soft-lock[br]
## - distanza dall’entry point
var spawn_points: Array[Vector2i] = []


# ---------------------------------------------------------------------------
# Trap planning
# ---------------------------------------------------------------------------

## Lista degli ID delle trappole che devono essere istanziate nella stanza.[br]
##
## L’ordine è deterministico e dipende da:[br]
## - budget[br]
## - difficoltà[br]
## - pesi di spawn
var traps: Array[TrapRegistry.ID] = []


# ---------------------------------------------------------------------------
# Runtime references
# ---------------------------------------------------------------------------

## Lista di riferimenti alle istanze di trappole presenti nella stanza.[br]
##
## Serve per:[br]
## - gestione runtime[br]
## - reset della stanza[br]
## - cleanup automatico
var traps_references: Array[TrapEntity] = []


# ---------------------------------------------------------------------------
# State flags
# ---------------------------------------------------------------------------

## Indica se le trappole sono già state spawnate/preparate per questa stanza.[br]
##
## Evita duplicazioni di spawn in caso di rientro del giocatore
## o di riattivazioni multiple della stanza.
var spawned: bool = false


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

## Costruttore dello stato delle trappole della stanza.[br]
##
## Permette di inizializzare lo stato con dati già calcolati
## o di usare valori di default.[br]
##
## [param _spawn_points] Celle utilizzate per lo spawn delle trappole.[br]
## [param _traps] Lista degli ID delle trappole da istanziare.[br]
## [param _traps_references] Riferimenti alle istanze create.[br]
## [param _spawned] Flag che indica se le trappole sono già state spawnate.[br]
func _init(
	_spawn_points: Array[Vector2i] = [],
	_traps: Array[TrapRegistry.ID] = [],
	_traps_references: Array[TrapEntity] = [],
	_spawned: bool = false
) -> void:
	spawn_points = _spawn_points
	traps = _traps
	traps_references = _traps_references
	spawned = _spawned

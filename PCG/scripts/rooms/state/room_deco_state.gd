# ============================================================================
# RoomDecoState
# ============================================================================
## Modulo che gestisce lo **stato runtime delle decorazioni** presenti in una stanza.[br]
##
## Questo nodo funge da **contenitore di stato passivo** per tutto ciò che
## riguarda le decorazioni istanziate in una stanza.[br]
##
## Responsabilità:[br]
## - Conservare i punti di spawn disponibili per le decorazioni.[br]
## - Tracciare quali decorazioni devono essere istanziate.[br]
## - Mantenere i riferimenti alle istanze create.[br]
##
## Note architetturali:[br]
## - Non decide *quali* decorazioni spawnare (compito di [DecoSpawner]).[br]
## - Non gestisce logica o comportamento delle decorazioni.[br]
## - È un **contenitore di stato** puro.[br]
## - È contenuto all’interno di [RoomState].[br]
##
## Differenze rispetto ad altri state (nemici / trappole):[br]
## - le decorazioni NON hanno ondate[br]
## - NON hanno reset di combattimento[br]
## - vengono spawnate una sola volta per stanza
# ============================================================================

extends RefCounted
class_name RoomDecoState


# ---------------------------------------------------------------------------
# Spawn data
# ---------------------------------------------------------------------------

## Lista di celle ([Vector2i]) utilizzabili come punti di spawn per le decorazioni.[br]
##
## I punti sono calcolati dal [DecoSpawner] in base a:[br]
## - geometria della stanza[br]
## - tipo di decorazione (GROUND / WALL / CEILING)[br]
## - distribuzione estetica (Voronoi / beautify)
var spawn_points: Array[Vector2i] = []


# ---------------------------------------------------------------------------
# Decoration planning
# ---------------------------------------------------------------------------

## Coda degli ID delle decorazioni da istanziare nella stanza.[br]
##
## L’ordine è deterministico ed è deciso dal [DecoSpawner]
## in base a budget, pesi e limiti per stanza.
var queue: Array[DecorationsRegistry.ID] = []


# ---------------------------------------------------------------------------
# Runtime references
# ---------------------------------------------------------------------------

## Lista di riferimenti alle istanze di decorazioni presenti nella stanza.[br]
##
## Serve per:[br]
## - gestione runtime[br]
## - cleanup automatico[br]
## - future ottimizzazioni (es. spegnere luci fuori stanza)
var deco_references: Array[DecorationEntity] = []


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

## Costruisce lo stato runtime delle decorazioni della stanza.[br]
##
## Permette di inizializzare lo stato con dati già calcolati
## oppure con valori di default.[br]
##
## [param _spawn_points] Celle utilizzate per lo spawn delle decorazioni.[br]
## [param _queue] Lista ordinata di ID di decorazioni da istanziare.[br]
## [param _deco_references] Riferimenti alle istanze create.[br]
func _init(
	_spawn_points: Array[Vector2i] = [],
	_queue: Array[DecorationsRegistry.ID] = [],
	_deco_references: Array[DecorationEntity] = []
) -> void:
	spawn_points = _spawn_points
	queue = _queue
	deco_references = _deco_references

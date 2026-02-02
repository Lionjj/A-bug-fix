# ============================================================================
# RoomEnemyState
# ============================================================================
## Modulo che gestisce lo **stato runtime dei nemici** presenti in una stanza.[br]
##
## Questo nodo rappresenta **tutta la memoria del combattimento** di una stanza:[br]
## - pianificazione delle ondate[br]
## - nemici istanziati[br]
## - nemici ancora vivi[br]
## - avanzamento del combattimento[br]
##
## Note architetturali:[br]
## - Non istanzia direttamente i nemici.[br]
## - Viene letto e aggiornato da [EnemiesSpawner] e [RoomsManager].[br]
## - È contenuto all’interno di [RoomState].[br]
## - È progettato per supportare combattimenti a ondate.[br]
# ============================================================================

extends Node
class_name RoomEnemyState


# ---------------------------------------------------------------------------
# Spawn data
# ---------------------------------------------------------------------------

## Lista di celle ([Vector2i]) utilizzate come punti di spawn per i nemici.[br]
##
## I punti vengono calcolati una sola volta e riutilizzati
## per tutte le ondate della stanza.
var spawn_points: Array[Vector2i] = []


# ---------------------------------------------------------------------------
# Wave planning
# ---------------------------------------------------------------------------

## Piano delle ondate di combattimento.[br]
##
## Ogni elemento rappresenta il **numero di nemici** da spawnare
## in una specifica ondata.[br]
## La lunghezza dell’array indica il numero totale di ondate.
var wave_plan: Array[int] = []

## Indice dell’ondata corrente all’interno di [member wave_plan].[br]
##
## Viene incrementato ogni volta che una nuova ondata viene attivata.
var wave_index: int = 0


# ---------------------------------------------------------------------------
# Enemy queue & references
# ---------------------------------------------------------------------------

## Coda logica degli ID dei nemici da istanziare.[br]
##
## L’ordine è deterministico ed è calcolato dallo spawner
## in base a difficoltà, budget e peso.
var queue: Array[EnemiesRegistry.ID] = []

## Lista di **tutte** le istanze di nemici create nella stanza.[br]
##
## Include nemici:[br]
## - non ancora attivi[br]
## - già uccisi[br]
## - attualmente vivi
var enemies_references: Array[EnemyEntity] = []

## Indice utilizzato per scorrere [member enemies_references].[br]
##
## Serve a sapere quale nemico attivare/spawnare
## durante le ondate.
var enemy_index: int = 0


# ---------------------------------------------------------------------------
# Runtime combat state
# ---------------------------------------------------------------------------

## Lista dei nemici **attualmente vivi** nella stanza.[br]
##
## Viene aggiornata dinamicamente durante il combattimento
## quando un nemico muore o viene attivato.
var enemies_alive: Array[EnemyEntity] = []

## Numero totale di nemici che devono essere eliminati
## per completare la stanza.
var to_eliminate: int = 0

## Indica se il combattimento è già iniziato.[br]
##
## Usato per evitare di riattivare il combattimento
## quando il giocatore rientra nella stanza.
var started: bool = false

## Indica se la stanza è pronta per iniziare il combattimento.[br]
##
## Diventa true quando:[br]
## - nemici[br]
## - ondate[br]
## - punti di spawn[br]
## sono stati preparati correttamente.
var prepared: bool = false


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

## Costruttore dello stato dei nemici della stanza.[br]
##
## Permette di inizializzare lo stato con dati pre-calcolati
## o di usare valori di default.[br]
##
## [param _spawn_points] Celle utilizzate per lo spawn dei nemici.[br]
## [param _wave_plan] Piano delle ondate.[br]
## [param _queue] Coda degli ID dei nemici da istanziare.[br]
## [param _enemies_references] Riferimenti alle istanze create.[br]
## [param _enemies_alive] Nemici attualmente vivi.[br]
## [param _to_eliminate] Numero totale di nemici da sconfiggere.[br]
## [param _started] Flag di combattimento avviato.[br]
## [param _prepared] Flag di stanza pronta al combattimento.[br]
func _init(
	_spawn_points: Array[Vector2i] = [],
	_wave_plan: Array[int] = [],
	_queue: Array[EnemiesRegistry.ID] = [],
	_enemies_references: Array[EnemyEntity] = [],
	_enemies_alive: Array[EnemyEntity] = [],
	_to_eliminate: int = 0,
	_started: bool = false,
	_prepared: bool = false
) -> void:
	spawn_points = _spawn_points
	wave_plan = _wave_plan
	queue = _queue
	enemies_references = _enemies_references
	enemies_alive = _enemies_alive
	to_eliminate = _to_eliminate
	started = _started
	prepared = _prepared

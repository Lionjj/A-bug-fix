# ============================================================================
# RoomItemState
# ============================================================================
## Modulo che gestisce lo **stato runtime degli item** presenti in una stanza.[br]
##
## Questo nodo NON istanzia item direttamente, ma funge da **contenitore di stato**
## per tutto ciò che riguarda gli oggetti di una stanza.[br]
##
## Responsabilità:[br]
## - Conservare il catalogo logico degli item da spawnare.[br]
## - Tracciare le istanze fisiche degli item presenti nella scena.[br]
## - Conservare i punti di spawn calcolati per la stanza.[br]
## - Indicare se gli item sono già stati istanziati.[br]
##
## Note architetturali:[br]
## - Viene letto e modificato da [ItemsSpawner] e [RoomsManager].[br]
## - È contenuto all’interno di [RoomState].[br]
## - Non contiene logica attiva: è uno **stato passivo**.[br]
# ============================================================================

extends Node
class_name RoomItemState


# ---------------------------------------------------------------------------
# Logical item data
# ---------------------------------------------------------------------------

## Catalogo logico degli item della stanza.[br]
## - Chiave: [ItemRegistry.ID][br]
## - Valore: quantità di item da istanziare per quella tipologia.[br]
##
## Questo dizionario deriva dal nodo logico della stanza ([MissionNode]).
var items: Dictionary[ItemRegistry.ID, int] = {}


# ---------------------------------------------------------------------------
# Runtime references
# ---------------------------------------------------------------------------

## Lista di riferimenti alle istanze fisiche degli item presenti nella stanza.[br]
##
## Usata per:[br]
## - mostrare/nascondere item (es. a fine combattimento)[br]
## - cleanup automatico quando un item esce dall’albero[br]
## - accesso rapido agli item senza doverli cercare nella scena
var items_references: Array[ItemEntity] = []


# ---------------------------------------------------------------------------
# Spawn data
# ---------------------------------------------------------------------------

## Elenco delle celle ([Vector2i]) utilizzate come punti di spawn per gli item.[br]
##
## Queste posizioni vengono calcolate una sola volta e riutilizzate
## per coerenza e debugging.
var item_spawn_points: Array[Vector2i] = []


# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------

## Indica se gli item della stanza sono già stati istanziati.[br]
##
## Serve a evitare spawn duplicati e a distinguere tra:[br]
## - stanza preparata[br]
## - stanza ancora non inizializzata
var spawned: bool = false


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

## Costruttore dello stato degli item della stanza.[br]
##
## Permette di inizializzare lo stato con dati pre-esistenti
## oppure con valori di default.[br]
##
## [param _items] Catalogo logico degli item da spawnare.[br]
## [param _items_references] Riferimenti alle istanze fisiche già presenti.[br]
## [param _item_spawn_points] Celle utilizzate come punti di spawn.[br]
func _init(
	_items: Dictionary[ItemRegistry.ID, int] = {},
	_items_references: Array[ItemEntity] = [],
	_item_spawn_points: Array[Vector2i] = []
) -> void:
	items = _items
	items_references = _items_references
	item_spawn_points = _item_spawn_points

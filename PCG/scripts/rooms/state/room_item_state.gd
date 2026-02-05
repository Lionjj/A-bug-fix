# ============================================================================
# RoomItemState
# ============================================================================
## Modulo che gestisce lo **stato runtime degli item** presenti in una stanza.[br]
##
## Questo nodo NON istanzia item direttamente, ma funge da **contenitore di stato**
## per tutto ciò che riguarda gli oggetti associati a una stanza.[br]
##
##[br]
## [b]Responsabilità[/b]:[br]
## - Conservare il catalogo logico degli item da spawnare.[br]
## - Tracciare le istanze fisiche degli item presenti nella scena.[br]
## - Memorizzare i punti di spawn calcolati per la stanza.[br]
## - Indicare se gli item sono già stati istanziati.[br]
##
##[br]
## [b]Note architetturali[/b]:[br]
## - Viene letto e modificato da [ItemsSpawner] e [RoomsManager].[br]
## - È contenuto all’interno di [RoomState].[br]
## - Non contiene logica attiva: è uno **stato passivo**.[br]
# ============================================================================

extends RefCounted
class_name RoomItemState


# ---------------------------------------------------------------------------
# Logical item data
# ---------------------------------------------------------------------------

## Catalogo logico degli item associati alla stanza.[br]
##[br]
## - Chiave: [ItemRegistry.ID][br]
## - Valore: quantità di item da istanziare per quella tipologia.[br]
##[br]
## Questo dizionario deriva dal nodo logico della stanza ([MissionNode]).
var items: Dictionary[ItemRegistry.ID, int] = {}


# ---------------------------------------------------------------------------
# Runtime references
# ---------------------------------------------------------------------------

## Lista di riferimenti alle istanze fisiche degli item presenti nella stanza.[br]
##[br]
## Usata per:[br]
## - mostrare/nascondere item (es. a fine combattimento)[br]
## - cleanup automatico quando un item esce dallo scene tree[br]
## - accesso diretto agli item senza doverli cercare nella scena
var items_references: Array[ItemEntity] = []


# ---------------------------------------------------------------------------
# Spawn data
# ---------------------------------------------------------------------------

## Elenco delle celle ([Vector2i]) utilizzate come punti di spawn per gli item.[br]
##[br]
## Le posizioni vengono calcolate una sola volta e riutilizzate per:[br]
## - coerenza visiva[br]
## - determinismo[br]
## - debugging
var item_spawn_points: Array[Vector2i] = []


# ---------------------------------------------------------------------------
# State flags
# ---------------------------------------------------------------------------

## Indica se gli item della stanza sono già stati istanziati.[br]
##[br]
## Serve a evitare spawn duplicati e a distinguere tra:[br]
## - stanza già preparata[br]
## - stanza non ancora inizializzata
var spawned: bool = false


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

## Costruisce lo stato runtime degli item della stanza.[br]
##[br]
## Permette di inizializzare lo stato con dati già calcolati
## oppure con valori di default.[br]
##[br]
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

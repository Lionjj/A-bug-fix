# ============================================================================
# CorridorBuildContext
# ============================================================================
## Contesto dati per la fase di costruzione dei corridoi.[br]
##
## Responsabilità:[br]
## - Fornire a [CorridorBuilder] tutti i dati necessari per collegare
##   le stanze fisiche già istanziate.[br]
## - Disaccoppiare completamente la logica dei corridoi da WorldGen.[br]
##
## Contenuto:[br]
## - Nodo root del livello (per accesso al scene tree).[br]
## - Grafo logico della missione (adiacenze).[br]
## - Posizioni logiche delle stanze su griglia.[br]
## - Dimensione della cella stanza (grid spacing).[br]
## - Dimensione tile (per conversioni world ↔ cell).[br]
##
## Note architetturali:[br]
## - Oggetto immutabile dopo l’inizializzazione.[br]
## - Deve essere creato dopo lo spawn delle stanze.[br]
## - CorridorBuilder non deve mai leggere direttamente WorldGen.[br]
# ============================================================================

extends RefCounted
class_name CorridorBuildContext


# ---------------------------------------------------------------------------
# Core references
# ---------------------------------------------------------------------------

## Nodo root del livello.
## Usato per:
## - recuperare / creare il TileMapLayer dei corridoi
## - indicizzare le stanze presenti nel scene tree
var root: Node2D

## Grafo logico della missione.
## Usato per determinare quali stanze sono adiacenti.
var graph: MissionGraph

## Mapping id nodo logico -> posizione su griglia.
## Le posizioni sono in coordinate logiche (celle).
var positions: Dictionary[String, Vector2i]

## Dimensione della cella stanza in tile.
## Definisce lo spacing della griglia fisica.
var cell_tiles: Vector2i

## Dimensione del tile (fallback 16x16).
## Usata per conversioni world/cell nei TileMapLayer.
var tile_size: Vector2i = Vector2i(16, 16)


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

## Costruisce il contesto per la fase di build dei corridoi.[br]
## [br]
## [param _root] Nodo root del livello.[br]
## [param _graph] Grafo logico della missione.[br]
## [param _positions] Posizioni logiche su griglia.[br]
## [param _cell_tiles] Dimensione cella stanza in tile.[br]
## [param _tile_size] Dimensione tile (default 16x16).[br]
func _init(
	_root: Node2D,
	_graph: MissionGraph,
	_positions: Dictionary[String, Vector2i],
	_cell_tiles: Vector2i,
	_tile_size: Vector2i = Vector2i(16, 16),
) -> void:
	root = _root
	graph = _graph
	positions = _positions
	cell_tiles = _cell_tiles
	tile_size = _tile_size

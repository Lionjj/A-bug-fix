# ============================================================================
# CorridorBuildContext
# ============================================================================
## Contesto dati per la fase di costruzione dei corridoi.[br]
##[br]
## [b]Responsabilità principali[/b]:[br]
## - Fornire a [CorridorBuilder] tutti i riferimenti necessari per collegare stanze già istanziate.[br]
## - Separare la logica corridoi dall’orchestratore ([WorldGen]).[br]
## - Trasportare i dati minimi per conversioni griglia ↔ world in modo consistente.[br]
##[br]
## [b]Cosa NON fa[/b]:[br]
## - Non crea corridoi: contiene solo dati.[br]
## - Non valida la correttezza del grafo o delle posizioni.[br]
## - Non decide dove piazzare le stanze: riceve posizioni già calcolate.[br]
##[br]
## [b]Contenuto[/b]:[br]
## - [member root]: root del livello (accesso a scene tree e TileMapLayer corridoi).[br]
## - [member graph]: grafo logico (adiacenze da collegare).[br]
## - [member positions]: mapping id logico → cella su griglia.[br]
## - [member cell_tiles]: dimensione cella stanza in tile (grid spacing fisico).[br]
## - [member tile_size]: dimensione tile (conversioni world ↔ cell).[br]
##[br]
## [b]Note architetturali[/b]:[br]
## - Da trattare come immutabile dopo la costruzione.[br]
## - Va creato dopo lo spawn delle stanze: il builder deve trovare stanze/layer nello scene tree.[br]
## - [CorridorBuilder] non deve leggere direttamente [WorldGen]: questo context è il contratto.[br]
# ============================================================================

extends RefCounted
class_name CorridorBuildContext


# ---------------------------------------------------------------------------
# Core references
# ---------------------------------------------------------------------------

## Root del livello.[br]
## Usato da [CorridorBuilder] per:[br]
## - recuperare/creare il [TileMapLayer] dei corridoi[br]
## - indicizzare le stanze presenti nello scene tree[br]
var root: Node2D

## Grafo logico della missione.[br]
## Usato per determinare quali stanze (id) vanno collegate.[br]
var graph: MissionGraph

## Mapping id nodo logico → posizione su griglia.[br]
## Le posizioni sono in coordinate logiche (celle).[br]
var positions: Dictionary[String, Vector2i]

## Dimensione della cella stanza in tile.[br]
## Definisce lo spacing fisico tra stanze quando si converte la griglia in world.[br]
var cell_tiles: Vector2i

## Dimensione del tile (fallback 16x16).[br]
## Usata per conversioni tra coordinate world e celle dei [TileMapLayer].[br]
var tile_size: Vector2i = Vector2i(16, 16)


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

## Costruisce il contesto per la build dei corridoi.[br]
##[br]
## [param _root]: root del livello.[br]
## [param _graph]: grafo logico della missione.[br]
## [param _positions]: posizioni logiche su griglia (id → cella).[br]
## [param _cell_tiles]: dimensione cella stanza in tile.[br]
## [param _tile_size]: dimensione tile usata per conversioni world ↔ cell (default 16x16).[br]
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

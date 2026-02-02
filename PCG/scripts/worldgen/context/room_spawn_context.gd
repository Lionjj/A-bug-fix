# ============================================================================
# RoomSpawnContext
# ============================================================================
## Contesto dati per la fase di spawn delle stanze fisiche.[br]
##
## Responsabilità:[br]
## - Fornire a [RoomSpawner] tutte le informazioni necessarie
##   per istanziare le RoomTemplateMeta.[br]
## - Isolare completamente la fase di spawn da WorldGen.[br]
##
## Contenuto:[br]
## - Nodo root su cui aggiungere le stanze.[br]
## - Posizioni logiche delle stanze su griglia.[br]
## - Lookup inverso cella → id nodo (per adiacenze rapide).[br]
## - Grafo logico della missione.[br]
## - RoomAssembler per selezione e istanziazione template.[br]
## - Dimensione cella stanza (grid spacing).[br]
##
## Note architetturali:[br]
## - Oggetto immutabile dopo l’inizializzazione.[br]
## - Deve essere creato dopo il placement su griglia.[br]
## - RoomSpawner non deve mai leggere direttamente WorldGen.[br]
# ============================================================================

extends RefCounted
class_name RoomSpawnContext


# ---------------------------------------------------------------------------
# Core references
# ---------------------------------------------------------------------------

## Nodo root del livello.
## Tipicamente WorldGen, usato solo per add_child / ownership.
var root: Node

## Mapping id nodo logico -> posizione su griglia.
var positions: Dictionary[String, Vector2i]

## Mapping inverso posizione su griglia -> id nodo logico.
## Usato per calcolo adiacenze in O(1).
var occupied: Dictionary[Vector2i, String]

## RNG del livello.
## Deve essere lo stesso usato nella generazione per garantire coerenza.
var rng: RandomNumberGenerator

## Abilità possedute dal player (usate per filtro template / gating).
## Devono essere le stesse usato nella generazione per garantire coerenza.
var abilities: Array[Abilities.Ability]

## Grafo logico della missione.
var graph: MissionGraph

## Assembler responsabile della selezione template e istanziazione.
var assembler: RoomAssembler

## Dimensione cella stanza in tile.
## Usata per convertire coordinate logiche → world.
var cell_tiles: Vector2i


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

## Costruisce il contesto per la fase di spawn delle stanze.[br]
## [br]
## [param _root] Nodo root del livello.[br]
## [param _positions] Posizioni logiche su griglia.[br]
## [param _occupied] Lookup inverso cella → id nodo.[br]
## [param _graph] Grafo logico della missione.[br]
## [param _assembler] RoomAssembler da usare.[br]
## [param _cell_tiles] Dimensione cella stanza in tile.[br]
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

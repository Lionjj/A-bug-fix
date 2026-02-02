# ============================================================================
# WorldGen
# ============================================================================
## Nodo root che orchestra la pipeline di generazione del livello.[br]
##
## Flusso:[br]
## 1) Generazione grafo logico + RNG (GraphPipeline)[br]
## 2) Placement su griglia (GridPlacerBFS)[br]
## 3) Selezione/istanza stanze (RoomAssembler + RoomSpawner)[br]
## 4) Costruzione corridoi (CorridorBuilder)[br]
## 5) Merge tilemap + spawn player (WorldFinalize)[br]
## 6) Setup manager runtime (RoomsManager)[br]
##
## Note architetturali:[br]
## - WorldGen è un orchestrator: coordina moduli stateless tramite Context dedicati.[br]
## - In caso di grafo non solvibile, la scena viene ricaricata e la pipeline riparte.[br]
# ============================================================================

extends Node2D
class_name WorldGen


# ---------------------------------------------------------------------------
# Export / Config
# ---------------------------------------------------------------------------

@export var budget_nodes: int
@export var seed: int
@export var player_scene: PackedScene
@export var run_level: int = 1


# ---------------------------------------------------------------------------
# Scene refs
# ---------------------------------------------------------------------------

@onready var auto_tiles: Node = $AutoTiles

## TileMapLayer finale risultante dal merge.
## Nota: viene assegnato a runtime da WorldFinalize.
var final: TileMapLayer = null


# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------

## Abilità possedute dal player (usate per filtro template / gating).
var abilities: Array[Abilities.Ability] = [
	Abilities.Ability.GRAPPLE,
	Abilities.Ability.DASH,
]

## RNG derivato dalla pipeline (seed effettivo).
var rng: RandomNumberGenerator = null

## Grafo logico della missione.
var graph: MissionGraph = null


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal final_layer_ready


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	build()


# ---------------------------------------------------------------------------
# Build pipeline
# ---------------------------------------------------------------------------

## Esegue l’intera generazione del livello.[br]
## - I moduli ricevono Context dedicati per ridurre coupling.[br]
func build() -> void:
	# --- 1) Graph pipeline (CRITICAL) ---
	var pipeline: GraphPipeline.Result = GraphPipeline.run(seed, budget_nodes)
	if not pipeline.solvable:
		# Retry completo: reload scena -> pipeline riparte
		get_tree().reload_current_scene()
		return

	seed = pipeline.seed
	rng = pipeline.rng
	graph = pipeline.graph

	# --- 2) Grid placement ---
	var placer_result: GridPlacerBFS.Result = GridPlacerBFS.place(graph, rng)
	var positions: Dictionary[String, Vector2i] = placer_result.positions
	var occupied: Dictionary[Vector2i, String] = placer_result.occupied

	# --- 3) Room assembling ---
	var assembler: RoomAssembler = RoomAssembler.new()
	var cell_tiles: Vector2i = assembler.max_room_size_tiles() + Vector2i(4, 4)

	# --- 4) Spawn rooms ---
	var spawner: RoomSpawner = RoomSpawner.new()
	var spawn_ctx: RoomSpawnContext = RoomSpawnContext.new(self, positions, occupied, rng, abilities, graph, assembler, cell_tiles)
	var rooms: Dictionary[RoomTemplateMeta, RoomState] = spawner.spawn_all(spawn_ctx)

	# --- 5) Spawn point ---
	var spawn_point: Vector2 = _get_spawn_point_from_start_room()

	# --- 6) Corridors ---
	var corridor_ctx: CorridorBuildContext = CorridorBuildContext.new(self, graph, positions, cell_tiles)
	CorridorBuilder.connect_adjacent(corridor_ctx)

	# --- 7) Finalize (merge + player spawn) ---
	var fin_ctx := WorldFinalizeContext.new(self, seed, auto_tiles, player_scene, spawn_point)
	final = WorldFinalize.merge_and_spawn(fin_ctx)
	final_layer_ready.emit()

	# --- 8) Runtime manager ---
	var rooms_ctx: RoomsManagerContext = RoomsManagerContext.new(graph, rooms, positions, GameManager.player, rng, run_level)
	add_child(RoomsManager.new(rooms_ctx))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Legge lo spawn point dalla start room (prima stanza nel gruppo "rooms").[br]
## Fallback: Vector2.ZERO se non trovata.[br]
func _get_spawn_point_from_start_room() -> Vector2:
	var start_room := get_tree().get_first_node_in_group("rooms") as RoomTemplateMeta
	if start_room == null:
		push_error("Start room not found")
		return Vector2.ZERO

	return start_room.get_spawn_point().global_position

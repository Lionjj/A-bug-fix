# ============================================================================
# RoomAssemblerContext
# ============================================================================
## Contesto condiviso durante l’assemblaggio delle stanze.[br]
##
## [b]Responsabilità principali[/b]:[br]
## - Contenere lo stato necessario all’assemblaggio dei template stanza.[br]
## - Ridurre il passaggio ripetuto di parametri tra funzioni del [RoomAssembler] e componenti collegati.[br]
## - Rendere il processo riproducibile (RNG unico) e più semplice da ispezionare in debug.[br]
##[br]
## [b]Cosa NON fa[/b]:[br]
## - Non prende decisioni di selezione: la scelta è delegata a [RoomTemplatePicker] e alle regole.[br]
## - Non esegue istanziazione o placement fisico della stanza.[br]
## - Non valida la solvibilità della missione.[br]
##[br]
## [b]Contenuto[/b]:[br]
## - [member catalog]: catalogo dei template disponibili.[br]
## - [member picker]: selezione template in base a vincoli e scoring.[br]
## - [member rng]: RNG condiviso seedato a monte (determinismo).[br]
## - [member graph]: grafo logico della missione.[br]
## - [member positions]: posizioni logiche su griglia (id → cella).[br]
## - [member abilities]: abilità disponibili al player (gating).[br]
## - [member connector_req]: requisiti connettori per il nodo corrente.[br]
## - [member placed_scenes]: bookkeeping delle scene scelte per nodo.[br]
## - [member placed_infos]: bookkeeping delle info del template scelto per nodo.[br]
##[br]
## [b]Note architetturali[/b]:[br]
## - Data container: contiene dati, non strategia.[br]
## - Pensato per vivere per una singola generazione di mappa.[br]
## - Le strutture “placed_*” servono a garantire coerenza tra scelte e a fare debug post-mortem.[br]
# ============================================================================

extends RefCounted
class_name RoomAssemblerContext


# ---------------------------------------------------------------------------
# Core systems
# ---------------------------------------------------------------------------

## Catalogo centrale dei template stanza.[br]
var catalog: RoomTemplateCatalog

## Picker responsabile della selezione dei template.[br]
var picker: RoomTemplatePicker

## RNG condiviso (seedato a monte).[br]
var rng: RandomNumberGenerator


# ---------------------------------------------------------------------------
# Graph / layout
# ---------------------------------------------------------------------------

## Grafo logico della missione.[br]
var graph: MissionGraph

## Posizioni dei nodi nella griglia logica.[br]
## Mapping { node_id → Vector2i }.[br]
var positions: Dictionary[String, Vector2i] = {}


# ---------------------------------------------------------------------------
# Assembly constraints
# ---------------------------------------------------------------------------

## Requisiti espliciti sui connettori per il nodo corrente.[br]
## Mapping {"N":bool,"E":bool,"S":bool,"W":bool}.[br]
var connector_req: Dictionary[String, bool] = {}


# ---------------------------------------------------------------------------
# Output / bookkeeping
# ---------------------------------------------------------------------------

## Scene selezionate (template finale) per nodo.[br]
## Mapping { node_id → PackedScene }.[br]
var placed_scenes: Dictionary[String, PackedScene] = {}

## Info del template scelto per nodo (utile per debug/scoring).[br]
## Mapping { node_id → RoomTemplateInfo }.[br]
var placed_infos: Dictionary[String, RoomTemplateInfo] = {}


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

## Costruisce il contesto condiviso per l’assemblaggio.[br]
##[br]
## [param _catalog]: catalogo dei template disponibili.[br]
## [param _picker]: selettore dei template (scoring + vincoli).[br]
## [param _graph]: grafo logico della missione.[br]
## [param _rng]: RNG condiviso seedato a monte.[br]
## [param _abilities]: abilità disponibili al player.[br]
## [param _positions]: posizioni dei nodi sulla griglia logica.[br]
func _init(
	_catalog: RoomTemplateCatalog,
	_picker: RoomTemplatePicker,
	_graph: MissionGraph,
	_rng: RandomNumberGenerator,
	_positions: Dictionary[String, Vector2i]
) -> void:
	catalog = _catalog
	picker = _picker
	graph = _graph
	rng = _rng
	positions = _positions


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Ritorna il [MissionNode] associato a un id.[br]
##[br]
## [param id]: id del nodo logico.[br]
##[br]
## [return]: [MissionNode] se presente, altrimenti null.[br]
func node(id: String) -> MissionNode:
	return graph.nodes.get(id, null)


## Registra la scelta finale per un nodo.[br]
##[br]
## Scopo:[br]
## - Tenere traccia della scena/template scelto.[br]
## - Rendere il processo ispezionabile (debug e telemetria).[br]
##[br]
## [param node_id]: id del nodo logico a cui associare la scelta.[br]
## [param scene]: scena/template selezionato.[br]
## [param info]: info strutturata del template scelto.[br]
func register_choice(
	node_id: String,
	scene: PackedScene,
	info: RoomTemplateInfo
) -> void:
	placed_scenes[node_id] = scene
	placed_infos[node_id] = info

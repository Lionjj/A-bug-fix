extends Node2D
class_name RoomTemplateMeta

## Stringa rappresentante il tipo della stanza.
@export var kind: String = "ARENA"
## Dimensione in tile della stanza.
@export var size_tiles: Vector2i = Vector2i(80,48)
## Abilità obbligatorie per superare la stanza.
@export var requires: Array[Abilities.Ability] = []
@export var difficulty: int = 1

# Connettori dichiarati: true = presente, false = assente
@export var connectors := {"N":false, "E":true, "S":false, "W":true}

# Convenzione: nel scene tree devono esistere Marker2D con questi nomi se true
const CONNECTOR_NAMES := {"N":"conn_N","E":"conn_E","S":"conn_S","W":"conn_W"}

const PIXEL = 16


@export var base_weight: float = 1.0												# “quanto vuole apparire” il template
@export var tags: Array[String] = []												# es: ["vertical","gap","combat","platforming"]

@onready var collision: TileMapLayer = $Collision
#@onready var enemy_spawner : EnemySpawner = $EnemySpawner

## Area usata per verificare quando un giocatore etra in una stanza.
var bounds: Rect2 = Rect2()

## Valore privato che rappresneta quando il giocatore entra in una stanza istanziata.
var _player_entered: bool = false

## Elenco di punti disponibili per lo spawn all'interno della stanza.
var spawn_points: Array[Vector2i] = []

## Elenco di punti disponibili per lo spawn di oggetti.
var item_spawn_points: Array[Vector2i] = []

## Elenco di punti disponibili per lo spawn di nemici.
var enemy_spawn_points: Array[Vector2i] = []

## Nodo del grafo logico
var logic_node: MissionNode = null :
	set(_logic_node): logic_node = _logic_node

## Lista di riferimenti alle porte della stanza corrente, variabile di utilità per semplificarne 
## il loro accesso e la loro gestione.
var doors: Array[Door] = []

## Dizionario contenente il nome dell'oggetto e la quantità di oggetti che devono 
## essere istanziati.
var items : Dictionary[ItemRegistry.ID, int] = {}

## Lista di riferimenti agli oggetti della stanza corrente, variabile di utilità per semplificarne 
## il loro accesso e la loro gestione.
var items_references: Array[ItemEntity] = []

var enemies_references: Dictionary = {}

## Numero di nemici per ondata che la stanza deve gestire, il numero di elementi della lista 
## rappresenta inoltre quante ondate ci sono
var enemies_waves: Array[int] = []

signal done
## Segnale emesso quando un giocatore entra nella stanza.
signal player_entered(room: RoomTemplateMeta)
## Segnale emesso quando un giocatore esce della stanza.
signal player_exited(room: RoomTemplateMeta)

signal enemies_cleared(room: RoomTemplateMeta)

func _ready() -> void:
	## Caricare le posizioni interne per lo spawn
	spawn_points = SmartPlacement.compute_internal_cells(self)
	
	#if !enemy_spawner: return
	#
	#enemy_spawner.done.connect(func(): emit_signal("done"))


func get_spawn_point() -> Marker2D:
	var spawn: Marker2D = $Spawn
	return spawn

## Verifica in che stanza sta il player.
func update_player_presence(player: Player) -> void:
	#var player_pos : Vector2 = player.global_position
	var player_shape : CapsuleShape2D = player.ground_collision_2d.shape as CapsuleShape2D
	
	var player_transform : Transform2D = player.ground_collision_2d.global_transform
	var center : Vector2 = player_transform.origin
	
	## Area della forma shape del player
	var w : float = player_shape.radius * 2.0
	var h : float = player_shape.height + w
	
	## Scala globlale
	var player_scale : Vector2 = player.ground_collision_2d.global_scale
	var half := Vector2(w * abs(player_scale.x), h * abs(player_scale.y)) * 0.5
	
	
	var player_aabb := Rect2(center - half, half * 2.0)
	
	var is_inside : bool = bounds.encloses(player_aabb)
	
	if is_inside and not _player_entered:
		_player_entered = true
		emit_signal("player_entered", self)
	elif not is_inside and _player_entered:
		_player_entered = false
		emit_signal("player_exited", self)

# ====== Helper ======

## Restitusice un dizzionario di [class RoomConnector] identificati dalla posizione cardinle:
## - "N" = Nord;
## - "S" = Sud;
## - "W" = West;
## - "E" = Est;
func get_connectors() -> Dictionary[String, RoomConnector]:
	var out : Dictionary[String, RoomConnector] = {}
	for conn in CONNECTOR_NAMES.keys():
		var current : RoomConnector = get_node_or_null(CONNECTOR_NAMES.get(conn)) as RoomConnector
		if !current: continue
		out[conn] = current
	
	return out

func center_to_top_left(center_cell: Vector2i, tiles_x: int, tiles_y: int) -> Vector2:
	# offset in celle
	var offset_x := tiles_x / 2
	var offset_y := tiles_y / 2

	var top_left_cell: Vector2i = center_cell - Vector2i(offset_x, offset_y)

	# conversione finale in pixel
	return Vector2(top_left_cell) * PIXEL

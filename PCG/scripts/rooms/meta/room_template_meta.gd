# ============================================================================
# RoomTemplateMeta
# ============================================================================
## Rappresenta una stanza fisica del mondo di gioco.[br]
##
## Responsabilità:[br]
## - Contenere la geometria della stanza (TileMap).[br]
## - Esporre metadati logici (tipo, difficoltà, abilità richieste).[br]
## - Gestire la presenza del player nella stanza.[br]
## - Fungere da owner del [RoomPlacementManager] (spawn, occupazione, buffer).[br]
##
## Coordinate:[br]
## - Tutto ciò che riguarda spawn e placement lavora in CELLE ([Vector2i]).[br]
##
## Architettura:[br]
## - Ogni stanza possiede il proprio PlacementManager.[br]
## - Nessuna interferenza tra stanze.[br]
## - Lifecycle chiaro e confinato.
# ============================================================================

extends Node2D
class_name RoomTemplateMeta


# ---------------------------------------------------------------------------
# Metadati stanza
# ---------------------------------------------------------------------------

## Tipo logico della stanza (es. "ARENA", "PUZZLE", "BOSS").
@export var kind: RoomTags.Tag = RoomTags.Tag.ARENA

## Dimensione della stanza in tile.
@export var size_tiles: Vector2i = Vector2i(80, 48)

## Abilità obbligatorie per superare la stanza.
@export var requires: Array[Abilities.Ability] = []

## Difficoltà della stanza (scala arbitraria).
@export var difficulty: int = 1


# ---------------------------------------------------------------------------
# Connettori
# ---------------------------------------------------------------------------

## Connettori dichiarati:[br]
## - true  → connettore presente[br]
## - false → connettore assente
@export var connectors: Dictionary[String, bool] = {
	"N": false,
	"E": true,
	"S": false,
	"W": true
}

## Convenzione:[br]
## - Se un connettore è true, nel scene tree deve esistere un Marker2D
##   con il nome specificato in questa mappa.
const CONNECTOR_NAMES: Dictionary[String, String] = {
	"N": "conn_N",
	"E": "conn_E",
	"S": "conn_S",
	"W": "conn_W"
}


# ---------------------------------------------------------------------------
# Costanti (no magic numbers)
# ---------------------------------------------------------------------------

## Dimensione di un tile in pixel.
const TILE_SIZE_PX: int = 16

## Default “safe” per bounds finché non viene calcolato altrove.
const DEFAULT_BOUNDS: Rect2 = Rect2(Vector2.ZERO, Vector2.ZERO)

## Moltiplicatori usati per derivare dimensioni della capsule del player.
const CAPSULE_DIAMETER_MULT: float = 2.0
const HALF_MULT: float = 0.5

## Direzioni dei connettori (serve se vuoi iterare in modo deterministico).
const CONNECTOR_DIRS: Array[String] = ["N", "E", "S", "W"]


# ---------------------------------------------------------------------------
# Peso e tag per PCG
# ---------------------------------------------------------------------------

## Peso base del template (probabilità di selezione nel PCG).
@export var base_weight: float = 1.0

## Tag semantici per il PCG.[br]
@export_flags(
	"START","HUB","CHALLENGE","KEY_ROOM","SAVE","SIDE","ARENA","BOSS", "FALLBACK"
)
var tag_mask: int = 0


# ---------------------------------------------------------------------------
# Nodi e componenti
# ---------------------------------------------------------------------------

## TileMapLayer di collisione della stanza.
@onready var collision: TileMapLayer = $Collision

## Placement manager responsabile di spawn e occupazione celle.
@onready var placement: RoomPlacementManager = RoomPlacementManager.new()


# ---------------------------------------------------------------------------
# Stato runtime
# ---------------------------------------------------------------------------

## Bounding box globale della stanza (in pixel).[br]
## Usata per verificare ingresso/uscita del player.
var bounds: Rect2 = DEFAULT_BOUNDS

## Flag interno: true se il player è attualmente nella stanza.
var _player_entered: bool = false


# ---------------------------------------------------------------------------
# Riferimenti logici
# ---------------------------------------------------------------------------

## Nodo del grafo logico associato alla stanza.
var logic_node: MissionNode = null

## Riferimenti alle porte fisiche della stanza.
var doors: Array[Door] = []


# ---------------------------------------------------------------------------
# Segnali
# ---------------------------------------------------------------------------

## Emesso quando la stanza viene completata.
signal done

## Emesso quando il player entra nella stanza.
signal player_entered(room: RoomTemplateMeta)

## Emesso quando il player esce dalla stanza.
signal player_exited(room: RoomTemplateMeta)


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	## Inizializza il PlacementManager a partire dalla stanza.
	add_child(placement)
	placement.name = "Placement"


# ---------------------------------------------------------------------------
# Spawn helpers
# ---------------------------------------------------------------------------

## Restituisce il marker di spawn principale della stanza.
##
## @return Marker2D di spawn.
func get_spawn_point() -> Marker2D:
	return $Spawn as Marker2D


# ---------------------------------------------------------------------------
# Player presence
# ---------------------------------------------------------------------------

## Aggiorna lo stato di presenza del player nella stanza.[br]
## Emette i segnali di ingresso e uscita.[br]
##
## [param player] Player da verificare.
func update_player_presence(player: Player) -> void:
	var collider: CollisionShape2D = player.ground_collision_2d
	if collider == null:
		return

	var shape: CapsuleShape2D = collider.shape as CapsuleShape2D
	if shape == null:
		return

	var center: Vector2 = collider.global_transform.origin

	## Dimensioni locali della capsule
	var width: float = shape.radius * CAPSULE_DIAMETER_MULT
	var height: float = shape.height + width

	## Scala globale del collider
	var scale: Vector2 = collider.global_scale
	var half_extents: Vector2 = Vector2(
		width * abs(scale.x),
		height * abs(scale.y)
	) * HALF_MULT

	var player_aabb: Rect2 = Rect2(center - half_extents, half_extents * CAPSULE_DIAMETER_MULT)

	var is_inside: bool = bounds.encloses(player_aabb)

	## Early-exit leggibile
	if is_inside == _player_entered:
		return

	_player_entered = is_inside

	if is_inside:
		player_entered.emit(self)
	else:
		player_exited.emit(self)


# ---------------------------------------------------------------------------
# Connettori
# ---------------------------------------------------------------------------

## Restituisce i connettori fisici della stanza indicizzati per direzione.[br]
##
## @return Dictionary[String, RoomConnector]
func get_connectors() -> Dictionary[String, RoomConnector]:
	var result: Dictionary[String, RoomConnector] = {}

	## Iterazione deterministica (evita dipendenze dall'ordine delle keys del dict)
	for dir: String in CONNECTOR_DIRS:
		if not CONNECTOR_NAMES.has(dir):
			continue

		var node_name: String = CONNECTOR_NAMES[dir]
		var connector: RoomConnector = get_node_or_null(node_name) as RoomConnector
		if connector == null:
			continue

		result[dir] = connector

	return result


# ---------------------------------------------------------------------------
# Utility coordinate
# ---------------------------------------------------------------------------

## Converte una cella centrale in coordinate pixel top-left
## di un rettangolo di dimensione (tiles_x, tiles_y).[br]
##
## [param center_cell] Cella centrale.[br]
## [param tiles_x] Larghezza in tile.[br]
## [param tiles_y] Altezza in tile.[br]
##
## @return Posizione top-left in pixel.
func center_to_top_left(
	center_cell: Vector2i,
	tiles_x: int,
	tiles_y: int
) -> Vector2:
	var offset: Vector2i = Vector2i(tiles_x / 2, tiles_y / 2)
	var top_left_cell: Vector2i = center_cell - offset

	return Vector2(top_left_cell) * TILE_SIZE_PX

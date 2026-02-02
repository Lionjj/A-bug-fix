# ============================================================================
# WorldFinalizeContext
# ============================================================================
## Contesto dati per la fase di finalizzazione del livello.[br]
##
## Responsabilità:[br]
## - Fornire a [WorldFinalize] tutte le informazioni necessarie
##   per completare la generazione del livello.[br]
## - Isolare la fase finale (merge tilemap + spawn player)
##   dal nodo orchestratore ([WorldGen]).[br]
##
## Operazioni supportate:[br]
## - Merge dei TileMapLayer in un layer finale.[br]
## - Inizializzazione del sistema di autotiling.[br]
## - Spawn e setup del player.[br]
##
## Contenuto:[br]
## - Nodo root del livello.[br]
## - Seed definitivo della run.[br]
## - Nodo AutoTiles per inizializzazione post-merge.[br]
## - Scena del player da istanziare.[br]
## - Punto di spawn del player (world-space).[br]
##
## Note architetturali:[br]
## - Oggetto immutabile dopo l’inizializzazione.[br]
## - Deve essere creato solo dopo il completamento di stanze e corridoi.[br]
## - WorldFinalize non deve accedere direttamente a WorldGen.[br]
# ============================================================================

extends RefCounted
class_name WorldFinalizeContext


# ---------------------------------------------------------------------------
# Core references
# ---------------------------------------------------------------------------

## Nodo root del livello.
## Tipicamente WorldGen.
var level_root: Node

## Seed definitivo della run.
## Usato per sincronizzare sistemi post-merge (es. autotiling).
var seed: int

## Nodo responsabile dell’autotiling finale.
var auto_tiles: Node

## Scena del player da istanziare.
var player_scene: PackedScene

## Punto di spawn del player in coordinate world.
var spawn_point: Vector2


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

## Costruisce il contesto per la fase di finalize del livello.[br]
## [br]
## [param _level_root] Nodo root del livello.[br]
## [param _seed] Seed definitivo della run.[br]
## [param _auto_tiles] Nodo AutoTiles.[br]
## [param _player_scene] Scena del player.[br]
## [param _spawn_point] Posizione world di spawn del player.[br]
func _init(
	_level_root: Node,
	_seed: int,
	_auto_tiles: Node,
	_player_scene: PackedScene,
	_spawn_point: Vector2,
) -> void:
	level_root = _level_root
	seed = _seed
	auto_tiles = _auto_tiles
	player_scene = _player_scene
	spawn_point = _spawn_point

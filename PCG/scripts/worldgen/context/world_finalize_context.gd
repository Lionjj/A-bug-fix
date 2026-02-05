# ============================================================================
# WorldFinalizeContext
# ============================================================================
## Contesto dati per la fase di finalizzazione del livello.[br]
##
## [b]Responsabilità principali[/b]:[br]
## - Fornire a [WorldFinalize] tutti i riferimenti necessari per chiudere la pipeline.[br]
## - Separare la fase “finale” (merge + spawn) dall’orchestrazione generale ([WorldGen]).[br]
##[br]
## [b]Cosa NON fa[/b]:[br]
## - Non esegue operazioni: contiene solo dati.[br]
## - Non valida la correttezza della pipeline: i guard sono responsabilità del chiamante/consumer.[br]
##[br]
## [b]Operazioni abilitate da questo context[/b]:[br]
## - Merge dei [TileMapLayer] in un layer finale.[br]
## - Inizializzazione del sistema di autotiling post-merge.[br]
## - Spawn e setup del player.[br]
##[br]
## [b]Contenuto[/b]:[br]
## - [member level_root]: root del livello su cui operare.[br]
## - [member seed]: seed effettivo della run (coerenza post-merge).[br]
## - [member auto_tiles]: nodo AutoTiles opzionale.[br]
## - [member player_scene]: scena del player da instanziare.[br]
## - [member spawn_point]: posizione world di spawn.[br]
##[br]
## [b]Note architetturali[/b]:[br]
## - Da trattare come immutabile dopo la costruzione: chi lo consuma deve leggerlo, non modificarlo.[br]
## - Va creato solo quando stanze e corridoi esistono già (altrimenti il merge non ha senso).[br]
## - [WorldFinalize] non deve conoscere [WorldGen]: questa classe è il “contratto” tra i due.[br]
# ============================================================================

extends RefCounted
class_name WorldFinalizeContext


# ---------------------------------------------------------------------------
# Core references
# ---------------------------------------------------------------------------

## Root del livello su cui operare.[br]
## Tipicamente l’istanza di [WorldGen], o un suo nodo equivalente usato come contenitore.[br]
var level_root: Node

## Seed effettivo della run.[br]
## Usato per sincronizzare sistemi post-merge (es. autotiling) e mantenere riproducibilità.[br]
var seed: int

## Nodo responsabile dell’autotiling finale (opzionale).[br]
## Se null, la fase di seed autotiles viene semplicemente saltata.[br]
var auto_tiles: Node

## Scena del player da instanziare (obbligatoria per rendere il livello giocabile).[br]
var player_scene: PackedScene

## Posizione di spawn del player in coordinate world.[br]
var spawn_point: Vector2


# ---------------------------------------------------------------------------
# Init
# ---------------------------------------------------------------------------

## Costruisce il contesto per la fase di finalize.[br]
##[br]
## [param _level_root]: root del livello su cui verranno eseguiti merge e spawn.[br]
## [param _seed]: seed effettivo della run.[br]
## [param _auto_tiles]: nodo AutoTiles (può essere null).[br]
## [param _player_scene]: scena del player da instanziare.[br]
## [param _spawn_point]: posizione world di spawn del player.[br]
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

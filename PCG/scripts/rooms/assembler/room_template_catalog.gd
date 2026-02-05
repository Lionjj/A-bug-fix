# ============================================================================
# RoomTemplateCatalog
# ============================================================================
## Catalogo centrale dei template di stanza.[br]
##
## Responsabilità:[br]
## - Caricare tutti i PackedScene delle stanze da una directory.[br]
## - Fornire accesso ai template tramite key.[br]
## - Mantenere una ban list (template esclusi dalla selezione).[br]
## - Estrarre e cache-are i metadati tipizzati (RoomTemplateInfo).[br]
##
## Nota di design:[br]
## - Questo modulo è PASSIVO: non prende decisioni di gameplay.[br]
## - Non filtra per abilità, tag, kind o connettori.[br]
## - È una sorgente di dati condivisa (single source of truth).[br]
## - La cache evita istanziazioni ripetute delle scene.[br]
# ============================================================================

extends RefCounted
class_name RoomTemplateCatalog

# ---------------------------------------------------------------------------
# Configuration (no magic numbers)
# ---------------------------------------------------------------------------

## Path di default per il caricamento dei template stanza.
const DEFAULT_PATH: String = "res://PCG/scenes/rooms/tmpl"

## Estensione di default per i template.
const DEFAULT_EXTENSION: String = "tscn"

## Key fallback se serve indicizzare in modo sicuro (es. accesso keys[0]).
const FALLBACK_INDEX: int = 0

## Stringa vuota standard (evita "magic string" ripetute).
const EMPTY_STRING: String = ""

## Logging: prefisso coerente.
const LOG_PREFIX: String = "RoomTemplateCatalog"

## Sicurezza: evita loop infiniti in casi strani (DirAccess).
const DIR_LOOP_SAFETY_MAX: int = 100_000


# ---------------------------------------------------------------------------
# Internal storage
# ---------------------------------------------------------------------------

## Catalogo dei template caricati.[br]
## key (String) -> PackedScene
##
## Nota:[br]
## - La key è il basename del file in uppercase.[br]
## - Usata come identificatore stabile del template.
var templates: Dictionary[String, PackedScene] = {}

## Ban list dei template.[br]
## key -> true
##
## Usata per:[br]
## - Template one-shot (START).[br]
## - Template già consumati.[br]
## - Debug / esclusioni forzate.
var banned: Dictionary[String, bool] = {}

## Cache dei metadati tipizzati.[br]
## key -> RoomTemplateInfo
##
## Perché esiste:[br]
## - Istanziare scene è costoso.[br]
## - I metadati sono immutabili dopo il load.[br]
## - Un template viene letto molte volte dal picker.
var _info_cache: Dictionary[String, RoomTemplateInfo] = {}


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

## Costruttore.[br]
## [param path] Directory da cui caricare i template.
func _init(path: String = DEFAULT_PATH) -> void:
	templates = _load_templates_from_dir(path, DEFAULT_EXTENSION)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Ritorna tutte le chiavi dei template caricati.[br]
## [return] Array[String] delle key.
func keys() -> Array[String]:
	return templates.keys()


## Ritorna il PackedScene associato a una key.[br]
##
## Fail-first:[br]
## - Se la key non esiste ritorna null.
##
## [param key] Identificatore del template.[br]
## [return] PackedScene o null.
func get_scene(key: String) -> PackedScene:
	return templates.get(key, null)


## True se il template è bannato.[br]
##
## [param key] Identificatore del template.[br]
## [return] True se bannato.
func is_banned(key: String) -> bool:
	return bool(banned.get(key, false))


## Banna esplicitamente un template.[br]
##
## Usato tipicamente per:[br]
## - START one-shot.[br]
## - Template consumati.[br]
##
## [param key] Identificatore del template.
func ban_key(key: String) -> void:
	if key != EMPTY_STRING:
		banned[key] = true


## Ritorna la key associata a un PackedScene.[br]
##
## Nota:[br]
## - Lookup lineare: costo accettabile (catalogo piccolo).[br]
##
## Fail-first:[br]
## - Se la scena non appartiene al catalogo ritorna stringa vuota.
##
## [param scene] PackedScene.[br]
## [return] Key o "".
func key_of_scene(scene: PackedScene) -> String:
	if scene == null:
		return EMPTY_STRING

	for k: String in templates.keys():
		if templates[k] == scene:
			return k
	return EMPTY_STRING


## Ritorna i metadati tipizzati associati a una key.[br]
##
## Comportamento:[br]
## - Usa cache se disponibile.[br]
## - Istanzia la scena SOLO al primo accesso.[br]
##
## Fail-first:[br]
## - Se la key non esiste o la scena è invalida ritorna null.
##
## [param key] Identificatore del template.[br]
## [return] RoomTemplateInfo o null.
func info_of_key(key: String) -> RoomTemplateInfo:
	if _info_cache.has(key):
		return _info_cache[key]

	var scene: PackedScene = templates.get(key, null)
	if scene == null:
		return null

	var info: RoomTemplateInfo = _build_info(key, scene)
	if info == null:
		return null

	_info_cache[key] = info
	return info


## Ritorna i metadati tipizzati partendo da un PackedScene.[br]
##
## Fail-first:[br]
## - Se la scena non appartiene al catalogo ritorna null.
##
## [param scene] PackedScene.[br]
## [return] RoomTemplateInfo o null.
func info_of_scene(scene: PackedScene) -> RoomTemplateInfo:
	if scene == null:
		return null

	var key: String = key_of_scene(scene)
	if key == EMPTY_STRING:
		return null

	return info_of_key(key)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Costruisce un RoomTemplateInfo a partire da un PackedScene.[br]
##
## Comportamento:[br]
## - Istanzia temporaneamente la scena.[br]
## - Verifica che sia RoomTemplateMeta.[br]
## - Estrae i dati.[br]
## - Libera immediatamente l'istanza.[br]
##
## Fail-first:[br]
## - Se l'istanza NON è RoomTemplateMeta ritorna null.
##
## [param key] Identificatore del template.[br]
## [param scene] PackedScene.[br]
## [return] RoomTemplateInfo o null.
func _build_info(key: String, scene: PackedScene) -> RoomTemplateInfo:
	var inst := scene.instantiate()
	if inst == null:
		return null

	var room := inst as RoomTemplateMeta
	if room == null:
		inst.queue_free()
		return null

	var info := RoomTemplateInfo.from_room(key, room)
	inst.queue_free()
	return info


## Carica tutti i PackedScene da una directory.[br]
##
## Comportamento:[br]
## - Filtra per estensione.[br]
## - Ignora sottodirectory.[br]
## - Usa il basename uppercase come key.[br]
##
## Fail-first:[br]
## - Se la directory non è accessibile ritorna dizionario vuoto.
##
## [param path] Path directory.[br]
## [param extension] Estensione file (default "tscn").[br]
## [return] Dictionary[key -> PackedScene].
func _load_templates_from_dir(
	path: String,
	extension: String = DEFAULT_EXTENSION
) -> Dictionary[String, PackedScene]:

	var out: Dictionary[String, PackedScene] = {}

	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		push_error("%s: impossibile aprire dir: %s" % [LOG_PREFIX, path])
		return out

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	var safety: int = DIR_LOOP_SAFETY_MAX
	while file_name != EMPTY_STRING and safety > 0:
		safety -= 1

		## Fail-first: scarta subito sottodirectory o estensione non compatibile.
		if dir.current_is_dir() or file_name.get_extension() != extension:
			file_name = dir.get_next()
			continue

		var full_path: String = path.path_join(file_name)
		out[file_name.get_basename().to_upper()] = load(full_path)

		file_name = dir.get_next()

	if safety <= 0:
		push_error("%s: loop safety trigger in _load_templates_from_dir(%s)" % [LOG_PREFIX, path])

	return out

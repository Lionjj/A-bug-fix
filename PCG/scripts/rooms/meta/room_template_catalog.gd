# ============================================================================
# RoomTemplateCatalog
# ============================================================================
## Catalogo template stanza + cache RoomTemplateInfo.[br]
##
## Responsabilità:[br]
## - Caricare PackedScene da directory.[br]
## - Ban list (es. START one-shot).[br]
## - Cache dei metadati tipizzati (RoomTemplateInfo).[br]
# ============================================================================

extends RefCounted
class_name RoomTemplateCatalog

const DEFAULT_PATH: String = "res://PCG/scenes/rooms/tmpl"

var templates: Dictionary[String, PackedScene] = {}              ## key -> scene
var banned: Dictionary[String, bool] = {}                        ## key -> bool
var _info_cache: Dictionary[String, RoomTemplateInfo] = {}        ## key -> info (cache)

func _init(path: String = DEFAULT_PATH) -> void:
	templates = _load_templates_from_dir(path)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func all_keys() -> Array[String]:
	return templates.keys()

func scene_of(key: String) -> PackedScene:
	return templates.get(key, null)

func is_banned(key: String) -> bool:
	return bool(banned.get(key, false))

func ban_key(key: String) -> void:
	if key != "":
		banned[key] = true

func key_of_scene(scene: PackedScene) -> String:
	for k in templates.keys():
		if templates[k] == scene:
			return k
	return ""

func info_of_key(key: String) -> RoomTemplateInfo:
	if _info_cache.has(key):
		return _info_cache[key]

	var scene: PackedScene = templates.get(key, null)
	if scene == null:
		return null

	var info: RoomTemplateInfo = _build_info(key, scene)
	_info_cache[key] = info
	return info

func info_of_scene(scene: PackedScene) -> RoomTemplateInfo:
	if scene == null:
		return null
	var key := key_of_scene(scene)
	if key == "":
		return null
	return info_of_key(key)

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

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

func _load_templates_from_dir(path: String) -> Dictionary[String, PackedScene]:
	var out: Dictionary[String, PackedScene] = {}
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("RoomTemplateCatalog: impossibile aprire dir: %s" % path)
		return out

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "tscn":
			var full_path := path.path_join(file_name)
			out[file_name.get_basename().to_upper()] = load(full_path)
		file_name = dir.get_next()

	return out

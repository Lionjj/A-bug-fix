extends Node
class_name RoomAssembler

@export var vertical_ratio: float = 0.35  # 35% di nodi verticali

const PATH : String = "res://PCG/scenes/rooms/tmpl"
const KIND_RULES :Dictionary= {
	"HUB":       {"require_tags_any": ["hub"],       "allow_kinds": ["ARENA"]},
	"CHALLENGE": {"require_tags_any": ["challenge","gap","shaft"]},
	"KEY_ROOM":  {"require_tags_any": ["key","ability","upgrade"]},
	"SAVE":      {"require_tags_any": ["save"]},
	"SIDE":      {"require_tags_any": ["side","optional"]}
}

const DIVERSITY_WINDOW := 6
const DIVERSITY_PENALTY := 0.25
const DIFF_SIGMA := 1.6					# smoothing difficoltà (più alto = più morbido)

const DIRS = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
const DIRS_STR = {Vector2i(1,0):"E", Vector2i(-1,0):"W", Vector2i(0,1):"S", Vector2i(0,-1):"N"}

# Catalogo di template disponibili (riempi da editor o via codice)
var room_scenes : Dictionary[String, PackedScene]

var _meta_cache: Dictionary = {} 		# PackedScene -> meta dict
var _used_counts := {}					# kind_str -> count
var _last_kinds: Array[String] = []		# sliding window per diversità
var _banned_templates: Dictionary[String, bool] = {}	#contiene le stanze che sono bannate (es. per togliere la stanza start dopo la prima inserzione)




func _init() -> void:
	room_scenes = dir_contents(PATH)

# =============== helpers base ===============
func _ban_template(p: PackedScene) -> void:
	for k in room_scenes.keys():
		if room_scenes[k] == p:
			_banned_templates[k] = true
			return

func _finalize_choice(node_data, chosen: PackedScene) -> PackedScene:
	# se è lo START, usa questo template una volta sola e poi bannalo
	if "kind" in node_data and String(node_data.kind) == "START":
		_ban_template(chosen)
	return chosen
	
func _get_meta(ps: PackedScene) -> Dictionary:
	if _meta_cache.has(ps): 
		return _meta_cache[ps]

	var inst := ps.instantiate() as Node2D
	var rm := inst as RoomTemplateMeta
	if rm == null:
		inst.queue_free()
		return {}

	var has_base := false
	var has_tags := false
	for p in rm.get_property_list():
		if String(p.name) == "base_weight": has_base = true
		if String(p.name) == "tags":        has_tags = true

	var base_w: float = 1.0
	if has_base:
		# rm.base_weight è float
		base_w = float(rm.base_weight)

	var tags_arr: Array = []
	if has_tags:
		tags_arr = rm.tags.duplicate()

	var meta := {
		"kind":        rm.kind,						# etichetta della stanza
		"size_tiles":  rm.size_tiles,				# dimensione della stanza
		"requires":    rm.requires.duplicate(),		# abilità richieste per la stanza
		"difficulty":  rm.difficulty,				# difficolta
		"connectors":  rm.connectors.duplicate(),	# connettori della stanza disponibili {"N":bool,"E":bool,"S":bool,"W":bool}
		"base_weight": base_w,						# peso
		"tags":        tags_arr						# 
	}
	_meta_cache[ps] = meta
	inst.queue_free()
	return meta

func _abilities_ok(meta_requires: Array, node_requires: Array, abilities: Array) -> bool:
	for a in meta_requires: if not abilities.has(a): return false
	for a in node_requires: if not abilities.has(a): return false
	return true

func _kind_ok(meta: Dictionary, node_kind: String) -> bool:
	# Se non c'è regola, non vincoliamo (compatibile con il passato)
	if not KIND_RULES.has(node_kind): 
		return true
	var rule :Dictionary= KIND_RULES[node_kind]
	var tags: Array = meta.get("tags", [])
	# allow_kinds: opzionale – utile per far usare ARENA come HUB
	if rule.has("allow_kinds") and not (String(meta["kind"]) in rule["allow_kinds"]):
		# se non è tra i kind consentiti, può comunque passare coi tag
		pass
	# require_tags_any: almeno uno dei tag deve essere presente
	if rule.has("require_tags_any"):
		for t in rule["require_tags_any"]:
			if tags.has(t):
				return true
		# nessun tag richiesto presente: non ok
		return false
	return true

func _tags_match(node_kind: String, tags: Array) -> bool:
	if not KIND_RULES.has(node_kind):
		return false
	var rule: Dictionary = KIND_RULES[node_kind]
	if not rule.has("require_tags_any"):
		return false
	for t in rule["require_tags_any"]:
		if tags.has(t):
			return true
	return false

func _needed_connectors(node_id: String, positions: Dictionary) -> Array:
	var base: Vector2i = positions[node_id]
	var need: Array[String] = []
	var lookup := {}
	for id in positions.keys(): lookup[str(positions[id])] = id
	for d in DIRS:
		if lookup.has(str(base + d)): need.append(DIRS_STR[d])
	return need

func _difficulty_weight(meta_diff: int, node_diff: int) -> float:
	var delta :float= abs(float(meta_diff - node_diff))
	return exp(- (delta * delta) / (2.0 * DIFF_SIGMA * DIFF_SIGMA))
	
func _diversity_factor(kind: String) -> float:
	var repeats := 0
	for k in _last_kinds:
		if k == kind: repeats += 1
	return maxf(0.6, 1.0 - DIVERSITY_PENALTY * repeats)      # mai sotto 0.6
	
func _connectors_coverage(meta_con: Dictionary, need_dirs: Array) -> float:
	if need_dirs.is_empty(): return 1.0
	var have := 0
	for d in need_dirs:
		if meta_con.get(d, false): have += 1
	return float(have) / float(need_dirs.size())             # 0..1

func _weighted_pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var sum := 0.0
	for k in weights.keys(): sum += float(weights[k])
	var r := rng.randf() * sum
	for k in weights.keys():
		r -= float(weights[k])
		if r <= 0.0: return String(k)
	return String(weights.keys()[0])
	
func allowed_dirs_by_kind() -> Dictionary:
	var map := {}  # kind -> {"N":bool,"E":bool,"S":bool,"W":bool}
	for key in room_scenes.keys():
		var meta := _get_meta(room_scenes[key])
		var k := String(meta["kind"])
		if not map.has(k): map[k] = {"N":false,"E":false,"S":false,"W":false}
		for d in ["N","E","S","W"]:
			if meta["connectors"].get(d,false):
				map[k][d] = true
	return map

func dir_contents(path: String) -> Dictionary[String, PackedScene]:
	var scene_loads :Dictionary[String, PackedScene]= {} 	

	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				print("Found directory: " + file_name)
			else:
				if file_name.get_extension() == "tscn":
					var full_path = path.path_join(file_name)
					scene_loads[(file_name.get_basename()).to_upper()] = load(full_path)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")

	return scene_loads

func _align_all_tilemap_layers(room: Node2D) -> void:
	# Alcuni addon TileMapLayer non ereditano il transform: settiamo la position a mano
	var stack := [room]
	while stack.size() > 0:
		var n : Node = stack.pop_back()
		
		for c in n.get_children(): stack.append(c)
		var l := n as TileMapLayer
		
		if l: l.position = room.position

# Ritorna se esiste almeno un template compatibile col nodo/abilità che consenta H (W+E) e/o V (N+S)
func node_axes_caps(node: MissionNode, abilities: Array[Abilities.Ability]) -> Dictionary:
	var can_H := false
	var can_V := false
	for key in room_scenes.keys():
		var ps: PackedScene = room_scenes[key]
		var meta := _get_meta(ps)
		if meta.is_empty(): continue
		# abilità del template + abilità richieste dal nodo
		if not _abilities_ok(meta["requires"], node.requires, abilities):
			continue
		# se esiste ALMENO un template praticabile con W ed E -> orizzontale possibile
		if meta["connectors"].get("W", false) and meta["connectors"].get("E", false):
			can_H = true
		# se esiste ALMENO un template praticabile con N ed S -> verticale possibile
		if meta["connectors"].get("N", false) and meta["connectors"].get("S", false):
			can_V = true
	# esempio: LONG_GAP tipicamente -> {H:true, V:false}; VERTICAL_SHAFT -> {H:false, V:true}; ARENA -> {H:true,V:true}
	return {"H":can_H, "V":can_V}

func _get_room_conn_x_size(meta: RoomTemplateMeta) -> int:
	var out: int = 0
	var openingE: int = 0
	var openingW: int = 0
	
	var connE: RoomTemplateMeta = meta.get_node_or_null("E")
	var connW: RoomTemplateMeta = meta.get_node_or_null("W")

	if connE: openingE += (connE.offset_up + connE.offset_down)
	if connW: openingW += (connW.offset_up + connW.offset_down)
	
	out += max(openingE, openingW)
	return out

func _get_room_conn_y_size(meta: RoomTemplateMeta) -> int:
	var out: int = 0
	var openingN: int = 0
	var openingS: int = 0
	
	var connN: RoomTemplateMeta = meta.get_node_or_null("N")
	var connS: RoomTemplateMeta = meta.get_node_or_null("S")

	if connN: openingN += (connN.offset_up + connN.offset_down)
	if connS: openingS += (connS.offset_up + connS.offset_down)
	
	out += max(openingN, openingS)
	return out
	
# RoomAssembler.gd
func max_room_size_tiles(rooms:Dictionary[String, PackedScene] = room_scenes) -> Vector2i:
	var w := 0
	var h := 0
	var min_offset_x := 0
	var min_offset_y := 0
	for key in rooms.keys():
		var m := _peek_meta(rooms.get(key))
		if m == null: continue
		
		min_offset_x = max(min_offset_x, _get_room_conn_x_size(m))
		min_offset_y = max(min_offset_y, _get_room_conn_y_size(m))
		w = max(w, m.size_tiles.x)
		h = max(h, m.size_tiles.y)
	return Vector2i(w, h)

# =============== Builder ===============

func pick_template(
	node: MissionNode,
	abilities: Array[Abilities.Ability],
	positions: Dictionary,                  # id -> Vector2i (per connettori richiesti)
	rng: RandomNumberGenerator
) -> PackedScene:
	if room_scenes.is_empty():
		push_error("Template non caricati!"); return null

	var need := _needed_connectors(node.id, positions)
	var node_diff := (("diff" in node) and (node.diff if typeof(node.diff)==TYPE_INT else 1))

	# 1) Scoring generico per tutti i template senza conoscere le "categorie"
	var candidates := {}
	for key in room_scenes.keys():
		var ps :PackedScene= room_scenes[key]
		var meta := _get_meta(ps)
		
		if meta.is_empty(): continue
		
		if not _kind_ok(meta, node.kind): continue

		# Gate abilità
		if not _abilities_ok(meta["requires"], node.requires, abilities):
			continue

		# Copertura connettori (preferisci quelli che coprono tutte le direzioni richieste)
		var cover :float= _connectors_coverage(meta["connectors"], need)
		if cover <= 0.0:
			# se proprio zero copertura, scartalo (evita corridoi impossibili)
			continue

		# Difficoltà (gauss)
		var w_diff :float= _difficulty_weight(int(meta["difficulty"]), node_diff)

		# Base weight dichiarato nel template (o 1.0)
		var w_base :float= float(meta["base_weight"])

		# Se il template "usa abilità" (meta.requires non vuoto) e il nodo è CHALLENGE → bonus
		var w_skill :float= (node.kind == "CHALLENGE" and (1.15 if meta["requires"].size() > 0 else 1.0))

		# Tags opzionali: pura semantica *autodichiarata*, non hard-coded
		var w_tags :float= 1.0
		if "tags" in meta:
			var tags: Array = meta["tags"]
			# piccolo esempio generico: se servono N/S e il template “dice” vertical → spintina
			if need.has("N") or need.has("S"):
				if tags.has("vertical"): w_tags *= 1.12
			if need.has("E") or need.has("W"):
				if tags.has("horizontal"): w_tags *= 1.12
			# se il nodo richiede abilità, e il template ha tag “platforming” o “gap”
			if node.requires.size() > 0:
				if tags.has("platforming") or tags.has("gap"): w_tags *= 1.08

		# Diversità (meno spam dello stesso "kind")
		var kind :String= String(meta["kind"])
		var w_div :float= _diversity_factor(kind)

		# Peso finale (tutto neutro e generico)
		var weight :float= w_base * pow(cover, 2.0) * w_diff * w_skill * w_tags * w_div
		# Nota: eleviamo cover^2 così premiamo molto chi copre TUTTI i connettori richiesti

		if weight > 0.0:
			candidates[key] = maxf(0.0001, weight)

	# 2) Fallback morbido se nulla è rimasto (es. per grafi strani)
	if candidates.is_empty():
		for key in room_scenes.keys():
			var ps :PackedScene= room_scenes[key]
			var meta := _get_meta(ps)
			if meta.is_empty(): continue
			if not _abilities_ok(meta["requires"], node.requires, abilities): continue
			candidates[key] = 0.5  # tutto uguale, ma abilità rispettate

	if candidates.is_empty():
		return room_scenes.values()[0] # estremo fallback

	# 3) Weighted pick
	var chosen_key := _weighted_pick(candidates, rng)
	var chosen_ps :PackedScene= room_scenes[chosen_key]

	# book-keeping per diversità
	var chosen_kind := String(_get_meta(chosen_ps)["kind"])
	_used_counts[chosen_kind] = int(_used_counts.get(chosen_kind, 0)) + 1
	_last_kinds.append(chosen_kind)
	if _last_kinds.size() > DIVERSITY_WINDOW:
		_last_kinds.pop_front()

	return chosen_ps
	
func instantiate_room(
		packed: PackedScene,
		grid_pos: Vector2i,
		tile_size := Vector2i(16,16),
		grid_cell_tiles := Vector2i(80,48)  # <<< cella canonica
) -> RoomTemplateMeta:
	var room := packed.instantiate() as RoomTemplateMeta

	# leggi size_tiles dal meta della stanza
	var sz := room.size_tiles if room else grid_cell_tiles

	# offset per centrare la stanza dentro la cella
	var off_tiles := Vector2(
		(grid_cell_tiles.x - sz.x),
		(grid_cell_tiles.y - sz.y)
	)

	var cell_px := Vector2(grid_cell_tiles.x * tile_size.x, grid_cell_tiles.y * tile_size.y)
	var off_px  := Vector2(off_tiles.x * tile_size.x, off_tiles.y * tile_size.y)

	room.position = Vector2(
		grid_pos.x * cell_px.x,
		grid_pos.y * cell_px.y
	) + off_px

	_align_all_tilemap_layers(room)
	
	return room

# Rileva se un meta è H-only, V-only, Omni
func _axes_kind_from_meta(meta: Dictionary) -> String:
	var c :Dictionary= meta["connectors"]
	var H :bool= c.get("W", false) and c.get("E", false)
	var V :bool= c.get("N", false) and c.get("S", false)
	if H and V: return "OMNI"
	if H and not V: return "H"
	if V and not H: return "V"
	return "NONE"

func caps_decide_for_node(node: MissionNode, abilities: Array[Abilities.Ability], rng: RandomNumberGenerator) -> Dictionary:
	var hasH := false
	var hasV := false
	
	for key in room_scenes.keys():
		var meta := _get_meta(room_scenes[key])
		if meta.is_empty(): continue
		
		if not _abilities_ok(meta["requires"], node.requires, abilities): continue
		
		var c: Dictionary = meta["connectors"]
		hasH = hasH or (c.get("W", false) and c.get("E", false))
		hasV = hasV or (c.get("N", false) and c.get("S", false))
		if hasH and hasV: break

	if hasH and not hasV: return {"H": true,  "V": false}
	if hasV and not hasH: return {"H": false, "V": true}
	if not hasH and not hasV:  return {"H": true,  "V": true}  # nessun vincolo

	# Qui hai both true: scegli in base al ratio
	return {"H": false, "V": true} if (rng.randf() < vertical_ratio) else {"H": true, "V": false}

func caps_decide_for_graph(G: MissionGraph, abilities: Array[Abilities.Ability], rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for id in G.nodes.keys():
		out[id] = caps_decide_for_node(G.nodes[id], abilities, rng)
	return out

func caps_available_for_graph(G: MissionGraph, abilities: Array[Abilities.Ability], rng:RandomNumberGenerator) -> Dictionary:
	var out := {}
	for id in G.nodes.keys():
		out[id] = caps_decide_for_node(G.nodes[id], abilities, rng)
	return out

# -------- API nuova: scelta template con connettori richiesti --------
func pick_template_with_requirements(
		node_data,                      # MissionNode o simile (deve avere .kind e .requires)
		abil_here: Array,
		positions: Dictionary,
		rng: RandomNumberGenerator,
		req: Dictionary                 # {"N":bool,"E":bool,"S":bool,"W":bool}
) -> PackedScene:
	var candidates := _candidates_for(node_data, abil_here)
	if candidates.is_empty():
		push_warning("RoomAssembler: nessun candidato dopo il filtro abilità.")
		return null

	# prendiamo il kind del nodo dal dato
	var node_kind := ""
	if "kind" in node_data:
		node_kind = String(node_data.kind)

	# allow_kinds da KIND_RULES, se esistono (es. HUB -> ARENA)
	var rule: Dictionary = KIND_RULES.get(node_kind, {})
	var allow_kinds: Array = []
	if rule.has("allow_kinds"):
		allow_kinds = rule["allow_kinds"]

	# ---------- 1) MATCH ESATTO CON REQ ----------
	var exact_kind: Array[PackedScene] = []
	var exact_tags: Array[PackedScene] = []
	var exact_any:  Array[PackedScene] = []

	for p in candidates:
		var meta := _peek_meta(p)
		if meta == null:
			continue
		if not _satisfies(meta.connectors, req):
			continue

		var meta_kind: String = String(meta.kind)
		var tags_arr: Array = meta.tags

		var strong_match := (meta_kind == node_kind) or allow_kinds.has(meta_kind)
		var tag_match := _tags_match(node_kind, tags_arr)

		if strong_match:
			exact_kind.append(p)
		elif tag_match:
			exact_tags.append(p)
		else:
			exact_any.append(p)

	# priorità: kind -> tag -> any
	if exact_kind.size() > 0:
		var chosen = exact_kind[rng.randi() % exact_kind.size()]
		return _finalize_choice(node_data, chosen)
	if exact_tags.size() > 0:
		var chosen = exact_tags[rng.randi() % exact_tags.size()]
		return _finalize_choice(node_data, chosen)
	if exact_any.size() > 0:
		var chosen = exact_any[rng.randi() % exact_any.size()]
		return _finalize_choice(node_data, chosen)

	# ---------- 2) FALLBACK RELAXED (asse coerente) ----------
	var relax_kind: Array[PackedScene] = []
	var relax_tags: Array[PackedScene] = []
	var relax_any:  Array[PackedScene] = []
#
	for p in candidates:
		var meta := _peek_meta(p)
		if meta == null:
			continue
		if not _relaxed_satisfies(meta.connectors, req):
			continue

		var meta_kind: String = String(meta.kind)
		var tags_arr: Array = meta.tags

		var strong_match := (meta_kind == node_kind) or allow_kinds.has(meta_kind)
		var tag_match := _tags_match(node_kind, tags_arr)

		if strong_match:
			relax_kind.append(p)
		elif tag_match:
			relax_tags.append(p)
		else:
			relax_any.append(p)

	if relax_kind.size() > 0:
		var chosen = relax_kind[rng.randi() % relax_kind.size()]
		return _finalize_choice(node_data, chosen)
	if relax_tags.size() > 0:
		var chosen = relax_tags[rng.randi() % relax_tags.size()]
		return _finalize_choice(node_data, chosen)
	if relax_any.size() > 0:
		var chosen = relax_any[rng.randi() % relax_any.size()]
		return _finalize_choice(node_data, chosen)

	# ---------- 3) ULTIMO FALLBACK: QUALSIASI CANDIDATO ----------
	if candidates.size() > 0:
		var chosen = candidates[rng.randi() % candidates.size()]
		return _finalize_choice(node_data, chosen)

	push_warning("RoomAssembler: nessun candidate template disponibile; usa un placeholder.")
	return null


# -------- Helpers di filtro --------
func _candidates_for(node_data, abil_here: Array) -> Array[PackedScene]:
	var pool: Dictionary[String, PackedScene] = room_scenes.duplicate()
	var out: Array[PackedScene] = []

	for key in pool.keys():
		# se è bannato, salta
		if _banned_templates.get(key, false):
			continue

		var meta := _peek_meta(pool.get(key))
		if meta == null:
			continue

		var ok :bool = true
		for need in meta.requires:
			if not abil_here.has(need):
				ok = false
				break

		if ok:
			out.append(pool.get(key))

	return out

func _satisfies(conn: Dictionary, req: Dictionary) -> bool:
	var corrisponding : Dictionary = {
		"N":"S", 
		"E":"W",
		"S":"N",
		"W":"E"
	}
	for key in corrisponding.keys():
		var opposite: String = corrisponding.get(key, false)
		if bool(req.get(key, false)) and not bool(conn.get(opposite, false)):
			return false
	return true

func _relaxed_satisfies(conn: Dictionary, req: Dictionary) -> bool:
	var need_h := bool(req.get("E",false)) or bool(req.get("W",false))
	var need_v := bool(req.get("N",false)) or bool(req.get("S",false))
	if need_h and not (bool(conn.get("E",false)) or bool(conn.get("W",false))):
		return false
	if need_v and not (bool(conn.get("N",false)) or bool(conn.get("S",false))):
		return false
	return true

# -------- Lettura “leggera” dei meta dai PackedScene --------
func _peek_meta(p: PackedScene) -> RoomTemplateMeta:
	if p == null:
		return null
	# Istanzia “in memoria” e cerca il meta nel root o nei figli
	var inst := p.instantiate()
	if inst == null:
		return null

	var meta := inst as RoomTemplateMeta
	if meta == null:
		# prova a cercarlo nei figli (root empty wrapper, ecc.)
		meta = inst.get_node_or_null(".") as RoomTemplateMeta
		if meta == null:
			# ricerca profonda, costo accettabile dato che è solo in fase di build
			meta = inst.find_child("",
				true,        # owned
				false        # search by regex name? false
			) as RoomTemplateMeta
	inst.queue_free()
	return meta

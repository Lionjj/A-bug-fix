extends Node
class_name GridPlacer

var pos: Dictionary = {}  # id:String -> Vector2i

@export var prefer_vertical: float = 0.0  # -1=orizzontale, 0=neutro, +1=verticale
@export var ring_max_radius: int = 3

const DIR_VECT := {
	"N": Vector2i(0, -1),
	"E": Vector2i(1, 0),
	"S": Vector2i(0, 1),
	"W": Vector2i(-1, 0),
}

const OPP := { "N":"S", "S":"N", "E":"W", "W":"E" }


func place(G: MissionGraph, rng: RandomNumberGenerator, caps: Dictionary, conns: Dictionary) -> Dictionary:
	pos.clear()

	# Normalizza e ripara caps PRIMA
	caps = _validate_and_fix_caps(G, caps, true)
	var caps_norm: Dictionary = {}
	for k in caps.keys():
		caps_norm[String(k)] = caps[k]
	caps = caps_norm

	var start: String = String(G.start_id)
	pos[start] = Vector2i(0, 0)
	var used: Dictionary = { Vector2i(0, 0) : true }

	# --- CODA DI ARCHI (genitore->figlio) ---
	var edge_q: Array = []
	var retries: Dictionary = {}  # chiave "u->v" -> int

	# seed iniziale
	for v_any in G.neighbors(start):
		edge_q.append({"u": start, "v": String(v_any)})

	while edge_q.size() > 0:
		var e :Dictionary= edge_q.pop_front()
		var u: String = e["u"]
		var v: String = e["v"]

		if not pos.has(u):
			push_warning("Edge with parent not placed: %s -> %s" % [u, v])
			continue
		if pos.has(v):
			# già piazzato: espandi i suoi figli
			for w_any in G.neighbors(v):
				var w := String(w_any)
				if not pos.has(w):
					edge_q.append({"u": v, "v": w})
			continue

		var base_pos: Vector2i = pos[u]
		var picked: Variant = _pick_adjacent(base_pos, used, caps, u, v, rng, false, conns)

		if picked == null:
			var key := "%s->%s" % [u, v]
			retries[key] = int(retries.get(key, 0)) + 1

			# al 3º e 6º tentativo, concedi allow_gaps (anelli)
			if retries[key] == 3 or retries[key] == 6:
				picked = _pick_adjacent(base_pos, used, caps, u, v, rng, true, conns)

			if picked == null:
				if retries[key] <= 10:
					edge_q.append(e)  # riprova più avanti
				else:
					push_warning("Unable to place %s compatibly from %s after many retries; skipping." % [v, u])
				continue

		# piazza v
		var pv: Vector2i = picked as Vector2i
		pos[v] = pv
		used[pv] = true

		# espandi i figli di v
		for w_any in G.neighbors(v):
			var w := String(w_any)
			if not pos.has(w):
				edge_q.append({"u": v, "v": w})

	return pos


func _pick_adjacent(
	base: Vector2i,
	used: Dictionary,
	caps: Dictionary,
	u_id: String,
	v_id: String,
	rng: RandomNumberGenerator,
	allow_gaps := false,
	conns: Dictionary = {}
) -> Variant:
	# 1) connettori della stanza di partenza (u) e della candidata (v)
	var conn_u := _get_connectors(conns, caps, u_id)
	var conn_v := _get_connectors(conns, caps, v_id)
	prints("PICK", u_id, "->", v_id, "conn_u", conn_u, "conn_v", conn_v, "base", base)

	# 2) ordina le direzioni da provare in base ai connettori di u (+ bias)
	var dir_syms := _ordered_dirs_for_room(conn_u)

	# 3) adiacenze (Manhattan 1) vincolate dai connettori
	var candidates: Array[Vector2i] = []
	for d_sym in dir_syms:
		var d_vec :Vector2i= DIR_VECT[d_sym]
		var p := base + d_vec
		if used.has(p): continue
		# v deve avere il connettore opposto
		if not conn_v.get(OPP[d_sym], false): continue
		
		# opzionale: tieni anche il tuo controllo H/V se vuoi doppio vincolo
		if not _dir_allowed_strict(d_vec, caps, u_id, v_id): continue
		candidates.append(p)

	if candidates.size() > 0:
		return candidates[rng.randi_range(0, candidates.size() - 1)]

	# 4) fallback: anelli (se consentito)
	if not allow_gaps:
		return null

	for r in range(2, ring_max_radius + 1):
		# perimetro a diamante, mescolato
		var ring := _diamond_perimeter(base, r)
		_shuffle_in_place(ring, rng)
		for p in ring:
			if used.has(p): continue
			var d := p - base
			# ammetti solo spostamenti puramente H o V
			var d_sym2 := ("E" if d.x > 0 else "W") if (abs(d.x) > abs(d.y)) else ("S" if d.y > 0 else "N")
			# vincolo connettori: u deve poter uscire in d_sym2, v deve avere OPP
			if not conn_u.get(d_sym2, false): continue
			if not conn_v.get(OPP[d_sym2], false): continue
			# opzionale: anche caps H/V
			if not _dir_allowed_strict(DIR_VECT[d_sym2], caps, u_id, v_id): continue
			return p

	return null

# --- helpers caps/assi ---

# conns: Dictionary(id -> {"N":bool,"E":bool,"S":bool,"W":bool})
func _get_connectors(conns: Dictionary, caps: Dictionary, who) -> Dictionary:
	var id := String(who)
	var cdir = conns.get(id)
	if typeof(cdir) == TYPE_DICTIONARY:
		return {
			"N": bool(cdir.get("N", false)),
			"E": bool(cdir.get("E", false)),
			"S": bool(cdir.get("S", false)),
			"W": bool(cdir.get("W", false)),
		}
	# fallback da caps, o omni
	var cap := _get_caps(caps, id)
	return _connectors_from_caps(cap)

func _connectors_from_caps(c: Dictionary) -> Dictionary:
	# H:true -> E/W disponibili; V:true -> N/S disponibili
	var has_h = c.get("H", true)
	var has_v = c.get("V", true)
	return {
		"N": has_v, "S": has_v,
		"E": has_h, "W": has_h
	}

func _ordered_dirs_for_room(conn_u: Dictionary) -> Array[String]:
	var h_av :bool= conn_u.get("E", false) or conn_u.get("W", false)
	var v_av :bool= conn_u.get("N", false) or conn_u.get("S", false)

	# base order per bias
	var bias_dirs : Array[String]
	if prefer_vertical > 0.2:
		bias_dirs = ["S","N","E","W"]
	elif prefer_vertical < -0.2:
		bias_dirs = ["E","W","S","N"]
	else:
		bias_dirs = ["E","W","S","N"]

	# filtra per connettori realmente presenti su u
	var out : Array[String] = []
	for d in bias_dirs:
		if conn_u.get(d, false):
			out.append(d)
	return out

# Genera l’intero perimetro manhattan (a rombo) di r: 
# {(x,y): |x|+|y| = r} traslato su 'base'
func _diamond_perimeter(base: Vector2i, r: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in range(-r, r + 1):
		var dy :int= r - abs(dx)
		out.append(base + Vector2i(dx, +dy))
		if dy != 0:
			out.append(base + Vector2i(dx, -dy))
	return out


func _shuffle_in_place(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _norm_id(x) -> String:
	return String(x)

func _get_caps(caps: Dictionary, who) -> Dictionary:
	if caps == null:
		return {"H": true, "V": true}
	var k: String = _norm_id(who)
	var c = caps.get(k)
	if typeof(c) == TYPE_DICTIONARY:
		var d := c as Dictionary
		# default permissivi (se manca un flag -> true)
		return {"H": bool(d.get("H", true)), "V": bool(d.get("V", true))}
	# se non c'è entry per quel nodo -> omni
	return {"H": true, "V": true}

func _dir_allowed_strict(d: Vector2i, caps: Dictionary, u_id, v_id) -> bool:
	var is_h := d.y == 0 and d.x != 0
	var is_v := d.x == 0 and d.y != 0
	if not (is_h or is_v):
		return false

	var cu := _get_caps(caps, u_id)
	var cv := _get_caps(caps, v_id)

	if is_h and (not cu.get("H", true) or not cv.get("H", true)): 
		push_warning("H reject: %s(H=%s) -> %s(H=%s)" % [u_id, cu.get("H", true), v_id, cv.get("H", true)])
		return false
	if is_v and (not cu.get("V", true) or not cv.get("V", true)): 
		push_warning("V reject: %s(V=%s) -> %s(V=%s)" % [u_id, cu.get("V", true), v_id, cv.get("V", true)])
		return false
	return true

func _normalize_caps(caps: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in caps.keys():
		var key := String(k)
		var c = caps[k]
		if typeof(c) == TYPE_DICTIONARY:
			out[key] = {
				"H": bool((c as Dictionary).get("H", true)),
				"V": bool((c as Dictionary).get("V", true))
			}
		else:
			out[key] = {"H": true, "V": true}
	return out

# policy:
#   "none"  -> solo avvisi
#   "promote_child_to_parent" -> rende il figlio compatibile col genitore (se U è H-only, dà H al figlio; se U è V-only, dà V al figlio)
#   "both_omni" -> rende entrambi omni (molto permissivo)
func _validate_and_fix_caps(G: MissionGraph, caps: Dictionary, start_omni := true, policy := "promote_child_to_parent") -> Dictionary:
	caps = _normalize_caps(caps)

	# Start omni (evita la gran parte dei conflitti iniziali)
	var s := String(G.start_id)
	if start_omni:
		var c = caps.get(s, {"H": true, "V": true})
		c["H"] = true; c["V"] = true
		caps[s] = c

	# Controlla gli archi del grafo
	for u_any in G.nodes.keys():  # se non hai G.nodes, itera su tutte le chiavi che usi come id
		var u := String(u_any)
		var cu = caps.get(u, {"H": true, "V": true})

		for v_any in G.neighbors(u):
			var v := String(v_any)
			var cv = caps.get(v, {"H": true, "V": true})

			var share = (cu.get("H",false) and cv.get("H",false)) or (cu.get("V",false) and cv.get("V",false))
			if share:
				continue

			# Conflitto: applica la policy scelta
			match policy:
				"promote_child_to_parent":
					if cu.get("H",false) and not cu.get("V",false):
						cv["H"] = true
					elif cu.get("V",false) and not cu.get("H",false):
						cv["V"] = true
					else:
						# se U è omni o non-caso, fai unione semplice
						cv["H"] = cv.get("H",false) or cu.get("H",false)
						cv["V"] = cv.get("V",false) or cu.get("V",false)
					caps[v] = cv

				"both_omni":
					caps[u] = {"H": true, "V": true}
					caps[v] = {"H": true, "V": true}

				"none":
					push_warning("Caps conflict %s <-> %s (cu=%s, cv=%s). Fix manually." % [u, v, str(cu), str(cv)])
				_:
					push_warning("Unknown caps policy: %s" % policy)

	return caps

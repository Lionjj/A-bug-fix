extends Node
class_name BTPlacer
# Backtracking, connector-aware, con forward-check

@export var prefer_vertical: float = 0.0   # -1=orizz, 0=neutro, +1=vert
@export var allow_gaps: bool = false       # per mappe sempre connesse: false

var pos: Dictionary = {}                   # id -> Vector2i
var used: Dictionary = {}                  # Vector2i -> true
var caps_norm: Dictionary                  # id -> {H,V}
var conns_norm: Dictionary                 # id -> {N,E,S,W}

const DIR_VECT := {
	"N": Vector2i(0, -1),
	"E": Vector2i(1, 0),
	"S": Vector2i(0, 1),
	"W": Vector2i(-1, 0),
}
const OPP := {"N":"S","S":"N","E":"W","W":"E"}

# ---------- API ----------
func place(G: MissionGraph, rng: RandomNumberGenerator, caps: Dictionary, conns: Dictionary) -> Dictionary:
	pos.clear(); used.clear()
	caps_norm = _normalize_caps(caps)
	conns_norm = _normalize_conns(conns, caps_norm)

	var start := String(G.start_id)
	pos[start] = Vector2i(0,0)
	used[Vector2i(0,0)] = true

	# frontier = archi (u->v) da soddisfare
	var frontier: Array = []
	for v_any in G.neighbors(start):
		frontier.append({"u": start, "v": String(v_any)})

	# Sanity: assicurati che almeno un arco abbia mosse legali
	var any_legal := false
	for e in frontier:
		var u := String(e["u"]); var v := String(e["v"])
		if not pos.has(u) or pos.has(v): continue
		var leg := _legal_positions_for(u, v, pos[u], rng)
		if not leg.is_empty():
			any_legal = true
			break
	if not any_legal:
		push_warning("Frontier has NO legal moves. Check caps/conns coherence for S and its children.")

	
	_bt(G, rng, frontier)
	return pos

# ---------- Backtracking core ----------
func _bt(G: MissionGraph, rng: RandomNumberGenerator, frontier: Array) -> bool:
	# terminazione: tutto soddisfatto
	var any_pending := false
	for e in frontier:
		if not pos.has(String(e["v"])):
			any_pending = true
			break
	if not any_pending:
		return true

	# MRV: scegli l'arco con meno posizioni legali
	var pick_i := -1
	var best_legal: Array = []
	var best_count := 1_000_000

	for i in range(frontier.size()):
		var e = frontier[i]
		var u := String(e["u"]); var v := String(e["v"])
		if not pos.has(u) or pos.has(v):
			continue
		var leg := _legal_positions_for(u, v, pos[u], rng)
		var c := leg.size()
		if c == 0: continue
		if c < best_count:
			best_count = c
			best_legal = leg
			pick_i = i
			if c == 1: break

	if pick_i == -1:
		return false

	# chiamata (nel backtracking), aggiungi rng e ids:
	_sort_candidates_in_place(best_legal, pos[String(frontier[pick_i]["u"])], String(frontier[pick_i]["u"]), String(frontier[pick_i]["v"]), rng)

	# prova le posizioni
	var e_pick = frontier[pick_i]
	frontier.remove_at(pick_i)
	var u := String(e_pick["u"])
	var v := String(e_pick["v"])

	for p in best_legal:
		# place
		pos[v] = p; used[p] = true

		# espandi frontier con i figli di v
		var adds: Array = []
		for w_any in G.neighbors(v):
			var w := String(w_any)
			if pos.has(w): continue
			var edge = {"u": v, "v": w}
			frontier.append(edge)
			adds.append(edge)

		# forward check: ogni (v->x) deve avere almeno 1 mossa legale
		var consistent := true
		for e2 in frontier:
			if String(e2["u"]) != v: continue
			var x := String(e2["v"])
			if pos.has(x): continue
			if _legal_positions_for(v, x, pos[v], rng).is_empty():
				consistent = false; break

		if consistent and _bt(G, rng, frontier):
			return true

		# undo
		for _a in adds: frontier.pop_back()
		used.erase(p); pos.erase(v)

	# rimetti l'arco e fallisci
	frontier.insert(pick_i, e_pick)
	return false

# ---------- Legal moves ----------
func _legal_positions_for(u_id: String, v_id: String, base: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var conn_u := _get_conns(u_id)
	var conn_v := _get_conns(v_id)
	var cu := _get_caps(u_id)
	var cv := _get_caps(v_id)

	var dir_syms := _ordered_dirs(conn_u, rng)

	# se v è H-only o V-only, filtra
	var v_has_h :bool= conn_v.get("E", false) or conn_v.get("W", false)
	var v_has_v :bool= conn_v.get("N", false) or conn_v.get("S", false)
	if v_has_h and not v_has_v:
		dir_syms = dir_syms.filter(func(d): return d == "E" or d == "W")
	elif v_has_v and not v_has_h:
		dir_syms = dir_syms.filter(func(d): return d == "N" or d == "S")

	var out: Array[Vector2i] = []

	# --- DEBUG: stampa la situazione di partenza
	prints("LEGAL?", u_id, "->", v_id, "base", base, "dir_syms", dir_syms, "conn_u", conn_u, "conn_v", conn_v, "caps_u", cu, "caps_v", cv)

	for d_sym in dir_syms:
		var p :Vector2i= base + DIR_VECT[d_sym]
		if used.has(p):
			prints("  REJECT", d_sym, "used", p)
			continue
		if not conn_v.get(OPP[d_sym], false):
			prints("  REJECT", d_sym, "v missing", OPP[d_sym])
			continue
		if not _caps_allow(d_sym, u_id, v_id):
			prints("  REJECT", d_sym, "caps forbid (cu=", cu, "cv=", cv, ")")
			continue

		prints("  ACCEPT", d_sym, "->", p)
		out.append(p)

	# fallback opzionale con gap
	if allow_gaps and out.is_empty():
		for r in range(2, 4):
			for d_sym in dir_syms:
				var p2 :Vector2i= base + DIR_VECT[d_sym] * r
				if used.has(p2): continue
				if not conn_v.get(OPP[d_sym], false): continue
				if not _caps_allow(d_sym, u_id, v_id): continue
				prints("  ACCEPT_GAP r=", r, d_sym, "->", p2)
				out.append(p2)
			if not out.is_empty():
				break

	if out.is_empty():
		prints("NO_LEGAL_MOVES", u_id, "->", v_id)
		
	if out.is_empty():
	# hard fallback adiacente (mai verticale se non possibile)
		if conn_u.get("E", false) and conn_v.get("W", false) and _caps_allow("E", u_id, v_id) and not used.has(base + DIR_VECT["E"]):
			return [base + DIR_VECT["E"]]
		if conn_u.get("W", false) and conn_v.get("E", false) and _caps_allow("W", u_id, v_id) and not used.has(base + DIR_VECT["W"]):
			return [base + DIR_VECT["W"]]


	return out

# ---------- Helpers ----------
func _normalize_caps(caps: Dictionary) -> Dictionary:
	var out := {}
	for k in caps.keys():
		var key := String(k)
		var d = caps[k] as Dictionary
		out[key] = {"H": bool(d.get("H", true)), "V": bool(d.get("V", true))}
	return out

func _normalize_conns(conns: Dictionary, caps_fb: Dictionary) -> Dictionary:
	var out := {}
	for k in caps_fb.keys():
		var key := String(k)
		if conns.has(key) and typeof(conns[key]) == TYPE_DICTIONARY:
			var cdir := conns[key] as Dictionary
			out[key] = {
				"N": bool(cdir.get("N", false)),
				"E": bool(cdir.get("E", false)),
				"S": bool(cdir.get("S", false)),
				"W": bool(cdir.get("W", false)),
			}
		else:
			var c = caps_fb[key]
			var h := bool(c.get("H", true)); var v := bool(c.get("V", true))
			out[key] = {"N": v, "E": h, "S": v, "W": h}
	return out

func _get_caps(id: String) -> Dictionary:
	return caps_norm.get(id, {"H":true,"V":true})

func _get_conns(id: String) -> Dictionary:
	return conns_norm.get(id, {"N":true,"E":true,"S":true,"W":true})

func _shuffle_in_place(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _ordered_dirs(conn_u: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
	var h: Array[String] = []; var v: Array[String] = []
	# parti dal bias grossolano
	var bias := ["E","W","S","N"]
	if prefer_vertical > 0.2: bias = ["S","N","E","W"]
	elif prefer_vertical < -0.2: bias = ["E","W","S","N"]

	# filtra per i connettori realmente presenti e separa per asse
	for d in bias:
		if not conn_u.get(d, false): continue
		if d == "E" or d == "W": h.append(d) 
		else: v.append(d)

	# mescola dentro i gruppi per varietà
	_shuffle_in_place(h, rng)
	_shuffle_in_place(v, rng)

	# asse preferito davanti
	if prefer_vertical > 0.2:
		return v + h
	elif prefer_vertical < -0.2:
		return h + v
	else:
		# neutro: 50/50 quale asse davanti
		return (h + v) if (rng.randf() < 0.5) else (v + h)

func _caps_allow(d_sym: String, u_id: String, v_id: String) -> bool:
	var cu := _get_caps(u_id); var cv := _get_caps(v_id)
	if d_sym == "E" or d_sym == "W":
		var ok := bool(cu.get("H", true)) and bool(cv.get("H", true))
		if not ok: prints("CAPS_BLOCK H", u_id, "->", v_id, "cu", cu, "cv", cv)
		return ok
	else:
		var ok := bool(cu.get("V", true)) and bool(cv.get("V", true))
		if not ok: prints("CAPS_BLOCK V", u_id, "->", v_id, "cu", cu, "cv", cv)
		return ok


func _sort_candidates_in_place(cands: Array, base: Vector2i, u_id: String, v_id: String, rng: RandomNumberGenerator) -> void:
	# preferisci l’asse che v *può* offrire (se è “only”), poi shuffle
	var conn_v := _get_conns(v_id)
	var want_h :bool= (conn_v.get("E",false) or conn_v.get("W",false)) and not (conn_v.get("N",false) or conn_v.get("S",false))
	var want_v :bool= (conn_v.get("N",false) or conn_v.get("S",false)) and not (conn_v.get("E",false) or conn_v.get("W",false))

	var group_good: Array = []
	var group_other: Array = []

	for p in cands:
		var d :Vector2i= p - base
		var is_h := d.y == 0 and d.x != 0
		if (want_h and is_h) or (want_v and not is_h):
			group_good.append(p)
		else:
			group_other.append(p)

	# tie-break: distanza minima prima, ma shuffle dentro pari
	var sort_by_dist = func(a, b):
		var da :int= abs(a.x - base.x) + abs(a.y - base.y)
		var db :int= abs(b.x - base.x) + abs(b.y - base.y)
		return da < db

	group_good.sort_custom(sort_by_dist)
	group_other.sort_custom(sort_by_dist)

	_shuffle_in_place(group_good, rng)
	_shuffle_in_place(group_other, rng)

	cands.clear()
	for p in group_good: cands.append(p)
	for p in group_other: cands.append(p)


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

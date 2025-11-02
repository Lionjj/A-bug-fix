extends Node
class_name GraphGrammar
var rules := []

func load_rules(path:String) -> void:
	rules = JSON.parse_string(FileAccess.get_file_as_string(path))["rules"]

func _match(n:MissionNode, cond:Dictionary) -> bool:
	return (not cond.has("kind")) or (n.kind == cond["kind"])

func expand(G:MissionGraph, budget:int) -> void:
	while G.node_count() < budget:
		var candidates := []
		for id in G.nodes.keys():
			for r in rules:
				if _match(G.nodes[id], r.get("match", {})):
					candidates.append({"id":id,"rule":r})
		if candidates.is_empty(): break
		var pick = Rng.choice(candidates)
		_apply_rule(G, pick["id"], pick["rule"])

static func _apply_rule(G: MissionGraph, target_id: String, r: Dictionary) -> void:
	# 1) salva IN e OUT del nodo target
	var old_out: Array[String] = G.neighbors(target_id)
	var old_in: Array[String] = []
	for u in G.nodes.keys():
		if G.neighbors(u).has(target_id):
			old_in.append(u)

	# 2) crea nuovi nodi e mappa id locali -> globali
	var id_map: Dictionary[String, String] = {}

	# r["expand_nodes"] è Array[Variant] -> cast a Dictionary
	var expand_nodes: Array = r["expand_nodes"]
	for spec_v in expand_nodes:
		var spec: Dictionary = spec_v as Dictionary

		var local_id: String = String(spec["id"])
		var nid: String = "%s_%s_%d" % [target_id, local_id, int(Rng.randi() % 10000)]

		var kind: String = String(spec.get("kind", "CHALLENGE"))
		var n := MissionNode.new(nid, kind)

		# grants / requires sono Array[Variant] nel JSON -> castele a String e mappa in enum
		if spec.has("grants"):
			var gs: Array = spec["grants"]
			for g_v in gs:
				var g_name: String = String(g_v)
				n.grants.append(Abilities.Ability[g_name])
		if spec.has("requires"):
			var rs: Array = spec["requires"]
			for r_v in rs:
				var r_name: String = String(r_v)
				n.requires.append(Abilities.Ability[r_name])

		G.add_node(n)
		id_map[local_id] = nid
	# 3) archi interni
	var expand_edges: Array = r["expand_edges"]  # Array[Variant] di coppie
	for e_v in expand_edges:
		var e: Array = e_v as Array
		var a_local: String = String(e[0])
		var b_local: String = String(e[1])
		G.add_edge(id_map[a_local], id_map[b_local])

	# 4) punti di attacco (entry/exit) – tipizzati
	var entry_local: String
	var exit_local:  String

	if r.has("attach_entry"):
		entry_local = String(r["attach_entry"])
	else:
		entry_local = String( (expand_nodes[0] as Dictionary)["id"] )

	if r.has("attach_exit"):
		exit_local = String(r["attach_exit"])
	else:
		exit_local = String( (expand_nodes.back() as Dictionary)["id"] )

	var entry_id: String = id_map[entry_local]
	var exit_id:  String = id_map[exit_local]

	# 5) ricollega IN: u -> target  diventa  u -> entry
	for u in old_in:
		var outs: Array[String] = G.edges[u]
		outs.erase(target_id)
		G.add_edge(u, entry_id)

	# 6) ricollega OUT: target -> v  diventa  exit -> v
	for v in old_out:
		G.add_edge(exit_id, v)

	# 7) disattiva/elimina il vecchio nodo target
	G.nodes[target_id].kind = "SIDE"
	G.edges.erase(target_id)  # opzionale: niente più uscite dal vecchio nodo

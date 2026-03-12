class_name ProgressionAnnotator
extends RefCounted


static func annotate(graph: MissionGraph, initial_abilities: Array) -> void:
	
	# reset annotazioni
	for n: MissionNode in graph.nodes.values():
		n.logical_abilities_before = []
	
	var q := []
	var visited := {}
	
	q.append({
		"id": graph.start_id,
		"abilities": initial_abilities.duplicate()
	})
	
	while q.size() > 0:
		
		var state = q.pop_front()
		var id: String = state["id"]
		var abilities: Array = state["abilities"].duplicate()
		
		var key = id + "|" + str(abilities)
		if visited.has(key):
			continue
		visited[key] = true
		
		var node: MissionNode = graph.nodes[id]
		
		# --- CHECK REQUIRES ---
		var blocked := false
		for r in node.requires:
			if not abilities.has(r):
				blocked = true
				break
		
		if blocked:
			continue
		
		# --- ANNOTAZIONE ---
		# Caso 1: mai annotato prima
		if node.logical_abilities_before.is_empty():
			node.logical_abilities_before = abilities.duplicate()
		
		# Caso 2: nodo gated e ora ho più abilità
		elif node.requires.size() > 0 \
		and abilities.size() > node.logical_abilities_before.size():
			node.logical_abilities_before = abilities.duplicate()
		
		# --- GRANTS ---
		for g in node.grants:
			if not abilities.has(g):
				abilities.append(g)
		
		# --- ESPANSIONE ---
		for n_id in graph.neighbors(id):
			q.append({
				"id": n_id,
				"abilities": abilities.duplicate()
			})
			
	for n in graph.nodes.values():
		print(n.id, " -> ", n.logical_abilities_before)

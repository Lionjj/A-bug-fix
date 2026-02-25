extends Node
class_name ConstraintValidator


# ------------------------------------------------------------------------------
# PUBLIC API
# ------------------------------------------------------------------------------

static func solvable(G: MissionGraph) -> bool:
	
	var start := G.start_id
	var goal := G.boss_id
	
	var q: Array = [
		{
			"id": start,
			"abilities": [] as Array[Abilities.Ability],
			"keys": 0,
			"unlocked": {}   # edge_key -> true
		}
	]
	
	var seen: Dictionary = {}
	
	while q.size() > 0:
		
		var s = q.pop_front()
		
		var id: String = s["id"]
		var abilities: Array = s["abilities"].duplicate()
		var keys: int = s["keys"]
		var unlocked: Dictionary = s["unlocked"].duplicate()
		
		# ---- STATE KEY (include tutto!)
		var abil_key = abilities.duplicate()
		abil_key.sort()
		
		var unlocked_keys = unlocked.keys()
		unlocked_keys.sort()
		
		var state_key = "%s|%s|%d|%s" % [
			id,
			abil_key,
			keys,
			unlocked_keys
		]
		
		if seen.has(state_key):
			continue
		
		seen[state_key] = true
		
		# ---- Nodo corrente
		var node: MissionNode = G.nodes[id]
		
		# ---- Acquisizione abilità permanenti
		for g in node.grants:
			if not abilities.has(g):
				abilities.append(g)
		
		# ---- Raccolta chiavi
		if node.catalog:
			for item in node.catalog.items:
				if item.id == ItemRegistry.ID.KEY:
					keys += 1
		
		# ---- Goal raggiunto?
		if id == goal:
			return true
		
		# ---- Espansione BFS
		for v_id in G.neighbors(id):
			
			var result = can_traverse(
				G,
				id,
				v_id,
				abilities,
				keys,
				unlocked
			)
			
			if not result["ok"]:
				continue
			
			q.append({
				"id": v_id,
				"abilities": abilities.duplicate(),
				"keys": result["keys"],
				"unlocked": result["unlocked"]
			})
	
	return false


# ------------------------------------------------------------------------------
# TRAVERSAL VALIDATION
# ------------------------------------------------------------------------------

static func can_traverse(
	G: MissionGraph,
	from_id: String,
	to_id: String,
	abilities: Array[Abilities.Ability],
	keys: int,
	unlocked: Dictionary
) -> Dictionary:
	
	# 1) Ability gating (nodo)
	if not _check_abilities(G, to_id, abilities):
		return {"ok": false}
	
	# 2) Edge lock gating
	return _check_edge_lock(G, from_id, to_id, keys, unlocked)


# ------------------------------------------------------------------------------
# ABILITY CHECK
# ------------------------------------------------------------------------------

static func _check_abilities(
	G: MissionGraph,
	node_id: String,
	abilities: Array[Abilities.Ability]
) -> bool:
	
	var req: Array[Abilities.Ability] = G.nodes[node_id].requires
	
	for r in req:
		if not abilities.has(r):
			return false
	
	return true


# ------------------------------------------------------------------------------
# EDGE LOCK CHECK
# ------------------------------------------------------------------------------

static func _check_edge_lock(
	G: MissionGraph,
	from_id: String,
	to_id: String,
	keys: int,
	unlocked: Dictionary
) -> Dictionary:
	
	var edge_key = G.edge_key(from_id, to_id)
	var lock_type = G.get_edge_lock(from_id, to_id)
	
	var new_keys := keys
	var new_unlocked := unlocked.duplicate()
	
	match lock_type:
		
		MissionGraph.LockType.FREE:
			pass
		
		MissionGraph.LockType.ENEMIES_CLEARED:
			# assumiamo sempre superabile in validazione
			pass
		
		MissionGraph.LockType.KEY:
			
			# Se già aperta, passa
			if new_unlocked.has(edge_key):
				pass
			else:
				# Serve una chiave
				if new_keys <= 0:
					return {"ok": false}
				
				new_keys -= 1
				new_unlocked[edge_key] = true
	
	return {
		"ok": true,
		"keys": new_keys,
		"unlocked": new_unlocked
	}

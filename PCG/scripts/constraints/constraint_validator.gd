extends Node
class_name ConstraintValidator

static func can_traverse(G:MissionGraph, from_id:String, to_id:String, abilities:Array[int]) -> bool:
	var req :Array[int]= G.nodes[to_id].requires
	for r in req:
		if not abilities.has(r): return false
	return true

# Verifica se il grafo prodotto è risovlible ovvero se esite un percorso
# dal nodo start al goal
static func solvable(G:MissionGraph) -> bool:
	var start : String = G.start_id; 
	var goal : String = G.boss_id
	
	var q : Array[Dictionary] = [ {"id":start, "abilities": [] as Array[int]} ]
	var seen : Dictionary = {} # key -> true
	
	while q.size() > 0:
		
		var s : Dictionary = q.pop_front()
		var s_id : String = s["id"]
		
		var abil_key : Array[int] = (s["abilities"] as Array[int]).duplicate()
		abil_key.sort()
		var key : String = "%s|%s" % [s_id, abil_key]
		
		if seen.has(key): continue
		seen[key] = true
		
		# recupera il nodo missione
		var n : MissionNode = (G.nodes[s_id] as MissionNode)
		
		var abil : Array[int] = (s["abilities"] as Array[int]).duplicate()
		for g in n.grants:
			if not abil.has(g): abil.append(g)
		
		# goal raggiunt?
		if s["id"]==goal: return true
		
		# espansion BFS
		for v in G.neighbors(s_id):
			var v_id: String = v
			if can_traverse(G, v_id, v, abil):
				q.append( {"id":v_id, "abilities": abil.duplicate()} )
	return false

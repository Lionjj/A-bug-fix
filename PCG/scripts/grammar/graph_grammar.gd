## Modulo utilizzato per gestire l'espansione della grammatica di base del grafo.
extends Node
class_name GraphGrammar

## Regole della grammatica.
var rules : Array = []
## Counter utilizzato per gestire gli identificativi dei nodi generati.
var _id_counter : int = 0

## Metodo utilizzato per caricare le regole della grammatica situate nel file al percorso [param path].
func load_rules(path: String) -> void:
	rules = JSON.parse_string(FileAccess.get_file_as_string(path))["rules"]

func _match(n:MissionNode, cond:Dictionary) -> bool:
	return (not cond.has("kind")) or (n.kind == cond["kind"])

## Metodo utilizzato per espandere il grafo di base [param G] applicando le regole della grammatica
## fintanto che il numero di nodi generati e minore del [param budget] fornito.
func expand(G:MissionGraph, budget:int) -> void:
	var to_elaborate: Dictionary[String, MissionNode] = G.nodes.duplicate()
	
	while G.node_count() < budget:
		for k in to_elaborate.keys():
			
			var node: MissionNode = to_elaborate.get(k)
			print("ID:", k, " NODE:", node.kind)	#Debug
			
			for rule in rules:
				if _match(node, rule.get("match", {})):
					
					var t : Dictionary[String, MissionNode] = _apply_rule(G, k, rule)
					to_elaborate.merge(t)
					
			to_elaborate.erase(k)

## Metodo che applica la regola [param rule] di espasione al nodo target identifiato da [param target_id].
## I nuovi nodi e i collegamneti sono poi inseriti consistentemnete nel grafo di base [param G].
func _apply_rule(G: MissionGraph, target_id: String, rule: Dictionary) -> Dictionary[String, MissionNode]:
	var attach_id : String = target_id
	var out: Dictionary[String, MissionNode] = {}

	## Per ciascun nodo generato viene creato un identificativo univoco.
	## Contiene le coppie [A$, A*] con * numero intero incrementale.
	var new_ids : Dictionary[String, String] = {}
	out = _applay_expand_nodes(G, rule, new_ids)
	## Collega i nodi aggiungendo archi al grafo tra loro secondo le regole definite nella grammatica.
	_applay_expand_edges(G, rule, new_ids)
	## Riaggancia la nodo target i nodi generati secondo le regole definite nella grammatica.
	_applay_attach(G, target_id, rule, new_ids)
	return out

## Metodo per generare l'id univoco partendo da un id base [param base_id].
func _unique_id(base_id: String) -> String:
	_id_counter += 1
	return "%d" % _id_counter

## Metodo che esporta dalle regole presenti in [param node_def] esportare 
## la lista di oggetti che può o deve contenere una stanza.
func _get_items(node_def: Dictionary) -> Array[Item]:
	var out : Array[Item] = []
	if !node_def.has("items"): return out
	
	for itemJSON in node_def["items"]:
		var _id : ItemRegistry.ID = ItemRegistry.ID.get((itemJSON["id"] as String).to_upper())
		var _name : String = itemJSON["name"] as String
		var _priority : Item.Priority = Item.Priority.get((itemJSON["priority"] as String).to_upper())
		var _spawn_rate : float = itemJSON["spawn_rate"] as float
		var _max_quantity : int = itemJSON["max_quantity"] as int
		
		var item : Item = Item.new(_id, _name, _priority, _spawn_rate, _max_quantity)

		out.append(item)

	return out

## Metodo privato usato per gestire l'applicazione della regola "attach"
## presenti in [param rule].
## I nuovi nodi e i collegamneti sono poi inseriti consistentemnete nel grafo di base [param G]
## ad un nodo di ancoraggio [param target_id].
## Sono poi utilizzati i nodi presenti in [param new_ids] come effettivi identificativi dei nodi.
## Vedi anche il [method _apply_rule]
func _applay_attach(G: MissionGraph, target_id: String, rule: Dictionary, new_ids: Dictionary[String, String]) -> void:
	if !rule.has("attach"): return
	
	for att in rule["attach"]:
		var _id: String = att["id"] as String
		var _lock: MissionGraph.LockType = MissionGraph.LockType.get((att["lock"] as String).to_upper(), MissionGraph.LockType.FREE)
		var _back_lock: MissionGraph.LockType = MissionGraph.LockType.get((att["back_lock"] as String).to_upper(), MissionGraph.LockType.FREE)
		
		var attach_real : String = new_ids[_id]
		G.add_edge(target_id, attach_real)
		G.lock_edge(target_id, attach_real, _lock)
		G.lock_edge(attach_real, target_id, _back_lock)
		

## Metodo privato usato per gestire l'applicazione della regola "expand_edges"
## presenti in [param rule].
## I nuovi nodi e i collegamneti sono poi inseriti consistentemnete nel grafo di base [param G].
## Viene poi aggiornata il dizionario contenente gli ID reali dei nodi [param new_ids].
## Vedi anche il [method _apply_rule]
func _applay_expand_edges(G: MissionGraph, rule: Dictionary, new_ids: Dictionary[String, String]) -> void:
	if !rule.has("expand_edges"): return
	
	for pair in rule["expand_edges"]:
		var _from: String = pair["from"] as String
		var _to: String = pair["to"] as String
		var _lock: MissionGraph.LockType = MissionGraph.LockType.get((pair["lock"] as String).to_upper(), MissionGraph.LockType.FREE)
		var _back_lock: MissionGraph.LockType = MissionGraph.LockType.get((pair["back_lock"] as String).to_upper(), MissionGraph.LockType.FREE)
		
		var real_from : String = new_ids[_from]
		var real_to : String = new_ids[_to]
		
		G.add_edge(real_from, real_to)
		G.lock_edge(real_from, real_to, _lock)
		G.lock_edge(real_to, real_from, _back_lock)

## Metodo per esportare dalle regole presenti in [param node_def] i nemici 
## che può o deve contenere una stanza.
func _get_enemy_directive(node_def: Dictionary) -> EnemyDirective:
	if !node_def.has("enemies"): return EnemyDirective.new()
	
	var enemyJSON = node_def["enemies"]

	var _budget_mult: float = enemyJSON["budget_mult"] as float
	var _waves: int = enemyJSON["waves"] as int
	var _combat_type: EnemyDirective.CombatType = EnemyDirective.CombatType.get((enemyJSON["combat_type"] as String).to_upper(), EnemyDirective.CombatType.NO_COMBAT)
		
	return EnemyDirective.new(_budget_mult, _waves, _combat_type)

## Metodo per esportare dalle regole presenti in [param node_def] le trappole 
## che può o deve contenere una stanza.
func _get_trap_directive(node_def: Dictionary) -> TrapDirective:
	if !node_def.has("traps"): return TrapDirective.new()
	
	var trapsJSON = node_def["traps"]

	var _budget_mult: float = trapsJSON["budget_mult"] as float
	var _trap_type: TrapDirective.TrapType = TrapDirective.TrapType.get((trapsJSON["trap_type"] as String).to_upper(), TrapDirective.TrapType.NO_TRAPS)
		
	return TrapDirective.new(_budget_mult, _trap_type)


## Metodo privato usato per gestire l'applicazione della regola "expand_nodes"
## presenti in [param rule].
## I nuovi nodi e i collegamneti sono poi inseriti consistentemnete nel grafo di base [param G].
## Viene poi aggiornata il dizionario contenente gli ID reali dei nodi [param new_ids].
## Vedi anche il [method _apply_rule]
func _applay_expand_nodes(G: MissionGraph, rule: Dictionary, new_ids: Dictionary[String, String]) -> Dictionary[String, MissionNode]:
	var out: Dictionary[String, MissionNode] = {}
	if !rule.has("expand_nodes"): return out
	
	for node_def in rule["expand_nodes"]:
		var _id: String = node_def["id"] as String
		var _kind: String = node_def["kind"] as String

		## sostituzione del "$" del base_id con un numero incrementale
		var real_id : String = _id.replace("$", str(_unique_id(_id)))
		new_ids[_id] = real_id
		
		## Viene creato il nuovo nodo
		var node : MissionNode = MissionNode.new(real_id, _kind)
		
		## Viene estratto e assegnato il cataglogo di oggetti che la stanza può/deve contenere
		node.catalog = NodeCatalogue.new(_get_items(node_def))
		## Viene estratto e assegnato la direttiva per gestire i nemici
		node.enemy_directive = _get_enemy_directive(node_def)
		## Viene estratto e assegnato la direttiva per gestire le trappole
		node.trap_directive = _get_trap_directive(node_def)
		
		# copia le proprietà addizionali (requires, grants, optional)
		#for key in node_def.keys():
			#if key not in ["id", "kind"]:
				#node.set(key, node_def[key])
		
		G.add_node(node)
		out[real_id] = node
	
	return out

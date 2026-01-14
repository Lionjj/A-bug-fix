## Modulo contenente il la struttura e le operazioni del grafo non orientato, 
## rappresentante la logica del livello.
class_name MissionGraph

## Rppresenta se il passaggio da una stanza a l'altra è libero o bloccato, il blocco e sormontabile
## a seguito della richiesta. Attualmente le richieste sono:
## - Eliminazione di tutti i nemici;
## - Richiesta una chiave;
enum LockType { FREE, ENEMIES_CLEARED, KEY }

## Dizionario rappresentante i nodi del grafo logico.
var nodes: Dictionary[String, MissionNode] = {}
## Dizionario rappresentante gli archi fra i nodi.
var edges: Dictionary[String, Array] = {}
## Dizionario rappresentante come sono le connessioni tra gli archi (libere o bloccate)
var edge_lock: Dictionary[String, LockType] = {}

## Chiave del nodo di partenza.
var start_id :String = "S"
## Chiave del nodo di arrivo.
var boss_id :String = "B"

func add_node(n: MissionNode) -> void:
	nodes[n.id] = n
	if not edges.has(n.id):
		edges[n.id] = [] as Array[String]

func add_edge(a: String, b: String) -> void:
	if not edges.has(a):
		edges[a] = [] as Array[String]
	
	if not edges.has(b):
		edges[b] = [] as Array[String]
	
	if not edges[a].has(b):
		edges[a].append(b)
	
	if not edges[b].has(a):
		edges[b].append(a)

func erase_edge(a: String, b: String) -> void:
	if not edges.has(a) or not edges.has(b): return
	
	edges[a].erase(b)
	edges[b].erase(a)

func has_edge(a: String, b: String) -> bool:
	if !edges.has(a): return false
	return edges[a].has(b)

func neighbors(id: String) -> Array[String]:
	return edges.get(id, [] as Array[String])

func node_count() -> int:
	return nodes.size()

func out_edges(id: String) -> Array:
	var out := []
	for t in neighbors(id):
		out.append({"from": id, "to": t})
	return out

func topo_order() -> Array:
	var indeg := {}
	for k in nodes.keys():
		indeg[k] = 0

	for a in edges.keys():
		for b in edges[a]:
			indeg[b] += 1

	var q := []
	for k in indeg.keys():
		if indeg[k] == 0:
			q.append(k)

	var order := []
	while q.size() > 0:
		var u = q.pop_front()
		order.append(u)
		for v in neighbors(u):
			indeg[v] -= 1
			if indeg[v] == 0:
				q.append(v)

	return order

## Questo metodo privato viene utilizzato per creare le chiavi del dizionario [member edge_lock] 
## in modo tale da rendere ciascuna chiave del tipo (A->B).
## Per garantire l'accesso corretto ad un valore di questo dizionario è fortemente sconsigliato 
## usare altri metodi.
## [param from] e [param to] rappresentato gli ideitifatori dei nodi tra cui sussite l'arco.
func _edge_key(from: String, to: String) -> String:
	return (from + "->" + to)

## Metodo usato per definire il tipo di passaggio [param lock] tra i nodi [param from] e [param to].
func lock_edge(from: String, to: String, lock: LockType = LockType.KEY) -> void:
	if !has_edge(from,to):
		push_warning("lock_edge: arco inesistente %s-%s" % [from, to])
		return
	edge_lock[_edge_key(from, to)] = lock

## Metodo per eliminare evenutali blocchi tra i nodi [param from] e [param to].
func unlock_edge(from: String, to: String) -> void:
	edge_lock.erase(_edge_key(from, to))

## Metodo per ottenere il tipo diblocco tra i nodi [param from] e [param to].
func get_edge_lock(from: String, to: String) -> LockType:
	return edge_lock.get(_edge_key(from, to), LockType.ENEMIES_CLEARED)

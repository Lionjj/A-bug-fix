# ============================================================================
# MissionGraph
# ============================================================================
## Modulo contenente la struttura e le operazioni del grafo non orientato,
## rappresentante la logica del livello.[br]
##
## Responsabilità principali:[br]
## - Gestire i nodi logici ([MissionNode]) indicizzati per id.[br]
## - Gestire gli archi non orientati tramite lista di adiacenza.[br]
## - Gestire i lock sugli archi (passaggi bloccati / sbloccati) tramite [LockType].[br]
## - Fornire utility comuni: vicini, conteggio nodi, lista archi uscenti, ordine topologico.[br]
##
## Note architetturali:[br]
## - Gli archi sono modellati come non orientati, quindi un edge (A-B) viene salvato
##   in entrambe le liste: A→B e B→A.[br]
## - I lock sono salvati in [member edge_lock] usando una chiave direzionale "A->B".[br]
##   Questo permette lock asimmetrici (A->B diverso da B->A) se necessario.[br]
# ============================================================================

class_name MissionGraph


# ---------------------------------------------------------------------------
# Lock policy
# ---------------------------------------------------------------------------

## Rappresenta se il passaggio da una stanza all'altra è libero o bloccato.
## Il blocco può essere sormontabile a seguito di una condizione.[br]
## Condizioni attuali:[br]
## - Eliminazione dei nemici (tutti i nemici della stanza).[br]
## - Possesso di una chiave.[br]
enum LockType { FREE, ENEMIES_CLEARED, KEY }


# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------

## Dizionario rappresentante i nodi del grafo logico.[br]
## - Key: String (id nodo)[br]
## - Value: [MissionNode]
var nodes: Dictionary[String, MissionNode] = {}

## Dizionario rappresentante gli archi fra i nodi (lista di adiacenza).[br]
## - Key: String (id nodo)[br]
## - Value: Array[String] (lista vicini)
var edges: Dictionary[String, Array] = {}

## Dizionario rappresentante il lock sugli archi, indicizzato da chiave "A->B".[br]
## - Key: String "from->to"[br]
## - Value: [LockType]
var edge_lock: Dictionary[String, LockType] = {}

## Id del nodo di partenza.
var start_id: String = "S"

## Id del nodo boss / arrivo.
var boss_id: String = "B"


# ---------------------------------------------------------------------------
# Node ops
# ---------------------------------------------------------------------------

## Aggiunge un nodo al grafo.[br]
## - inserisce in [member nodes][br]
## - assicura la lista adiacenze in [member edges][br]
##
## [param n] Nodo logico da aggiungere.
func add_node(n: MissionNode) -> void:
	nodes[n.id] = n
	if not edges.has(n.id):
		edges[n.id] = []


# ---------------------------------------------------------------------------
# Edge ops (undirected)
# ---------------------------------------------------------------------------

## Aggiunge un arco non orientato tra [param a] e [param b].[br]
## - inizializza liste adiacenze se mancanti[br]
## - evita duplicati[br]
##
## [param a] Id nodo A.[br]
## [param b] Id nodo B.
func add_edge(a: String, b: String) -> void:
	if not edges.has(a):
		edges[a] = []
	if not edges.has(b):
		edges[b] = []

	if not edges[a].has(b):
		edges[a].append(b)
	if not edges[b].has(a):
		edges[b].append(a)


## Rimuove un arco non orientato tra [param a] e [param b].[br]
## Nota: non rimuove eventuali lock già presenti in [member edge_lock].[br]
## Se vuoi pulire anche i lock, vedi [method unlock_edge] (direzione singola).[br]
##
## [param a] Id nodo A.[br]
## [param b] Id nodo B.
func erase_edge(a: String, b: String) -> void:
	if not edges.has(a) or not edges.has(b):
		return

	edges[a].erase(b)
	edges[b].erase(a)


## Verifica se esiste un arco A->B nella lista di adiacenza.[br]
## Nota: per grafo non orientato, controlla solo la lista di A.[br]
##
## [param a] Id nodo A.[br]
## [param b] Id nodo B.[br]
## [return] True se B è nei vicini di A.
func has_edge(a: String, b: String) -> bool:
	if not edges.has(a):
		return false
	return edges[a].has(b)


## Ritorna la lista di vicini di un nodo.[br]
##
## [param id] Id del nodo.[br]
## [return] Array dei vicini (può essere vuoto).
func neighbors(id: String) -> Array:
	return edges.get(id, [])


## Ritorna il numero di nodi nel grafo.[br]
##
## [return] Conteggio nodi.
func node_count() -> int:
	return nodes.size()


## Ritorna la lista degli archi uscenti da un nodo in formato strutturato.[br]
## Utile per debugging/serializzazione semplice.[br]
##
## [param id] Id del nodo.[br]
## [return] Array di Dictionary con chiavi "from" e "to".
func out_edges(id: String) -> Array:
	var out: Array = []
	for t: String in neighbors(id):
		out.append({"from": id, "to": t})
	return out


# ---------------------------------------------------------------------------
# Graph utilities
# ---------------------------------------------------------------------------

## Calcola un ordine "topologico" basato su indegree.[br]
## ATTENZIONE: un grafo non orientato e con cicli NON ha un vero ordine topologico.[br]
## Questa funzione è utile solo se la struttura risultante è aciclica (o se la usi
## come euristica di visita).[br]
##
## [return] Array con un ordine di visita; se ci sono cicli, l'output può essere parziale/non significativo.
func topo_order() -> Array:
	var indeg: Dictionary = {}
	for k: String in nodes.keys():
		indeg[k] = 0

	for a: String in edges.keys():
		for b: String in edges[a]:
			indeg[b] += 1

	var q: Array = []
	for k in indeg.keys():
		if indeg[k] == 0:
			q.append(k)

	var order: Array = []
	while q.size() > 0:
		var u: String = q.pop_front()
		order.append(u)

		for v: String in neighbors(u):
			indeg[v] -= 1
			if indeg[v] == 0:
				q.append(v)

	return order


# ---------------------------------------------------------------------------
# Edge locks
# ---------------------------------------------------------------------------

## Crea la chiave interna per [member edge_lock] nel formato "A->B".[br]
## Nota: per evitare bug, non costruire manualmente la chiave altrove.[br]
##
## [param from] Id nodo sorgente.[br]
## [param to] Id nodo destinazione.[br]
## [return] String chiave "from->to".
func edge_key(from: String, to: String) -> String:
	return from + "->" + to


## Definisce il tipo di lock sull'arco (direzionale) [param from] -> [param to].[br]
## Nota: dato che il grafo è non orientato, se vuoi un lock simmetrico devi chiamare
## anche lock_edge(to, from, lock).[br]
##
## [param from] Id nodo sorgente.[br]
## [param to] Id nodo destinazione.[br]
## [param lock] Tipo lock da applicare (default KEY).
func lock_edge(from: String, to: String, lock: LockType = LockType.KEY) -> void:
	if not has_edge(from, to):
		push_warning("lock_edge: arco inesistente %s-%s" % [from, to])
		return

	edge_lock[edge_key(from, to)] = lock


## Elimina un eventuale lock sull'arco direzionale [param from] -> [param to].[br]
##
## [param from] Id nodo sorgente.[br]
## [param to] Id nodo destinazione.
func unlock_edge(from: String, to: String) -> void:
	edge_lock.erase(edge_key(from, to))


## Ritorna il lock sull'arco direzionale [param from] -> [param to].[br]
## Se non esiste alcun lock registrato, ritorna un valore di default.[br]
##
## [param from] Id nodo sorgente.[br]
## [param to] Id nodo destinazione.[br]
## [return] [LockType] associato all'edge, oppure default se assente
func get_edge_lock(from: String, to: String) -> LockType:
	return edge_lock.get(edge_key(from, to), LockType.FREE)

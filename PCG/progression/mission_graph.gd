class_name MissionGraph

var nodes :Dictionary= {}     # id -> MissionNode
var edges :Dictionary= {}     # id -> Array[id]
var start_id :String= "S"
var boss_id :String= "B"

func add_node(n: MissionNode) -> void:
	nodes[n.id] = n
	if not edges.has(n.id):
		edges[n.id] = [] as Array[String]

func add_edge(a: String, b: String) -> void:
	if not edges.has(a):
		edges[a] = [] as Array[String]
	if not edges[a].has(b):
		edges[a].append(b)

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

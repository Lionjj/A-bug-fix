class_name ExpandDriver
static func run(G:MissionGraph, budget:int) -> void:
	var gg : GraphGrammar = GraphGrammar.new()
	gg.load_rules("res://pcg/data/grammar/metroidvania_rules.json")
	gg.expand(G, budget)

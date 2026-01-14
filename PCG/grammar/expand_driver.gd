static func run(G:MissionGraph, budget:int) -> void:
	var gg : GraphGrammar = GraphGrammar.new()
	gg.load_rules("res://pcg/grammar/metroidvania_rules.json")
	gg.expand(G, budget)

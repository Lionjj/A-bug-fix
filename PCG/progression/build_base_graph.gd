static func build_base() -> MissionGraph:
	var G := MissionGraph.new()
	G.add_node(MissionNode.new("S","START"))
	G.add_node(MissionNode.new("H1","HUB"))
	G.add_node(MissionNode.new("K1","KEY_ROOM"))
	(G.nodes["K1"] as MissionNode).grants.append(Abilities.Ability.DASH)
	G.add_node(MissionNode.new("C1","CHALLENGE"))
	(G.nodes["C1"] as MissionNode).requires.append(Abilities.Ability.DASH)
	G.add_node(MissionNode.new("SV1","SAVE"))
	G.add_node(MissionNode.new("B","BOSS"))
	G.add_edge("S","H1"); G.add_edge("H1","K1"); G.add_edge("K1","C1"); G.add_edge("C1","SV1"); G.add_edge("SV1","B")
	G.start_id="S"; G.boss_id="B"
	return G

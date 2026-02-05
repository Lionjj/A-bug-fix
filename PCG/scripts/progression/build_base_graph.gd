class_name BaseGraph
static func build_base() -> MissionGraph:
	var G : MissionGraph = MissionGraph.new()
	
	## Main path
	G.add_node(MissionNode.new("S", RoomTags.Tag.START))
	G.add_node(MissionNode.new("H", RoomTags.Tag.HUB))
	G.add_node(MissionNode.new("A", RoomTags.Tag.ARENA))
	G.add_node(MissionNode.new("K", RoomTags.Tag.KEY_ROOM))
	G.add_node(MissionNode.new("C", RoomTags.Tag.CHALLENGE))
	G.add_node(MissionNode.new("B", RoomTags.Tag.BOSS))
	
	## Ability granted/required
	(G.nodes["K"] as MissionNode).grants.append(Abilities.Ability.GRAPPLE)
	(G.nodes["C"] as MissionNode).requires.append(Abilities.Ability.GRAPPLE)
	
	## Item list
	(G.nodes["S"] as MissionNode).catalog = NodeCatalogue.new([
		Item.new(ItemRegistry.ID.CHECKPOINT, "Checkpoint", Item.Priority.MANDATORY),
		Item.new(ItemRegistry.ID.HEART, "Heart", Item.Priority.OPTIONAL, 0.5)
	])
	
	(G.nodes["A"] as MissionNode).catalog = NodeCatalogue.new(
		[Item.new(ItemRegistry.ID.HEART, "Heart", Item.Priority.OPTIONAL, 0.7, 3)]
	)
	(G.nodes["K"] as MissionNode).catalog = NodeCatalogue.new(
		[Item.new(ItemRegistry.ID.KEY, "Key", Item.Priority.MANDATORY, 1)]
	)
	(G.nodes["C"] as MissionNode).catalog = NodeCatalogue.new(
		[Item.new(ItemRegistry.ID.HEART, "Heart", Item.Priority.OPTIONAL, 2)]
	)
	
	## Enemy
	(G.nodes["A"] as MissionNode).enemy_directive = EnemyDirective.new(1, 3, EnemyDirective.CombatType.WAVES)
	(G.nodes["K"] as MissionNode).enemy_directive = EnemyDirective.new(1, 1, EnemyDirective.CombatType.WAVES)
	(G.nodes["C"] as MissionNode).enemy_directive = EnemyDirective.new(1, 2, EnemyDirective.CombatType.WAVES)
	(G.nodes["B"] as MissionNode).enemy_directive = EnemyDirective.new(1, 2, EnemyDirective.CombatType.BOSS)
	
	## Trap
	(G.nodes["A"] as MissionNode).trap_directive = TrapDirective.new(1, TrapDirective.TrapType.STATIC)
	(G.nodes["K"] as MissionNode).trap_directive = TrapDirective.new(1, TrapDirective.TrapType.STATIC)
	(G.nodes["C"] as MissionNode).trap_directive = TrapDirective.new(1, TrapDirective.TrapType.STATIC)
	(G.nodes["B"] as MissionNode).trap_directive = TrapDirective.new(1, TrapDirective.TrapType.STATIC)
	
	## Edge
	G.add_edge("S","H")
	G.add_edge("H","A")
	G.add_edge("A","K") 
	G.add_edge("K","C") 
	G.add_edge("C","B") 
	
	## Regole per gestire i blocchi tra gli edge
	G.lock_edge("S", "H", MissionGraph.LockType.FREE)
	G.lock_edge("H", "S", MissionGraph.LockType.FREE)
	
	G.lock_edge("H", "A", MissionGraph.LockType.FREE)
	G.lock_edge("A", "H", MissionGraph.LockType.ENEMIES_CLEARED)
	
	G.lock_edge("A", "K", MissionGraph.LockType.ENEMIES_CLEARED)
	G.lock_edge("K", "A", MissionGraph.LockType.ENEMIES_CLEARED)
	
	G.lock_edge("K", "C", MissionGraph.LockType.ENEMIES_CLEARED)
	G.lock_edge("C", "K", MissionGraph.LockType.ENEMIES_CLEARED)
	
	G.lock_edge("C", "B", MissionGraph.LockType.ENEMIES_CLEARED)
	G.lock_edge("B", "C", MissionGraph.LockType.ENEMIES_CLEARED)
	
	return G

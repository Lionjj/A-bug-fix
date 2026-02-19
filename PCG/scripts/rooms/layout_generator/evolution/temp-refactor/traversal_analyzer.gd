# ============================================================================
# TraversalAnalyzer
# ============================================================================
## Questa classe verifica che la stanza genererata sia giocabile dal gioctore.
##
## In particolare deve verificare che il giocatore possa arrivare secondo i 
## movimenti stabiliti alle: [br]
## - Uscite delle stanze (connettori N/S/E/W);
## - Tutte le celle calpestabili.
class_name TraversalAnalyzer
extends RefCounted

# ----------------------------------------------------------------------------
# API
# ----------------------------------------------------------------------------

## Verifica che eista un percorso che colleghi tutti i connettori secondo i 
## movimenti consenitit al player. [br]
## [param mask]: Rappresentazione semplificata di una stanza in cui si muove il player;
## [param plan]: Informazioni dei connettori;
## [param profile]: Dati euristici rappresentati i movimenti del player semplificati;
static func are_connectors_reacable(mask: RoomLayoutMask, plan: ConnectorPlan, profile: PlayerTraversalProfile) -> bool:
	var active := _carve_all_opening(mask, plan)
	
	if active.size() <= 1:
		return true
	
	var connector: int = active[0]
	var root: Vector2i = PlayerReachability.get_connector_entry_cell(mask, plan, connector)
	
	if root.x == -1:
		printerr("TraversalAnalyzer: Connector root invalido:", connector)
		return false
	
	#--------------------------------------------------------------------------
	# Verifica che si puo arrivare dal connettore root agli altri connettori
	#--------------------------------------------------------------------------
	
	for i in range(1, active.size()):
		var target: int = active[i]
		
		var solution_area: Array[Vector2i] = PlayerReachability.get_connector_volume_cells(
			mask, plan, target
		)
		
		if not PlayerReachability.has_path(
			mask, profile, root, solution_area
		): 
			printerr("TraversalAnalyzer: Non vi è alcun percorso: ", connector, " -> ", target)
			return false
	
	var root_area: Array[Vector2i] = PlayerReachability.get_connector_volume_cells(
			mask, plan, connector
	)
		
	for i in range(1, active.size()):
		var start_dir: int = active[i]
		var start: Vector2i = PlayerReachability.get_connector_entry_cell(mask, plan, start_dir)
		
		if not PlayerReachability.has_path(
			mask, profile, start, root_area
		): 
			printerr("TraversalAnalyzer: Non vi è alcun percorso: ", start_dir, " -> ", connector)
			return false
	
	#for i in range(active.size()):
		#var dir: int = active[i]
		#var start: Vector2i = PlayerReachability.get_connector_entry_cell(mask, plan, dir)
		#
		#if start.x == -1:
			#print("ERRORE start invalido:", dir)
			#return false
		#
		#for j in range(active.size()):
			#if i == j: continue
			#
			#var target: int = active[j]
			#var solution_area: Array[Vector2i] = PlayerReachability.get_connector_volume_cells(
				#mask, plan, target
			#)
			#
			#if not PlayerReachability.has_path(
				#mask, profile, start, solution_area
			#): 
				#print("Non vi è alcun percorso: ", start, " -> ", target)
				#return false
		
	return true

## Verifica che eista un percorso che colleghi tutte le celle paviment secondo i 
## movimenti consenitit al player. [br]
## [param mask]: Rappresentazione semplificata di una stanza in cui si muove il player;
## [param profile]: Dati euristici rappresentati i movimenti del player semplificati;
static func are_floor_tile_reacable(mask: RoomLayoutMask, profile: PlayerTraversalProfile) -> bool:
	var floor_clusters: Dictionary[Vector2i, Array] = _build_walk_graph(mask)
	
	if floor_clusters.size() <= 1:
		return true
	
	var root: Vector2i = floor_clusters.keys()[0]
	
	for kay in floor_clusters.keys():
		if kay == root: continue
		
		var target: Array[Vector2i] = floor_clusters[kay]
		if not PlayerReachability.has_path(
			mask, profile, root, target
		): 
			printerr("TraversalAnalyzer: path invalido:", root, "->", kay)
			return false
	
	var root_cluster: Array[Vector2i] = floor_clusters[root]
	
	for kay in floor_clusters.keys():
		if kay == root: continue
		
		var target: Array[Vector2i] = floor_clusters[kay]
		if not PlayerReachability.has_path(
			mask, profile, kay, root_cluster
		): 
			printerr("TraversalAnalyzer: path invalido:", kay, "->", root)
			return false
	
	return true


# ----------------------------------------------------------------------------
# Helper
# ----------------------------------------------------------------------------

## Scava le aperture rispettando le informanzioni conetune nel [b] plan [\b].[br]
## [param mask]: Rappresentazione semplificata di una stanza;
## [param plan]: Informazioni dei connettori;
static func _carve_all_opening(mask: RoomLayoutMask, plan: ConnectorPlan) -> Array[int]:
	var out: Array[int] = []
	
	for dir in Dir4.ORDER:
		if not plan.is_enabled(dir):
			continue
		
		PlayerReachability.carve_connector_volume(mask, plan, dir)
		out.append(dir)
	
	return out

## Costruisce un dizoonario di cluster tale che come chiave abiamo una cella 
## pavimento di quel cluster, come valore il cluster stesso. [br]
## Le condizioni che permetto ad una cella di far parte di un cluster sono: [br]
## - Deve essere una cella sul pavimento; [br]
## - a sinstra o a destra o entrambe le direzioni deve avere una cella facente 
## già parte di quel cluster; [br]
## [param mask]: Rappresentazione semplificata di una stanza;
static func _build_walk_graph(mask: RoomLayoutMask) -> Dictionary[Vector2i, Array]:

	var floors = mask.collect_floor_tiles()
	var floor_set := {}
	
	for f in floors:
		floor_set[f] = true
	
	var graph := {}
	
	for f in floors:
		graph[f] = []
		
		for dir in [Vector2i.LEFT, Vector2i.RIGHT]:
			var n = f + dir
			
			if floor_set.has(n):
				graph[f].append(n)
	
	return graph

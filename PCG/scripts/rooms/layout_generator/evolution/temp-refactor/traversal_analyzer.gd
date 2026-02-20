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

class Root:
	var dir: int
	var cell: Vector2i
	
	func _init(_dir: int, _cell: Vector2i) -> void:
		dir = _dir
		cell = _cell

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
	
	var root: Root = _find_lowest_active_connector(mask, plan, active)
	
	if root.dir == -1:
		printerr("TraversalAnalyzer.are_connectors_reacable: Nessun connettore valido")
		return false
	
	#--------------------------------------------------------------------------
	# Verifica che si puo arrivare dal connettore root agli altri connettori
	#--------------------------------------------------------------------------
	
	for i in range(active.size()):
		var target: int = active[i]
		
		if root.dir == target:
			continue
		
		var solution_area: Array[Vector2i] = PlayerReachability.get_connector_volume_cells(
			mask, plan, target
		)
		
		if not PlayerReachability.has_path(
			mask, profile, root.cell, solution_area
		): 
			printerr("TraversalAnalyzer: Non vi è alcun percorso: ", root.dir, " -> ", target)
			return false
		
	return true

## Verifica che eista un percorso che colleghi tutte le celle paviment secondo i 
## movimenti consenitit al player. [br]
## [param mask]: Rappresentazione semplificata di una stanza in cui si muove il player;
## [param profile]: Dati euristici rappresentati i movimenti del player semplificati;
static func are_floor_tile_reacable(mask: RoomLayoutMask, profile: PlayerTraversalProfile) -> bool:
	return PlayerReachability.can_reach_all_floor_tiles(mask, profile)


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


## Trova il connettore con il punto più basso rispetto ai connettori attivi 
## nella stanza
## [param mask]: Rappresentazione semplificata di una stanza;
## [param plan]: Informazioni dei connettori;
## [param active]: Rappresenta quali connettori sono attivi
static func _find_lowest_active_connector(
	mask: RoomLayoutMask,
	plan: ConnectorPlan,
	active: Array[int]
) -> Root:

	var best_pos := Vector2i(-1, -1)
	var best_dir := -1
	var best_y := -INF

	for dir in active:
		var entry := PlayerReachability.get_connector_entry_cell(mask, plan, dir)

		if entry.x == -1:
			continue

		if entry.y <= best_y:
			continue
		
		best_dir = dir
		best_y = entry.y
		best_pos = entry
	
	return Root.new(best_dir, best_pos)

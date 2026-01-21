## Modulo usato per calcolare una lista di poszioni valide per il piazzamento di 
## oggetti, nemici, ecc... all'interno di una stanza.
##
## Questo piazzamento inteligente viene usato per calcolare tutte le poszioni utilizzabili
## all'interno di una stanza che sono sul pavimento.[br]
## Viene usato Voronoi che crea n centroidi [member voronoi_centers] 
## che vengono usati per generare delle aree organiche coerenti e separate.
class_name SmartPlacement extends Node

## Numero di centri che devono essere generati.
const VORONOI_CENTERS : int = 6

## Score per influenzare la scelta dei punti per piazzare le trappole: Corridoi
const SCORE_HALLWAY: float = 3.0
## Score per influenzare la scelta dei punti per piazzare le trappole: Dead-end
const SCORE_DEAD_END: float = 2.0
## Score per influenzare la scelta dei punti per piazzare le trappole: Aree aperte
const SCORE_OPEN_AREA: float = 0.5
## Score per influenzare la scelta dei punti per piazzare le trappole: Vicino a muri
const SCORE_NEAR_WALL: float = 1.0

## Classe di supporto utilizzata per legare le poszioni indiviudate a un valore rappresentsante
## l'importanza della suddetta poszione.
## Vedi [method _score_list].
class PositionScore:
	var position: Vector2i
	var score: float
	
	func _init(_position: Vector2i = Vector2i.ZERO, _score: float = 0.0) -> void:
		position = _position
		score = _score

## API: Dato una lista di posizioni [param all_positions] e un numero di posizioni minime da rispettare
## [param require_count] utilizza Voronoi per individuare un sottoinsieme di punti utilizzabili.
static func beautify(all_positions: Array[Vector2i], require_count: int = 1) -> Array[Vector2i]:
	if all_positions.is_empty():
		return []
	
	var centers : Array[Vector2i] = _generate_centers(all_positions)
	var regions : Dictionary[Vector2i, Array] = _compute_regions(all_positions, centers)
	var final_pass : Array[Vector2i] = _select_beautiful_points(regions, require_count, all_positions.size())
	
	return final_pass

## Metodo pubblico che presa una [param tilemap]
## restituscie un elenco di poszioni che si trovano sul terreno 
## oppure un array vuoto.
static func get_floor_tiles(tilemap: TileMapLayer) -> Array[Vector2i]:
	var floors: Array[Vector2i] = []
	var used : Array[Vector2i] = tilemap.get_used_cells()

	for cell in used:
		var above : Vector2i = cell + Vector2i(0, -1)
		var below : Vector2i = cell + Vector2i(0, 1)

		var has_tile : bool = tilemap.get_cell_tile_data(cell) != null
		var air_above : bool = tilemap.get_cell_tile_data(above) == null
		var support_below : bool = tilemap.get_cell_tile_data(below) != null

		# criterio perfetto per un punto spawnabile
		if has_tile and air_above and support_below:
			floors.append(cell)

	return floors

## Converte una cella di cordinate [param cell] locali in [param tilemap] in coordinata world (centro cella)
static func cell_to_world_position(
	tilemap: TileMapLayer,
	cell: Vector2i,
	offset: Vector2 = Vector2.ZERO
) -> Vector2:
	var pos: Vector2 = tilemap.to_global(tilemap.map_to_local(cell))
	return pos + offset

## Metodo pubblico che restiuscie tutte le posizioni interne [param inner_space] della stanza [param room]
## che si trovano sul pavimento, se non c'è ne sono restiusice un [Array] vuoto.
static func get_floor_air_cells(room: RoomTemplateMeta, inner_space: Array[Vector2i]) -> Array[Vector2i]:
	var tilemap: TileMapLayer = room.collision
	if tilemap == null:
		push_error("Room has no TileMapLayer named 'Collision'")
		return []
	
	var inner_lookup: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in inner_space: inner_lookup[cell] = true
	
	var floor_tiles: Array[Vector2i] = get_floor_tiles(tilemap)
	var out: Array[Vector2i] = []
	
	for floor_cell: Vector2i in floor_tiles:
		var air_cell: Vector2i = floor_cell + Vector2i.UP
		if inner_lookup.has(air_cell): out.append(air_cell)
	
	return out

## Metodo privato genera e restitusice una lista di centoridi utilizzando Voronoi
## a partire da una lista di poszioni: [param all_positions]. 
static func _generate_centers(all_positions: Array[Vector2i]) -> Array[Vector2i]:
	var centers : Array[Vector2i] = []
	for i in VORONOI_CENTERS:
		#centers.append(all_positions.pick_random())
		var idx : = Rng.rng.randi_range(0, all_positions.size() - 1)
		centers.append(all_positions[idx])
	return centers

## Metodo privato che associa ad aun centroide presente in [param centers] una lista di posizioni
## [param all_positions].
static func _compute_regions(all_positions: Array[Vector2i], centers: Array[Vector2i]) -> Dictionary[Vector2i, Array]:
	var regions : Dictionary[Vector2i, Array] = {}
	for c in centers:
		regions[c] = []

	for p in all_positions:
		var best : Vector2i = centers[0]
		var best_d : float = p.distance_to(best)

		for c in centers:
			var d : float = p.distance_to(c)
			if d < best_d:
				best = c
				best_d = d

		regions[best].append(p)

	return regions

## Metodo privato usato per selezionare un insieme di punti "esteticamente validi" 
## distribuiti tra più regioni [param regions].
##
## La funzione assegna a ciascuna regione un numero di punti proporzionale
## alla sua capacità [param total_capacity] (numero di punti disponibili), 
## garantendo che il totale dei punti selezionati sia esattamente [parma items_count].
##
## Viene restituito un insieme di punti selezionati.
static func _select_beautiful_points(
	regions: Dictionary[Vector2i, Array],
	items_count: int,
	total_capacity: int
) -> Array[Vector2i]:
	var picks: Array[Vector2i] = []
	var centers: Array[Vector2i] = regions.keys()

	## Calcolo la capacità di ciascuna regione
	var capacities: Array[int] = []
	for center in centers:
		var cap : int = regions[center].size()
		capacities.append(cap)

	## Primo pass: quota proporzionale base (floor)
	var counts: Array[int] = []
	var remainders: Array = []
	var assigned : int = 0

	for i in range(centers.size()):
		var cap : int = capacities[i]

		var ideal : float = float(items_count) * float(cap) / float(total_capacity)
		var base_count : int = int(floor(ideal))

		counts.append(base_count)
		assigned += base_count

		remainders.append({
			"i": i,
			"rem": ideal - float(base_count)
		})

	var remaining : int = items_count - assigned

	## Secondo pass: assegno +1 alle regioni coi resti più grandi
	if remaining > 0:
		remainders.sort_custom(func(a, b):
			return a["rem"] > b["rem"]  # dal resto più grande al più piccolo
		)

		for idx in range(min(remaining, remainders.size())):
			var i: int = remainders[idx]["i"]
			counts[i] += 1

	## Seleziono per ogni regione i punti più vicini al centro
	for i in range(centers.size()):
		var n_for_region : int = counts[i]
		if n_for_region <= 0:
			continue

		var center: Vector2i = centers[i]
		var region: Array[Vector2i] = []
		region.assign(regions[center].duplicate().map(func(p) -> Vector2i: return Vector2i(p.x, p.y)))
		

		if region.is_empty(): continue

		var chosen: Array[Vector2i] = _pick_spread_points(region, center, n_for_region)
		picks.append_array(chosen)
		
	return picks


# ===== Helper =====
static func _pick_spread_points(region: Array[Vector2i], center: Vector2i, count: int) -> Array[Vector2i]:
	var selected: Array[Vector2i] = []
	if region.is_empty() or count <= 0:
		return selected

	# Ordino per distanza dal centro
	region.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_to(center) < b.distance_to(center)
	)

	if count >= region.size():
		return region as Array[Vector2i]

	# 1) primo punto: il più vicino al centro
	selected.append(region[0])

	# 2) finché non ho abbastanza punti, scelgo quello più lontano dai già selezionati
	while selected.size() < count:
		var best_point: Vector2i = region[0]
		var best_score : float = -1.0

		for p in region:
			if p in selected:
				continue

			# distanza dal set dei già scelti: uso la distanza minima
			var min_dist_sq := INF
			for s in selected:
				var d_sq := float(p.distance_squared_to(s))
				if d_sq < min_dist_sq:
					min_dist_sq = d_sq

			if min_dist_sq > best_score:
				best_score = min_dist_sq
				best_point = p

		selected.append(best_point)

	return selected

static func compute_internal_cells(room: RoomTemplateMeta) -> Array[Vector2i]:
	var out : Array[Vector2i] = []
	var tilemap : TileMapLayer = room.collision 
	var entry : Vector2i = _find_entry_point(tilemap)
	var cells : Array[Vector2i] = _flood_internal_area(tilemap, entry)
	
	room.bounds = _compute_bounds(cells, tilemap)
	
	out = cells.duplicate()
	return out

static func _flood_internal_area(tilemap: TileMapLayer, start: Vector2i) -> Array[Vector2i]:
	var used_rect: Rect2i = tilemap.get_used_rect()
	
	var visited: = {}
	var queue: Array[Vector2i] = [start]
	var out: Array[Vector2i] = []

	while not queue.is_empty():
		var c = queue.pop_front()
		if visited.has(c): continue
		
		visited[c] = true
		
		# limiti della stanza
		if !used_rect.has_point(c): 
			continue

		# se è un muro → stop
		if tilemap.get_cell_tile_data(c) != null:
			continue

		out.append(c)
		
		queue.append(c + Vector2i.RIGHT)
		queue.append(c + Vector2i.LEFT)
		queue.append(c + Vector2i.UP)
		queue.append(c + Vector2i.DOWN)

	return out

static func _find_entry_point(tilemap: TileMapLayer) -> Vector2i:
	var used : Array[Vector2i] = tilemap.get_used_cells()
	if used.is_empty(): return Vector2i.ZERO
	
	var min_y = used[0].y
	var max_y = used[0].y

	for c in used:
		min_y = min(min_y, c.y)
		max_y = max(max_y, c.y)

	# cerca un tile vuoto subito sotto al tetto
	for y in range(min_y, max_y + 1):
		for c in used:
			var test = Vector2i(c.x, y)
			if tilemap.get_cell_tile_data(test) == null:
				return test

	return Vector2i.ZERO

static func _compute_bounds(internal_cells: Array[Vector2i], tilemap: TileMapLayer) -> Rect2:
	if internal_cells.is_empty():
		return Rect2()

	var min_c : Vector2i = internal_cells[0]
	var max_c : Vector2i = internal_cells[0]

	for c in internal_cells:
		min_c.x = min(min_c.x, c.x)
		min_c.y = min(min_c.y, c.y)
		max_c.x = max(max_c.x, c.x)
		max_c.y = max(max_c.y, c.y)

	var tile_size: Vector2i = tilemap.tile_set.tile_size

	# top-left in LOCALE tilemap
	var top_left_local : Vector2 = Vector2(min_c * tile_size)
	var size_local : Vector2 = Vector2((max_c - min_c + Vector2i.ONE) * tile_size)

	# converto in globale
	var top_left_global : Vector2 = tilemap.to_global(top_left_local)

	return Rect2(top_left_global, size_local)
	

static func _walkable_degree(cell: Vector2i, inner_lookup: Dictionary[Vector2i, bool]) -> int:
	var out : int = 0
	if inner_lookup.has(cell + Vector2i.UP): out += 1
	if inner_lookup.has(cell + Vector2i.DOWN): out += 1
	if inner_lookup.has(cell + Vector2i.LEFT): out += 1
	if inner_lookup.has(cell + Vector2i.RIGHT): out += 1
	return out

static func _is_near_wall(cell: Vector2i, inner_lookup: Dictionary[Vector2i, bool]) -> bool:
	return (
		!inner_lookup.has(cell + Vector2i.UP) or
		!inner_lookup.has(cell + Vector2i.DOWN) or
		!inner_lookup.has(cell + Vector2i.LEFT) or
		!inner_lookup.has(cell + Vector2i.RIGHT)
	)

static func score_list(
	room: RoomTemplateMeta,
	candidates: Array[Vector2i], 
	inner_lookup: Array[Vector2i],
	require_count: int,
	min_dist_from_entry: int = 5
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	
	if candidates.is_empty(): return out
	if inner_lookup.is_empty(): return out
	
	var tilemap : TileMapLayer = room.collision
	var entry: Vector2i = _find_entry_point(tilemap)
	
	var scored : Array[PositionScore] = []
	var lookup: Dictionary[Vector2i, bool] = {}
	for position in inner_lookup: lookup[position] = true
	
	for c in candidates:
		## fairness: evita subito l'entry
		if c.distance_to(entry) < min_dist_from_entry: continue
		
		var deg : int = _walkable_degree(c, lookup)
		var near_wall : bool = _is_near_wall(c, lookup)

		## Applicazione dello score
		var score : float = 0.0
		match deg:
			1: score += SCORE_DEAD_END
			2: score += SCORE_HALLWAY
			_: score += SCORE_OPEN_AREA

		if near_wall: score += SCORE_NEAR_WALL

		## Applicszione di randomnes
		score += float(Rng.rng.randf_range(0.0, 0.25))

		scored.append(PositionScore.new(c, score))

	if scored.is_empty(): return out
	
	scored.sort_custom(func (a: PositionScore, b: PositionScore): return a.score > b.score)
	
	var oversample : int = min(scored.size(), max(require_count * 4, require_count))
	for i in range(oversample): out.append(scored[i].position)
	
	return out

## Calcola le celle in rientranze verticali nei muri dalle celle interne della 
## stanza [param inner_space].
static func get_wall_recesses(inner_space: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if inner_space.is_empty(): return out
	
	var inner: Dictionary[Vector2i, bool] = {}
	for cell in inner_space: inner[cell] = true
	
	for cell in inner_space:
		if !inner.has(cell): continue
		
		var wall_left: bool = !inner.has(cell + Vector2i.LEFT)
		var wall_right: bool = !inner.has(cell + Vector2i.RIGHT)
		if !(wall_left or wall_right): continue
		
		if !inner.has(cell + Vector2i.DOWN): continue
		
		out.append(cell)
	
	return out

static func _is_shaft_cell(cell: Vector2i, inner: Dictionary[Vector2i, bool]) -> bool:
	if !inner.has(cell): return false
	var left_solid: bool = !inner.has(cell + Vector2i.LEFT)
	var right_solid: bool = !inner.has(cell + Vector2i.RIGHT)
	return left_solid and right_solid

static func _shaft_depth_from(cell: Vector2i, inner: Dictionary[Vector2i, bool], max_depth: int = 64) -> int:
	var depth: int = 0
	var cur: Vector2i = cell
	while depth < max_depth and _is_shaft_cell(cur, inner):
		depth += 1
		cur += Vector2i.DOWN
	return depth

static func get_pit_cells_local(
	inner_space: Array[Vector2i],
	min_delpth: int = 3,
	bottom_offset: int = 1
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if inner_space.is_empty(): return out
	
	var inner: Dictionary[Vector2i, bool] = {}
	for cell in inner_space: inner[cell] = true
	
	var seen: Dictionary[Vector2i, bool] = {}
	
	for cell in inner_space:
		if seen.has(cell): continue
		if !_is_shaft_cell(cell, inner): continue
		
		var depth: int = _shaft_depth_from(cell, inner)
		if depth < min_delpth: continue
		
		var bottom: Vector2i = cell + Vector2i.DOWN * (depth - 1)
		var target: Vector2i = bottom - Vector2i.DOWN * bottom_offset
		if inner.has(target): out.append(target)
		
		for d in depth: seen[cell + Vector2i.DOWN * d] = true
	
	return out

## Candidati per trappole di platforming: nicchie + pit.
static func get_trap_candidates_local(
	room: RoomTemplateMeta,
	inner_space: Array[Vector2i],
	pit_weight: float = 0.6, # percentuale desiderata di pit vs niche
	min_pit_depth: int = 3,
	pit_bottom_offset: int = 1
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if inner_space.is_empty(): return out

	var pits : Array[Vector2i] = get_pit_cells_local(inner_space, min_pit_depth, pit_bottom_offset)
	var niches : Array[Vector2i] = get_wall_recesses(inner_space)

	# se una delle due è vuota, ritorna l'altra
	if pits.is_empty(): return niches
	if niches.is_empty(): return pits

	# unione semplice evitando duplicati
	var seen: Dictionary[Vector2i, bool] = {}
	for p in pits:
		if seen.has(p): continue
		#if !seen.has(p):
		seen[p] = true
		out.append(p)
	for n in niches:
		if seen.has(n): continue

		seen[n] = true
		out.append(n)

	return out

## TODO: Attualmente inserisco delle funzioni qui che sono necessarie per 
## verificare che le trappole non vengano poszionate in punti che softloccano
## il player. Unavolta che il problema è stato risolto occorre creare un nuovo 
## file coerente con la modularità.

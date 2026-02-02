# ============================================================================
# SmartPlacement
# ============================================================================
## Modulo statico usato per calcolare posizioni valide e “belle” per lo spawn[br]
## di entità (decorazioni, item, nemici, trappole) all’interno di una stanza.[br]
##
## Responsabilità principali:[br]
## - Calcolo delle celle interne "aria" tramite flood fill (geometria valida).[br]
## - Cache di sottoinsiemi utili:[br]
##   - pavimento (floor air)[br]
##   - soffitto (ceiling air)[br]
##   - rientranze a parete (wall recess)[br]
##   - candidati trappole (pit + niches)[br]
## - Selezione di punti ben distribuiti tramite clustering stile Voronoi
##   (centroidi + regioni + pick “spread”).[br]
## - Utility per conversioni cella → world e per footprint orizzontale.[br]
##
## Convenzioni:[br]
## - Tutta la logica di selezione/filtraggio lavora in CELLE ([Vector2i]).[br]
## - La conversione in world-space è demandata a:[br]
##   [method cell_to_world_position].[br]
##
## Note:[br]
## - Questo modulo non gestisce conflitti tra sistemi (distanze, occupazione).
##   Quello è compito del [RoomPlacementManager].[br]
# ============================================================================
class_name SmartPlacement


# ---------------------------------------------------------------------------
# CONFIG / SCORE
# ---------------------------------------------------------------------------

## Numero di centroidi generati per il clustering “Voronoi-like”.
const VORONOI_CENTERS: int = 6

## Score per favorire celle in corridoi (grado 2 nel grafo 4-dir).
const SCORE_HALLWAY: float = 3.0
## Score per favorire dead-end (grado 1).
const SCORE_DEAD_END: float = 2.0
## Score per favorire aree aperte (grado >= 3).
const SCORE_OPEN_AREA: float = 0.5
## Score aggiuntivo per favorire celle adiacenti a muro.
const SCORE_NEAR_WALL: float = 1.0


# ---------------------------------------------------------------------------
# SUPPORT TYPES
# ---------------------------------------------------------------------------

## Associa una cella ad un valore di priorità (score).
## Usata da [method score_list].
class PositionScore:
	var position: Vector2i
	var score: float

	## [param _position] Cella candidata.[br]
	## [param _score] Punteggio assegnato alla cella.[br]
	func _init(_position: Vector2i = Vector2i.ZERO, _score: float = 0.0) -> void:
		position = _position
		score = _score


# ---------------------------------------------------------------------------
# PUBLIC API: BEAUTIFY
# ---------------------------------------------------------------------------

## Seleziona un sottoinsieme di punti “ben distribuiti” da un set di posizioni.[br]
## Implementazione:[br]
## 1) genera centroidi ([method _generate_centers])[br]
## 2) crea regioni per prossimità ([method _compute_regions])[br]
## 3) assegna quote e seleziona punti “spread” ([method _select_beautiful_points])[br]
##
## [param all_positions] Lista di celle candidate.[br]
## [param rng] Generatore randomico basato sul seed del livello.[br]
## [param require_count] Numero minimo di punti desiderati.[br]
##
## @return Array di celle selezionate (dimensione ≈ require_count).[br]
static func beautify(all_positions: Array[Vector2i], rng: RandomNumberGenerator, require_count: int = 1) -> Array[Vector2i]:
	if all_positions.is_empty():
		return []

	var centers: Array[Vector2i] = _generate_centers(all_positions, rng)
	var regions: Dictionary[Vector2i, Array] = _compute_regions(all_positions, centers)
	var final_pass: Array[Vector2i] = _select_beautiful_points(regions, require_count, all_positions.size())

	return final_pass


# ---------------------------------------------------------------------------
# PUBLIC API: GEOMETRY CACHES
# ---------------------------------------------------------------------------

## Restituisce le celle interne “aria” che hanno un solido sotto (pavimento).[br]
##
## [param room] Stanza da cui leggere tilemap e celle interne.[br]
##
## @return Array di celle candidate per spawn a terra.
static func get_floor_air_cells(room: RoomTemplateMeta) -> Array[Vector2i]:
	var tilemap: TileMapLayer = room.collision
	var inner_lookup: Dictionary[Vector2i, bool] = room.placement.spawnable_cells
	var out: Array[Vector2i] = []

	if inner_lookup.is_empty():
		return out

	if tilemap == null:
		push_error("Room has no TileMapLayer named 'Collision'")
		return out

	for cell: Vector2i in inner_lookup.keys():
		## Guard: la cella deve essere aria
		if tilemap.get_cell_tile_data(cell) != null:
			continue

		## Guard: sotto deve esserci un tile solido
		var below: Vector2i = cell + Vector2i.DOWN
		if tilemap.get_cell_tile_data(below) == null:
			continue

		out.append(cell)

	return out


## Calcola tutte le celle interne “aria” tramite flood fill partendo da un entry point.[br]
## Aggiorna anche [member room.bounds] in coordinate globali.[br]
##
## [param room] Stanza su cui calcolare area interna e bounds.[br]
##
## @return Array di celle interne “aria”.[br]
static func compute_internal_cells(room: RoomTemplateMeta) -> Array[Vector2i]:
	var out: Array[Vector2i] = []

	var tilemap: TileMapLayer = room.collision
	if tilemap == null:
		push_error("Room has no TileMapLayer named 'Collision'")
		return out

	var entry_cell: Vector2i = _find_entry_point(tilemap)
	if entry_cell == Vector2i.ZERO:
		return out

	var internal_cells: Array[Vector2i] = _flood_internal_area(tilemap, entry_cell)
	if internal_cells.is_empty():
		return out

	room.bounds = _compute_bounds(internal_cells, tilemap)

	out = internal_cells.duplicate()
	return out


# ---------------------------------------------------------------------------
# COORD CONVERSION
# ---------------------------------------------------------------------------

## Converte una cella locale della TileMap in posizione world (centro cella),
## con offset opzionale.[br]
##
## [param tilemap] TileMapLayer di riferimento.[br]
## [param cell] Cella locale da convertire.[br]
## [param offset] Offset world-space da sommare al centro cella.[br]
##
## @return Posizione globale risultante.[br]
static func cell_to_world_position(
	tilemap: TileMapLayer,
	cell: Vector2i,
	offset: Vector2 = Vector2.ZERO
) -> Vector2:
	var pos: Vector2 = tilemap.to_global(tilemap.map_to_local(cell))
	return pos + offset


# ---------------------------------------------------------------------------
# VORONOI CORE
# ---------------------------------------------------------------------------

## Genera una lista di centroidi casuali pescati da [param all_positions].[br]
##
## [param all_positions] Set di posizioni da cui scegliere i centroidi.[br]
## [param rng] Generatore randomico basato sul seed del livello.[br]
##
## @return Array di centroidi.[br]
static func _generate_centers(all_positions: Array[Vector2i], rng: RandomNumberGenerator) -> Array[Vector2i]:
	var centers: Array[Vector2i] = []

	for i in VORONOI_CENTERS:
		var idx: int = rng.randi_range(0, all_positions.size() - 1)
		centers.append(all_positions[idx])

	return centers


## Crea regioni assegnando ogni punto al centroide più vicino.[br]
##
## [param all_positions] Punti totali da distribuire nelle regioni.[br]
## [param centers] Centroidi di riferimento.[br]
##
## @return Dizionario center -> lista di punti assegnati.[br]
static func _compute_regions(
	all_positions: Array[Vector2i],
	centers: Array[Vector2i]
) -> Dictionary[Vector2i, Array]:
	var regions: Dictionary[Vector2i, Array] = {}

	for c in centers:
		regions[c] = []

	for p in all_positions:
		var best: Vector2i = centers[0]
		var best_d: float = p.distance_to(best)

		for c in centers:
			var d: float = p.distance_to(c)
			if d < best_d:
				best = c
				best_d = d

		regions[best].append(p)

	return regions


## Seleziona un insieme di punti “belli” distribuiti tra le regioni.[br]
##
## Strategia:[br]
## - assegna a ciascuna regione una quota proporzionale alla sua capacità[br]
## - poi seleziona punti spread nella singola regione.[br]
##
## [param regions] Dizionario center -> lista di punti.[br]
## [param items_count] Numero totale di punti richiesti.[br]
## [param total_capacity] Numero totale di punti disponibili (tutte le regioni).[br]
##
## @return Array di punti selezionati.[br]
static func _select_beautiful_points(
	regions: Dictionary[Vector2i, Array],
	items_count: int,
	total_capacity: int
) -> Array[Vector2i]:
	var picks: Array[Vector2i] = []
	var centers: Array[Vector2i] = regions.keys()

	## Capacità per regione
	var capacities: Array[int] = []
	for center in centers:
		capacities.append(regions[center].size())

	## Primo pass: quota base (floor)
	var counts: Array[int] = []
	var remainders: Array = []
	var assigned: int = 0

	for i in range(centers.size()):
		var cap: int = capacities[i]

		var ideal: float = float(items_count) * float(cap) / float(total_capacity)
		var base_count: int = int(floor(ideal))

		counts.append(base_count)
		assigned += base_count

		remainders.append({"i": i, "rem": ideal - float(base_count)})

	var remaining: int = items_count - assigned

	## Secondo pass: assegno +1 ai resti più grandi
	if remaining > 0:
		remainders.sort_custom(func(a, b):
			return a["rem"] > b["rem"]
		)

		for idx in range(min(remaining, remainders.size())):
			var i: int = remainders[idx]["i"]
			counts[i] += 1

	## Pick nella singola regione
	for i in range(centers.size()):
		var n_for_region: int = counts[i]
		if n_for_region <= 0:
			continue

		var center: Vector2i = centers[i]
		var region: Array[Vector2i] = []
		region.assign(regions[center].duplicate().map(func(p) -> Vector2i:
			return Vector2i(p.x, p.y)
		))

		if region.is_empty():
			continue

		var chosen: Array[Vector2i] = _pick_spread_points(region, center, n_for_region)
		picks.append_array(chosen)

	return picks


## Sceglie [param count] punti in [param region] cercando una distribuzione uniforme.
## Strategia:
## 1) primo punto vicino al centro
## 2) poi scegli iterativamente il punto che massimizza la distanza minima
##    rispetto ai già selezionati.
##
## [param region] Lista di punti della regione.
## [param center] Centroide della regione (riferimento).
## [param count] Numero di punti da selezionare.
##
## @return Array di punti selezionati.
static func _pick_spread_points(region: Array[Vector2i], center: Vector2i, count: int) -> Array[Vector2i]:
	var selected: Array[Vector2i] = []
	if region.is_empty() or count <= 0:
		return selected

	region.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_to(center) < b.distance_to(center)
	)

	if count >= region.size():
		return region as Array[Vector2i]

	selected.append(region[0])

	while selected.size() < count:
		var best_point: Vector2i = region[0]
		var best_score: float = -1.0

		for p in region:
			if p in selected:
				continue

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


# ---------------------------------------------------------------------------
# INTERNAL AREA
# ---------------------------------------------------------------------------

## Flood fill interno: parte da [param start] e visita solo celle entro l’area usata
## della TileMap, fermandosi su celle solide.[br]
##
## [param tilemap] TileMapLayer su cui eseguire il flood fill.[br]
## [param start] Cella di partenza (deve essere aria).[br]
##
## @return Array di celle interne “aria”.[br]
static func _flood_internal_area(tilemap: TileMapLayer, start: Vector2i) -> Array[Vector2i]:
	var used_rect: Rect2i = tilemap.get_used_rect()

	var visited: Dictionary[Vector2i, bool] = {}
	var queue: Array[Vector2i] = [start]
	var out: Array[Vector2i] = []

	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()

		if visited.has(cell):
			continue
		visited[cell] = true

		## Guard: resta dentro i limiti della stanza
		if not used_rect.has_point(cell):
			continue

		## Guard: se è solido non è interno
		if tilemap.get_cell_tile_data(cell) != null:
			continue

		out.append(cell)

		queue.append(cell + Vector2i.RIGHT)
		queue.append(cell + Vector2i.LEFT)
		queue.append(cell + Vector2i.UP)
		queue.append(cell + Vector2i.DOWN)

	return out


## Trova un entry point per il flood fill interno.[br]
## Strategia: scansiona dall’alto verso il basso e cerca una cella vuota.[br]
##
## [param tilemap] TileMapLayer su cui cercare l’entry.[br]
##
## @return Cella di entry oppure [constant Vector2i.ZERO] se non trovata.[br]
static func _find_entry_point(tilemap: TileMapLayer) -> Vector2i:
	var used: Array[Vector2i] = tilemap.get_used_cells()
	if used.is_empty():
		return Vector2i.ZERO

	var min_y := used[0].y
	var max_y := used[0].y

	for c in used:
		min_y = min(min_y, c.y)
		max_y = max(max_y, c.y)

	for y in range(min_y, max_y + 1):
		for c in used:
			var test := Vector2i(c.x, y)
			if tilemap.get_cell_tile_data(test) == null:
				return test

	return Vector2i.ZERO


## Calcola i bounds globali di un set di celle interne.[br]
##
## [param internal_cells] Celle interne “aria”.[br]
## [param tilemap] TileMapLayer di riferimento (serve per tile_size e transform).[br]
##
## @return Rettangolo in world-space che racchiude l’area interna.[br]
static func _compute_bounds(internal_cells: Array[Vector2i], tilemap: TileMapLayer) -> Rect2:
	if internal_cells.is_empty():
		return Rect2()

	var min_c: Vector2i = internal_cells[0]
	var max_c: Vector2i = internal_cells[0]

	for c in internal_cells:
		min_c.x = min(min_c.x, c.x)
		min_c.y = min(min_c.y, c.y)
		max_c.x = max(max_c.x, c.x)
		max_c.y = max(max_c.y, c.y)

	var tile_size: Vector2i = tilemap.tile_set.tile_size

	var top_left_local: Vector2 = Vector2(min_c * tile_size)
	var size_local: Vector2 = Vector2((max_c - min_c + Vector2i.ONE) * tile_size)

	var top_left_global: Vector2 = tilemap.to_global(top_left_local)

	return Rect2(top_left_global, size_local)


# ---------------------------------------------------------------------------
# SCORING / FAIRNESS
# ---------------------------------------------------------------------------

## Calcola il grado di camminabilità in 4-dir:[br]
## numero di vicini che appartengono a [param inner_lookup].[br]
##
## [param cell] Cella da valutare.[br]
## [param inner_lookup] Set di celle interne (lookup O(1)).[br]
##
## @return Numero di adiacenze interne (0..4).[br]
static func _walkable_degree(cell: Vector2i, inner_lookup: Dictionary[Vector2i, bool]) -> int:
	var out: int = 0

	if inner_lookup.has(cell + Vector2i.UP):
		out += 1
	if inner_lookup.has(cell + Vector2i.DOWN):
		out += 1
	if inner_lookup.has(cell + Vector2i.LEFT):
		out += 1
	if inner_lookup.has(cell + Vector2i.RIGHT):
		out += 1

	return out


## Ritorna true se la cella è adiacente ad un “muro” (cioè almeno un vicino 4-dir
## non è interno).[br]
##
## [param cell] Cella da valutare.[br]
## [param inner_lookup] Set di celle interne (lookup O(1)).[br]
static func _is_near_wall(cell: Vector2i, inner_lookup: Dictionary[Vector2i, bool]) -> bool:
	if not inner_lookup.has(cell + Vector2i.UP):
		return true
	if not inner_lookup.has(cell + Vector2i.DOWN):
		return true
	if not inner_lookup.has(cell + Vector2i.LEFT):
		return true
	if not inner_lookup.has(cell + Vector2i.RIGHT):
		return true

	return false


## Valuta e ordina una lista di candidati applicando punteggi topologici.[br]
##
## Note:[br]
## - Evita un’area vicino all’entry per fairness ([param min_dist_from_entry]).[br]
## - Oversampling: restituisce ~ require_count * 4 per lasciare margine a filtri successivi.[br]
##
## [param room] Stanza di riferimento (tilemap + celle interne).[br]
## [param candidates] Celle candidate da valutare.[br]
## [param require_count] Numero base di punti richiesti (per calcolo oversampling).[br]
## [param rng] Generatore randomico basato sul seed del livello.[br]
## [param min_dist_from_entry] Distanza minima dall’entry in celle.[br]
##
## @return Lista ordinata di celle (dal punteggio più alto).[br]
static func score_list(
	room: RoomTemplateMeta,
	candidates: Array[Vector2i],
	require_count: int,
	rng: RandomNumberGenerator,
	min_dist_from_entry: int = 5
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var tilemap: TileMapLayer = room.collision
	var inner_lookup: Dictionary[Vector2i, bool] = room.placement.spawnable_cells

	if candidates.is_empty():
		return out
	if require_count <= 0:
		return out
	if tilemap == null:
		return out
	if inner_lookup.is_empty():
		return out

	var entry_cell: Vector2i = _find_entry_point(tilemap)
	var scored_positions: Array[PositionScore] = []

	for candidate_cell in candidates:
		## Guard: fairness - evita subito l’entry
		if candidate_cell.distance_to(entry_cell) < min_dist_from_entry:
			continue

		var deg: int = _walkable_degree(candidate_cell, inner_lookup)
		var near_wall: bool = _is_near_wall(candidate_cell, inner_lookup)

		var score: float = 0.0
		match deg:
			1:
				score += SCORE_DEAD_END
			2:
				score += SCORE_HALLWAY
			_:
				score += SCORE_OPEN_AREA

		if near_wall:
			score += SCORE_NEAR_WALL

		## Randomness leggero per evitare pattern rigidi
		score += float(rng.randf_range(0.0, 0.25))

		scored_positions.append(PositionScore.new(candidate_cell, score))

	if scored_positions.is_empty():
		return out

	scored_positions.sort_custom(func(a: PositionScore, b: PositionScore) -> bool:
		return a.score > b.score
	)

	var oversample_count: int = min(
		scored_positions.size(),
		max(require_count * 4, require_count)
	)

	for i in range(oversample_count):
		out.append(scored_positions[i].position)

	return out


# ---------------------------------------------------------------------------
# TRAP CANDIDATES
# ---------------------------------------------------------------------------

## Calcola celle interne in rientranze a muro (“nicchie”):[br]
## - cella interna[br]
## - con muro a sinistra o destra[br]
## - con supporto sotto (interno)[br]
##
## [param room] Stanza di riferimento.[br]
##
## @return Array di celle nicchia.[br]
static func get_wall_recesses(room: RoomTemplateMeta) -> Array[Vector2i]:
	var inner_lookup: Dictionary[Vector2i, bool] = room.placement.spawnable_cells
	var out: Array[Vector2i] = []

	for cell: Vector2i in inner_lookup.keys():
		var wall_left: bool = not inner_lookup.has(cell + Vector2i.LEFT)
		var wall_right: bool = not inner_lookup.has(cell + Vector2i.RIGHT)

		if not (wall_left or wall_right):
			continue
		if not inner_lookup.has(cell + Vector2i.DOWN):
			continue

		out.append(cell)

	return out


## Ritorna true se [param cell] è una cella di shaft/pit:[br]
## - interna[br]
## - chiusa da solidi su entrambi i lati (non interno a sx e dx).[br]
##
## [param cell] Cella da verificare.[br]
## [param inner_lookup] Set di celle interne.[br]
static func _is_shaft_cell(cell: Vector2i, inner_lookup: Dictionary[Vector2i, bool]) -> bool:
	if not inner_lookup.has(cell):
		return false

	var left_solid: bool = not inner_lookup.has(cell + Vector2i.LEFT)
	var right_solid: bool = not inner_lookup.has(cell + Vector2i.RIGHT)

	return left_solid and right_solid


## Calcola la profondità del pit partendo da [param cell] andando verso il basso
## finché resta shaft.[br][br]
##
## [param cell] Cella di partenza.[br][br]
## [param inner_lookup] Set di celle interne.[br][br]
## [param max_depth] Limite di sicurezza della scansione.[br][br]
##
## @return Profondità in celle.[br][br]
static func _shaft_depth_from(
	cell: Vector2i,
	inner_lookup: Dictionary[Vector2i, bool],
	max_depth: int = 64
) -> int:
	var depth: int = 0
	var cur: Vector2i = cell

	while depth < max_depth and _is_shaft_cell(cur, inner_lookup):
		depth += 1
		cur += Vector2i.DOWN

	return depth


## Estrae celle target nei pit abbastanza profondi.[br]
## Ritorna una cella verso il fondo, con offset configurabile.[br]
##
## [param room] Stanza di riferimento.[br]
## [param min_depth] Profondità minima per considerare un pit valido.[br]
## [param bottom_offset] Offset verso l’alto dal fondo (1 = una cella sopra).[br]
##
## @return Array di celle pit target.[br]
static func get_pit_cells_local(
	room: RoomTemplateMeta,
	min_depth: int = 3,
	bottom_offset: int = 1
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []

	var inner_lookup: Dictionary[Vector2i, bool] = room.placement.spawnable_cells
	if inner_lookup.is_empty():
		return out

	var seen: Dictionary[Vector2i, bool] = {}

	for cell: Vector2i in inner_lookup.keys():
		if seen.has(cell):
			continue
		if not _is_shaft_cell(cell, inner_lookup):
			continue

		var depth: int = _shaft_depth_from(cell, inner_lookup)
		if depth < min_depth:
			continue

		var bottom: Vector2i = cell + Vector2i.DOWN * (depth - 1)
		var target: Vector2i = bottom - Vector2i.DOWN * bottom_offset

		if inner_lookup.has(target):
			out.append(target)

		for d: int in range(depth):
			seen[cell + Vector2i.DOWN * d] = true

	return out


## Combina pit + niches per ottenere un set di candidati trappole.[br]
##
## [param room] Stanza di riferimento.[br]
##
## @return Array unico di celle candidate (senza duplicati).[br]
static func get_trap_candidates(room: RoomTemplateMeta) -> Array[Vector2i]:
	var pits: Array[Vector2i] = get_pit_cells_local(room)
	var niches: Array[Vector2i] = get_wall_recesses(room)

	if pits.is_empty():
		return niches
	if niches.is_empty():
		return pits

	var out: Array[Vector2i] = []
	var seen: Dictionary[Vector2i, bool] = {}

	for p: Vector2i in pits:
		if seen.has(p):
			continue
		seen[p] = true
		out.append(p)

	for n: Vector2i in niches:
		if seen.has(n):
			continue
		seen[n] = true
		out.append(n)

	return out


# ---------------------------------------------------------------------------
# CEILING DECOR
# ---------------------------------------------------------------------------

## Calcola celle interne “aria” con un solido sopra (soffitto).[br]
##
## [param room] Stanza di riferimento.[br]
##
## @return Array di celle candidate per decorazioni CEILING.[br]
static func get_ceiling_air_cells(room: RoomTemplateMeta) -> Array[Vector2i]:
	var tilemap: TileMapLayer = room.collision
	var inner_lookup: Dictionary[Vector2i, bool] = room.placement.spawnable_cells
	var out: Array[Vector2i] = []

	if tilemap == null:
		push_error("Room has no TileMapLayer named 'Collision'")
		return out

	for cell: Vector2i in inner_lookup.keys():
		if tilemap.get_cell_tile_data(cell) != null:
			continue

		var above: Vector2i = cell + Vector2i.UP
		if tilemap.get_cell_tile_data(above) == null:
			continue

		out.append(cell)

	return out


# ---------------------------------------------------------------------------
# FOOTPRINT FILTER
# ---------------------------------------------------------------------------

## Restituisce le celle occupate orizzontalmente da un footprint centrato su [param center].[br]
## Nota deterministica:[br]
## - se [param footprint] è pari, assegna una cella in più a destra.[br]
##
## [param center] Cella centrale.[br]
## [param footprint] Numero totale di celle occupate orizzontalmente (>= 1).[br]
##
## @return Array ordinato di celle occupate.[br]
static func get_footprint_cells(center: Vector2i, footprint: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	footprint = max(1, footprint)

	if footprint == 1:
		result.append(center)
		return result

	var left_count := (footprint - 1) / 2
	var right_count := footprint - 1 - left_count

	for dx in range(-left_count, right_count + 1):
		result.append(center + Vector2i(dx, 0))

	return result


## Filtra candidati mantenendo solo quelli piazzabili a terra con footprint orizzontale.[br]
## Requisiti:[br]
## - tutte le celle footprint sono interne[br]
## - sono aria (nessun tile)[br]
## - sotto ogni cella footprint c’è solido[br]
##
## [param room] Stanza di riferimento.[br]
## [param candidates] Celle candidate da filtrare.[br]
## [param footprint] Footprint orizzontale in celle (>= 1).[br]
##
## @return Array filtrato di celle center valide.[br]
static func filter_candidates_by_footprint_ground(
	room: RoomTemplateMeta,
	candidates: Array[Vector2i],
	footprint: int
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	if candidates.is_empty():
		return result

	var tilemap: TileMapLayer = room.collision
	if tilemap == null:
		return result

	var inner_lookup: Dictionary[Vector2i, bool] = room.placement.spawnable_cells
	if inner_lookup.is_empty():
		return result

	for center_cell: Vector2i in candidates:
		var footprint_cells: Array[Vector2i] = get_footprint_cells(center_cell, footprint)

		var is_valid: bool = true
		for cell: Vector2i in footprint_cells:
			if not inner_lookup.has(cell):
				is_valid = false
				break
			if tilemap.get_cell_tile_data(cell) != null:
				is_valid = false
				break
			var below_cell: Vector2i = cell + Vector2i.DOWN
			if tilemap.get_cell_tile_data(below_cell) == null:
				is_valid = false
				break

		if not is_valid:
			continue

		result.append(center_cell)

	return result


## Filtra candidati mantenendo solo quelli piazzabili a soffitto con footprint orizzontale.[br]
## Requisiti:[br]
## - tutte le celle footprint sono interne[br]
## - sono aria (nessun tile)[br]
## - sopra ogni cella footprint c’è solido[br]
##
## [param room] Stanza di riferimento.[br]
## [param candidates] Celle candidate da filtrare.[br]
## [param footprint] Footprint orizzontale in celle (>= 1).[br]
##
## @return Array filtrato di celle center valide.[br]
static func filter_candidates_by_footprint_ceiling(
	room: RoomTemplateMeta,
	candidates: Array[Vector2i],
	footprint: int
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []

	var tilemap: TileMapLayer = room.collision
	if tilemap == null:
		return out

	var inner_lookup: Dictionary[Vector2i, bool] = room.placement.spawnable_cells
	if inner_lookup.is_empty():
		return out

	for center: Vector2i in candidates:
		var cells: Array[Vector2i] = get_footprint_cells(center, footprint)

		var ok: bool = true
		for cell: Vector2i in cells:
			if not inner_lookup.has(cell):
				ok = false
				break
			if tilemap.get_cell_tile_data(cell) != null:
				ok = false
				break
			var above: Vector2i = cell + Vector2i.UP
			if tilemap.get_cell_tile_data(above) == null:
				ok = false
				break

		if not ok:
			continue

		out.append(center)

	return out


## TODO:
## Attualmente qui convivono anche funzioni necessarie per prevenire soft-lock
## nella logica trappole. Una volta stabilizzata la policy, spostare tali metodi
## in un modulo dedicato (es. TrapPlacementPolicy) per coerenza e modularità.

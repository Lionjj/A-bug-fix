## Modulo di utilità utilizzato per verificare che le trappole non creino un
## soft-lock che impedisca al giocatore di proseguire nel gioco.
class_name TrapPlcacementPolicy

## raggio (in celle) attorno alle walkable da proteggere 
## (1 consigliato, 2 se vuoi più safe);
const NEAR_WALKABLE_RADIUS: int = 1

## Margine extra (in tile) da aggiungere alla stima dell'altezza di salto.
## Serve a compensare:
## - wall jump
## - collision shape
## - arrotondamenti fisici
## - input buffering
const WALL_JUMP_MARGIN_TILES: int = 1

## Limite massimo di profondità ricorsiva consentita nella DFS.
## Valori tipici sicuri: 2048 o 4096 (dipende da piattaforma).
const TARJAN_MAX_RECURSION_DEPTH: int = 2048

## Stato interno per l'algoritmo di Tarjan.
## Contiene tutte le strutture dati mutate durante la DFS.
class TarjanState:
	var discovery_time: Dictionary[Vector2i, int] = {}
	var lowlink: Dictionary[Vector2i, int] = {}
	var parent: Dictionary[Vector2i, Vector2i] = {}
	var articulation_points: Dictionary[Vector2i, bool] = {}
	
	var time_counter: int = 0
	var recursion_depth: int = 0
	var aborted: bool = false

## Calcola l'altezza teorica massima di salto in TILE (full jump) 
## usando fisica base.
## - [param jump_velocity_abs]: valore assoluto della velocità iniziale 
## del salto;
## - [param gravity]: gravità in px/s^2;
## - [param tile_size_y]: altezza del tile in px;
static func compute_jump_height_tiles(
	jump_velocity_abs: float, 
	gravity: float, 
	tile_size_y: int
) -> float:
	if gravity <= 0.0 or tile_size_y <= 0: return 0.0
	
	var h_px : float = (jump_velocity_abs * jump_velocity_abs) / (2.0 * gravity)
	return h_px / float(tile_size_y)

## TODO: anziche costruire ongi volta un Dictionary[Vector2i, bool] converrebbe
## Converrebbe che nel SmartPlacement sia inizializzato direttamente un 
## dizionario di questo tipo anziche una lista.

## Converte un Array di celle in un set (Dictionary) per lookup O(1).
## - cells: lista di celle
## Return: Dictionary[Vector2i, bool] usabile come set
static func _to_set(cells: Array[Vector2i]) -> Dictionary[Vector2i, bool]:
	var s: Dictionary[Vector2i, bool] = {}
	for c in cells:
		s[c] = true
	return s

## Costruisce un insieme di celle "protette" dove NON è permesso piazzare trappole.
## Protegge:
## A) zone vicine alle walkable (passaggi, atterraggi, step)
## B) pareti adiacenti alle walkable utili al wall-jump (per evitare soft-lock)
## C) chokepoints (articulation points) del grafo di navigazione (per evitare blocchi strutturali)
##
## [param inner_cells] celle interne della stanza (aria), coordinate locali
## [param walkable_cells] celle attraversabili dal player (aria sopra pavimento), coordinate locali
## [param wall_reach_tiles] quanti tile di parete proteggere in verticale (tipico: ceil(jump_height_tiles) + margin)
## [param near_walkable_radius] raggio (in celle) attorno alle walkable da proteggere (1 consigliato, 2 più safe)
## @return Dictionary[Vector2i, bool] set di celle vietate (protette)
static func build_protected_cells(
	inner_cells: Array[Vector2i],
	walkable_cells: Array[Vector2i],
	wall_reach_tiles: int,
	near_walkable_radius: int = NEAR_WALKABLE_RADIUS
) -> Dictionary[Vector2i, bool]:

	var protected: Dictionary[Vector2i, bool] = {}

	# Set per lookup O(1)
	var inner_set: Dictionary[Vector2i, bool] = _to_set(inner_cells)
	
	## Proteggi vicino le are calpestabili
	_protect_near_walkables(protected, walkable_cells, near_walkable_radius)
	
	## Proteggi i wall-jump
	_protect_walljump_walls(
		walkable_cells,
		inner_set,
		protected,
		wall_reach_tiles,
		true # corner_protect (spigoli)
	)
	
	## Proteggi eventuali strettoie
	var walkable_set: Dictionary[Vector2i, bool] = _to_set(walkable_cells)
	_protect_chokepoints(protected, walkable_set, true) # true = buffer neighbors4

	return protected

static func _protect_near_walkables(
	protected: Dictionary[Vector2i, bool],
	walkable_cells: Array[Vector2i],
	radius: int
) -> void:
	for w in walkable_cells:
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				protected[w + Vector2i(dx, dy)] = true
				

## Filtra una lista di celle rimuovendo quelle presenti nel set "blocked".
## - [param candidates]: celle candidate;
## - [param blocked]: set di celle vietate
static func filter_not_blocked(
	candidates: Array[Vector2i], 
	blocked: Dictionary[Vector2i, bool]
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in candidates:
		if blocked.has(c):
			continue
		out.append(c)
	return out

## Restituisce i 4 vicini ortogonali (griglia 4-connessa) di una cella.
##
## Usato per costruire un grafo implicito su griglia:
## ogni cella è un nodo, collegato solo a sinistra, destra, sopra e sotto.
##
## [param c] cella di riferimento (coordinate tile locali)
## @return Array di celle adiacenti (LEFT, RIGHT, UP, DOWN)
static func _neighbors4(c: Vector2i) -> Array[Vector2i]:
	return [
		c + Vector2i.LEFT,
		c + Vector2i.RIGHT,
		c + Vector2i.UP,
		c + Vector2i.DOWN
	]

## Calcola i chokepoints con Tarjan (safe).
## Se la DFS supera TARJAN_MAX_RECURSION_DEPTH, abortisce e restituisce un set vuoto
## (o puoi mettere un fallback euristico).
##
## [param nodes] set di celle attraversabili (Dictionary usato come Set)
## @return Dictionary[Vector2i, bool] articulation points (può essere vuoto se abortito)
static func compute_articulation_points(nodes: Dictionary[Vector2i, bool]) -> Dictionary[Vector2i, bool]:
	var state := TarjanState.new()

	for cell in nodes.keys():
		if state.aborted:
			break
		if !state.discovery_time.has(cell):
			_tarjan_dfs_safe(cell, nodes, state)

	if state.aborted:
		# Fail-safe: non crashare mai. In debug lo segnali.
		push_warning("Tarjan aborted: recursion depth exceeded. Returned empty chokepoints set.")
		# Fallback semplice (opzionale): return _fallback_chokepoints(nodes)
		return _fallback_chokepoints(nodes)

	return state.articulation_points


## DFS ricorsiva per Tarjan con guardrail sulla profondità.
##
## [param current] cella corrente (nodo) visitata dalla DFS
## [param nodes] set di celle attraversabili (Dictionary usato come Set)
## [param state] stato mutabile dell'algoritmo (TarjanState)
static func _tarjan_dfs_safe(current: Vector2i, nodes: Dictionary[Vector2i, bool], state: TarjanState) -> void:
	if state.aborted:
		return

	state.recursion_depth += 1
	if state.recursion_depth > TARJAN_MAX_RECURSION_DEPTH:
		state.aborted = true
		state.recursion_depth -= 1
		return

	state.time_counter += 1
	state.discovery_time[current] = state.time_counter
	state.lowlink[current] = state.time_counter

	var children_count := 0

	for neighbor in _neighbors4(current):
		if state.aborted:
			break
		if !nodes.has(neighbor):
			continue

		if !state.discovery_time.has(neighbor):
			state.parent[neighbor] = current
			children_count += 1

			_tarjan_dfs_safe(neighbor, nodes, state)

			if state.aborted:
				break

			state.lowlink[current] = min(state.lowlink[current], state.lowlink[neighbor])

			# Root con più di un figlio => articulation
			if !state.parent.has(current) and children_count > 1:
				state.articulation_points[current] = true

			# Non-root che separa
			if state.parent.has(current) and state.lowlink[neighbor] >= state.discovery_time[current]:
				state.articulation_points[current] = true

		# Back-edge (non verso parent)
		elif state.parent.get(current, Vector2i(-999999, -999999)) != neighbor:
			state.lowlink[current] = min(state.lowlink[current], state.discovery_time[neighbor])

	state.recursion_depth -= 1

## Fallback: marca come "critiche" le celle con pochi vicini (corridoi/stretti).
## Non è Tarjan, ma è una rete di sicurezza.
##
## [param nodes] set di celle attraversabili
## @return Dictionary[Vector2i, bool] celle critiche euristiche
static func _fallback_chokepoints(nodes: Dictionary[Vector2i, bool]) -> Dictionary[Vector2i, bool]:
	var out: Dictionary[Vector2i, bool] = {}

	for c in nodes.keys():
		var deg := 0
		for n in _neighbors4(c):
			if nodes.has(n):
				deg += 1
		if deg <= 2:
			out[c] = true

	return out

static func _protect_chokepoints(
	protected: Dictionary[Vector2i, bool],
	walkable_set: Dictionary[Vector2i, bool],
	add_neighbors4_buffer: bool = true
) -> void:
	var chokepoints: Dictionary[Vector2i, bool] = compute_articulation_points(walkable_set)

	for c in chokepoints.keys():
		protected[c] = true

		if add_neighbors4_buffer:
			for n in _neighbors4(c):
				protected[n] = true

## Entry point modulare: protezione wall-jump.
## - corner_protect: se true, protegge anche lo spigolo (muro+UP)
## - extra_offsets: ulteriori offset (es. diagonali) se vuoi più safe
static func _protect_walljump_walls(
	walkable_cells: Array[Vector2i],
	inner_set: Dictionary[Vector2i, bool],
	protected: Dictionary[Vector2i, bool],
	wall_reach_tiles: int,
	corner_protect: bool = true,
	extra_offsets: Array[Vector2i] = []
) -> void:
	var wall_offsets: Array[Vector2i] = []
	
	if corner_protect: wall_offsets.append(Vector2i.UP)
	
	for offset in extra_offsets:
		wall_offsets.append(offset)
	
	for walkable in walkable_cells:
		for wall_reach_tile in range(0, wall_reach_tiles + 1):
			var air: Vector2i = walkable + Vector2i.UP * wall_reach_tile
			if !inner_set.has(air): continue
			_protect_air_if_adjacent_to_wall(air, inner_set, protected, wall_offsets)

## Dato un punto d’aria (air), protegge il muro a sinistra/destra se presente.
## - wall_offsets: offset extra da proteggere *rispetto alla cella muro* (es. UP per lo spigolo)
static func _protect_air_if_adjacent_to_wall(
	air: Vector2i,
	inner_set: Dictionary[Vector2i, bool],
	protected: Dictionary[Vector2i, bool],
	air_offsets: Array[Vector2i]
) -> void:
	var has_left_wall := !inner_set.has(air + Vector2i.LEFT)
	var has_right_wall := !inner_set.has(air + Vector2i.RIGHT)

	if has_left_wall or has_right_wall:
		_protect_with_offsets(protected, air, air_offsets)


## Protegge una cella e (opzionale) i suoi offset aggiuntivi.
static func _protect_with_offsets(
	protected: Dictionary[Vector2i, bool],
	base: Vector2i,
	offsets: Array[Vector2i]
) -> void:
	protected[base] = true
	for o in offsets:
		protected[base + o] = true

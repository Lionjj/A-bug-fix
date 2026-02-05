# ============================================================================
# DecoSpawner
# ============================================================================
## Modulo che gestisce lo spawn delle decorazioni all'interno delle stanze.[br]
##
## Obiettivo:[br]
## - Scegliere un set di decorazioni in base a budget, tipo e pesi (weight).[br]
## - Selezionare punti di spawn “esteticamente belli” tramite [method SmartPlacement.beautify].[br]
## - Piazzare le decorazioni rispettando:[br]
##   - footprint (celle occupate).[br]
##   - distanza minima globale tramite [RoomPlacementManager] (can_place/reserve).[br]
##   - assenza di collisione visiva con tiles solidi (AABB sprite vs TileMap).[br]
## [br]
## Convenzioni:[br]
## - Coordinate in CELLE ([Vector2i]) per scelta/filtri/placement.[br]
## - Conversione cella → world via [method SmartPlacement.cell_to_world_position].[br]
## - La gestione conflitti/distanze passa SEMPRE da [code]room.placement[/code].[br]
# ============================================================================

extends Node
class_name DecoSpawner

# ---------------------------------------------------------------------------
# Tuning constants (no magic numbers)
# ---------------------------------------------------------------------------

## Oversampling: quante candidate in più generiamo prima dei filtri (beautify).
const SPAWN_POINTS_OVERSAMPLE_MULT: int = 3

## Safety cap per loop di pick/allocazione (evita freeze in caso di vincoli impossibili).
const PICK_SAFETY_MAX_ITERS: int = 10_000

## Default tentativi massimi per trovare uno slot “safe”.
const SAFE_SPAWN_DEFAULT_ATTEMPTS: int = 30

## Fallback gap in celle se tipo non gestito.
const GAP_FALLBACK_CELLS: int = 0


# ---------------------------------------------------------------------------
# Tabella decorazioni
# ---------------------------------------------------------------------------

## Catalogo delle decorazioni disponibili.[br]
## - Chiave: [DecorationsRegistry.ID].[br]
## - Valore: [Decoration] (tipo, costo, scena, max_per_room, weight, ecc.).[br]
@export var deco_table: Dictionary[DecorationsRegistry.ID, Decoration] = {
	DecorationsRegistry.ID.TREE: Decoration.new(
		DecorationsRegistry.ID.TREE,
		Decoration.DECO_TYPE.GROUND,
		4,
		load("res://Scenes/Object/Decoration/FloatingTree.tscn"),
		1
	),

	DecorationsRegistry.ID.BINARY_LAMP_0: Decoration.new(
		DecorationsRegistry.ID.BINARY_LAMP_0,
		Decoration.DECO_TYPE.GROUND,
		2,
		load("res://Scenes/Object/Decoration/Lamp0.tscn"),
		1
	),

	DecorationsRegistry.ID.BINARY_LAMP_1: Decoration.new(
		DecorationsRegistry.ID.BINARY_LAMP_1,
		Decoration.DECO_TYPE.GROUND,
		2,
		load("res://Scenes/Object/Decoration/Lamp1.tscn"),
		0.4
	),

	DecorationsRegistry.ID.ROCK: Decoration.new(
		DecorationsRegistry.ID.ROCK,
		Decoration.DECO_TYPE.GROUND,
		2,
		load("res://Scenes/Object/Decoration/Rock.tscn"),
		1
	),

	DecorationsRegistry.ID.CABLE_LIGHT: Decoration.new(
		DecorationsRegistry.ID.CABLE_LIGHT,
		Decoration.DECO_TYPE.CEILING,
		2,
		load("res://Scenes/Object/Decoration/Light.tscn"),
		1
	),
}

# ---------------------------------------------------------------------------
# Budget base (per tipo)
# ---------------------------------------------------------------------------

## Budget base per decorazioni a terra.
@export var base_budget_ground: int = 4
## Budget base per decorazioni sui muri.
@export var base_budget_wall: int = 2
## Budget base per decorazioni a soffitto.
@export var base_budget_ceiling: int = 1

## Limite minimo di decorazioni.
const MIN_BUDGET: int = 1
## Limite massimo di decorazioni.
const MAX_BUDGET: int = 10

# ---------------------------------------------------------------------------
# Distanza minima (in pixel) tra decorazioni, per evitare cluster
# ---------------------------------------------------------------------------

## Distanza minima tra decorazioni GROUND.
const MIN_DIST_GROUND: float = 32.0
## Distanza minima tra decorazioni WALL.
const MIN_DIST_WALL: float = 48.0
## Distanza minima tra decorazioni CEILING.
const MIN_DIST_CEILING: float = 64.0

# ---------------------------------------------------------------------------
# Budget scaling (area -> budget)
# ---------------------------------------------------------------------------

## Ogni tot celle spawnabili aggiungo 1 al budget (GROUND).
const AREA_PER_BUDGET_GROUND: int = 60
## Ogni tot celle spawnabili aggiungo 1 al budget (WALL).
const AREA_PER_BUDGET_WALL: int = 120
## Ogni tot celle spawnabili aggiungo 1 al budget (CEILING).
const AREA_PER_BUDGET_CEILING: int = 180

# ---------------------------------------------------------------------------
# Support Types
# ---------------------------------------------------------------------------

## Helper per scelta pesata di un ID decorazione.
class DecoIdWeight:
	var id: DecorationsRegistry.ID
	var weight: float

	## [param _id] ID decorazione.[br]
	## [param _weight] Peso di estrazione (> 0).[br]
	func _init(_id: DecorationsRegistry.ID, _weight: float) -> void:
		id = _id
		weight = _weight

## Risultato di un pick di spawn.[br]
## - [member cell] Cella scelta.[br]
## - [member global_pos] Posizione globale in cui piazzare l'istanza.[br]
class SpawnPick:
	var cell: Vector2i
	var global_pos: Vector2

	## [param c] Cella scelta.[br]
	## [param p] Posizione globale di spawn.[br]
	func _init(c: Vector2i, p: Vector2) -> void:
		cell = c
		global_pos = p

# ---------------------------------------------------------------------------
# API principale
# ---------------------------------------------------------------------------

## Spawna le decorazioni in una stanza in base al tipo richiesto.[br]
## [br]
## Pipeline:[br]
## 1) Calcola budget (in base ad area + base_budget_*).[br]
## 2) Sceglie quali decorazioni spawnare ([method chose_decorations]).[br]
## 3) Calcola i punti candidati ([method get_spawn_points]).[br]
## 4) Istanzia e piazza con controlli ([method istanziate_in_position]).[br]
## [br]
## [param room] Stanza target in cui piazzare le decorazioni.[br]
## [param decos_state] Stato runtime che traccia le reference alle decorazioni.[br]
## [param deco_type] Tipo decorazioni (GROUND/WALL/CEILING).[br]
## [param rng] Generatore randomico basato sul seed del livello.[br]
func spawn_room_decos(
	room: RoomTemplateMeta,
	decos_state: RoomDecoState,
	deco_type: Decoration.DECO_TYPE,
	rng: RandomNumberGenerator
) -> void:
	var budget: int = compute_budget(room, deco_type)

	var decos: Array[DecorationsRegistry.ID] = chose_decorations(deco_type, budget, rng)
	if decos.is_empty():
		return

	var spawn_points: Array[Vector2i] = get_spawn_points(room, decos.size(), deco_type, rng)
	if spawn_points.is_empty():
		return

	istanziate_in_position(spawn_points, decos, room, decos_state, deco_type, rng)

# ---------------------------------------------------------------------------
# Spawn points / candidates
# ---------------------------------------------------------------------------

## Calcola una lista di celle candidate per un tipo di decorazione.[br]
## [br]
## Fonte candidates:[br]
## - [code]room.placement.floor_air_cells[/code] (GROUND)[br]
## - [code]room.placement.wall_recess_cells[/code] (WALL)[br]
## - [code]room.placement.ceiling_air_cells[/code] (CEILING)[br]
## [br]
## Poi usa [method SmartPlacement.beautify] per avere punti più distribuiti.[br]
## [br]
## [param room] Stanza da cui prelevare le liste candidate cache-ate nel PlacementManager.[br]
## [param slots_count] Numero di slot richiesti (prima dei filtri successivi).[br]
## [param deco_type] Tipo decorazione che determina quale lista usare.[br]
## [param rng] Generatore randomico basato sul seed del livello.[br]
## [br]
## @return Array di celle candidate “belle” (oversample incluso).
func get_spawn_points(
	room: RoomTemplateMeta,
	slots_count: int,
	deco_type: Decoration.DECO_TYPE,
	rng: RandomNumberGenerator
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []

	match deco_type:
		Decoration.DECO_TYPE.GROUND:
			candidates = room.placement.floor_air_cells
		Decoration.DECO_TYPE.WALL:
			candidates = room.placement.wall_recess_cells
		Decoration.DECO_TYPE.CEILING:
			candidates = room.placement.ceiling_air_cells

	return SmartPlacement.beautify(candidates, rng, slots_count * SPAWN_POINTS_OVERSAMPLE_MULT)

## Filtra i punti candidati in base al tipo e alla footprint.[br]
## - GROUND: deve essere piazzabile a terra.[br]
## - CEILING: deve essere piazzabile a soffitto.[br]
## - WALL: nessun filtro dedicato (ritorna candidates).[br]
## [br]
## [param room] Stanza target.[br]
## [param candidates] Celle candidate da filtrare.[br]
## [param deco_type] Tipo decorazione.[br]
## [param footprint_cells] Footprint orizzontale in celle (>= 1).[br]
## [br]
## @return Array di celle filtrate.
func filter_spawn_point(
	room: RoomTemplateMeta,
	candidates: Array[Vector2i],
	deco_type: Decoration.DECO_TYPE,
	footprint_cells: int
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if candidates.is_empty():
		return out

	match deco_type:
		Decoration.DECO_TYPE.GROUND:
			out = SmartPlacement.filter_candidates_by_footprint_ground(room, candidates, footprint_cells)
		Decoration.DECO_TYPE.CEILING:
			out = SmartPlacement.filter_candidates_by_footprint_ceiling(room, candidates, footprint_cells)
		_:
			out = candidates

	return out

# ---------------------------------------------------------------------------
# Budget selection
# ---------------------------------------------------------------------------

## Calcola il budget della stanza in base a:[br]
## - base_budget_* (per tipo)[br]
## - area spawnabile ([code]room.placement.spawnable_cells_list.size()[/code])[br]
## - scaling per tipo (AREA_PER_BUDGET_*)[br]
## [br]
## [param room] Stanza da cui derivare l’area spawnabile.[br]
## [param deco_type] Tipo decorazione.[br]
## [br]
## @return Budget finale clampato tra MIN_BUDGET e MAX_BUDGET.
func compute_budget(room: RoomTemplateMeta, deco_type: Decoration.DECO_TYPE) -> int:
	var area_cells: int = room.placement.spawnable_cells_list.size()
	var base_budget: int = 0

	match deco_type:
		Decoration.DECO_TYPE.GROUND:
			base_budget = base_budget_ground + int(area_cells / AREA_PER_BUDGET_GROUND)
		Decoration.DECO_TYPE.WALL:
			base_budget = base_budget_wall + int(area_cells / AREA_PER_BUDGET_WALL)
		Decoration.DECO_TYPE.CEILING:
			base_budget = base_budget_ceiling + int(area_cells / AREA_PER_BUDGET_CEILING)

	return clamp(base_budget, MIN_BUDGET, MAX_BUDGET)

# ---------------------------------------------------------------------------
# Decoration picking (weighted)
# ---------------------------------------------------------------------------

## Sceglie quali decorazioni spawnare rispettando:[br]
## - tipo decorazione (deco.type)[br]
## - budget disponibile (deco.cost)[br]
## - max_per_room[br]
## - weight (scelta pesata)[br]
## [br]
## [param deco_type] Tipo decorazione da selezionare.[br]
## [param budget] Budget disponibile (somma costi).[br]
## [param rng] Generatore randomico basato sul seed del livello.[br]
## [br]
## @return Array di [DecorationsRegistry.ID] nell’ordine di spawn.
func chose_decorations(deco_type: Decoration.DECO_TYPE, budget: int, rng: RandomNumberGenerator) -> Array[DecorationsRegistry.ID]:
	var out: Array[DecorationsRegistry.ID] = []
	if deco_table.is_empty():
		return out
	if budget <= 0:
		return out

	var remaining_budget: int = budget
	var counts: Dictionary[DecorationsRegistry.ID, int] = {}
	var safety: int = PICK_SAFETY_MAX_ITERS

	while remaining_budget > 0 and safety > 0:
		safety -= 1

		var candidates: Array[DecoIdWeight] = []

		for id: DecorationsRegistry.ID in deco_table.keys():
			var deco: Decoration = deco_table.get(id)
			if deco == null:
				continue

			if deco.type != deco_type:
				continue

			if deco.cost > remaining_budget:
				continue

			var current_count: int = counts.get(id, 0)
			if current_count >= deco.max_per_room:
				continue

			var w: float = max(0.0, deco.weight)
			if w <= 0.0:
				continue

			candidates.append(DecoIdWeight.new(id, w))

		if candidates.is_empty():
			break

		var picked_id: DecorationsRegistry.ID = _pick_deco_weighted(candidates, rng)
		var picked_deco: Decoration = deco_table[picked_id]

		out.append(picked_id)
		counts[picked_id] = counts.get(picked_id, 0) + 1
		remaining_budget -= picked_deco.cost

	return out

## Pick pesato su una lista di coppie (id, weight).[br]
## [br]
## [param candidates] Lista di candidati con peso > 0.[br]
## [param rng] Generatore randomico basato sul seed del livello.[br]
## [br]
## @return ID selezionato (fallback: ultimo elemento).
static func _pick_deco_weighted(candidates: Array[DecoIdWeight], rng: RandomNumberGenerator) -> DecorationsRegistry.ID:
	var total_weight: float = 0.0
	for candidate: DecoIdWeight in candidates:
		total_weight += candidate.weight

	var roll: float = rng.randf() * total_weight

	for candidate: DecoIdWeight in candidates:
		roll -= candidate.weight
		if roll <= 0.0:
			return candidate.id

	return candidates.back().id

# ---------------------------------------------------------------------------
# Spawn (single / batch)
# ---------------------------------------------------------------------------

## Spawna una singola decorazione scegliendo uno slot valido e “sicuro”.[br]
## [br]
## “Sicuro” significa:[br]
## - passa i filtri footprint (ground/ceiling)[br]
## - passa [code]room.placement.can_place()[/code] (no conflitti + distanza minima)[br]
## - l’AABB dello sprite non interseca tile solidi (tranne contatto consentito)[br]
## [br]
## [param room] Stanza target.[br]
## [param room_deco_state] Stato runtime per tracciare le reference.[br]
## [param deco_id] ID della decorazione da istanziare.[br]
## [param slots] Pool di celle candidate (usato per il pick).[br]
## [param deco_type] Tipo decorazione.[br]
## [param rng] Generatore randomico basato sul seed del livello.[br]
## [br]
## @return Istanza piazzata o null se fallisce.
func spawn_deco_at_free_slot(
	room: RoomTemplateMeta,
	room_deco_state: RoomDecoState,
	deco_id: DecorationsRegistry.ID,
	slots: Array[Vector2i],
	deco_type: Decoration.DECO_TYPE,
	rng: RandomNumberGenerator
) -> DecorationEntity:
	if slots.is_empty():
		return null

	var inst: DecorationEntity = _create_and_prepare_instance(deco_id, deco_type, room)
	if inst == null:
		return null

	var valid_slots: Array[Vector2i] = filter_spawn_point(room, slots, deco_type, inst.footprint_cells)
	if valid_slots.is_empty():
		inst.queue_free()
		return null

	room.add_child(inst)
	_track_deco_reference(room_deco_state, inst)

	var pick: SpawnPick = _pick_safe_spawn_position(room, inst, valid_slots, deco_type, rng)
	if pick == null:
		inst.queue_free()
		return null

	inst.global_position = pick.global_pos

	var gap_cells: int = _min_gap_cells(room, deco_type)
	room.placement.reserve(pick.cell, inst.footprint_cells, gap_cells)

	return inst

## Spawna in sequenza tutte le decorazioni contenute in [param decos].[br]
## [br]
## [param slots] Pool di slot candidati (condiviso).[br]
## [param decos] Lista di ID decorazioni da spawnare.[br]
## [param room] Stanza target.[br]
## [param room_deco_state] Stato runtime.[br]
## [param deco_type] Tipo decorazione.[br]
## [param rng] Generatore randomico basato sul seed del livello.[br]
func istanziate_in_position(
	slots: Array[Vector2i],
	decos: Array[DecorationsRegistry.ID],
	room: RoomTemplateMeta,
	room_deco_state: RoomDecoState,
	deco_type: Decoration.DECO_TYPE,
	rng: RandomNumberGenerator
) -> void:
	for id: DecorationsRegistry.ID in decos:
		spawn_deco_at_free_slot(room, room_deco_state, id, slots, deco_type, rng)

# ---------------------------------------------------------------------------
# Snap / AABB helpers
# ---------------------------------------------------------------------------

## Offset per spostare lo spawn dal centro della cella “aria” al contatto.[br]
## - GROUND: verso il basso (contatto col pavimento).[br]
## - CEILING: verso l'alto (contatto col soffitto).[br]
## [br]
## [param tilemap] TileMap di collisione della stanza.[br]
## [param deco_type] Tipo decorazione.[br]
## [br]
## @return Offset world-space da sommare alla posizione cella→world.
func _contact_snap(tilemap: TileMapLayer, deco_type: Decoration.DECO_TYPE) -> Vector2:
	var tile_size: Vector2i = tilemap.tile_set.tile_size
	match deco_type:
		Decoration.DECO_TYPE.GROUND:
			return Vector2(0.0, tile_size.y * 0.5)
		Decoration.DECO_TYPE.CEILING:
			return Vector2(0.0, -tile_size.y * 0.5)
		_:
			return Vector2.ZERO

## Calcola l’AABB globale dello sprite della decorazione (tenendo conto del transform).[br]
## [br]
## [param inst] Istanza decorazione (deve avere Sprite2D valido).[br]
## [br]
## @return Rect2 globale dello sprite (Rect2 con size ZERO se non calcolabile).
func get_sprite_global_aabb(inst: DecorationEntity) -> Rect2:
	var sprite: Sprite2D = inst.sprite

	if sprite == null:
		sprite = inst.get_node_or_null("Sprite2D") as Sprite2D
		if sprite == null or sprite.texture == null:
			return Rect2(inst.global_position, Vector2.ZERO)

	var local_rect: Rect2 = sprite.get_rect()

	var tl: Vector2 = sprite.to_global(local_rect.position)
	var tr: Vector2 = sprite.to_global(local_rect.position + Vector2(local_rect.size.x, 0.0))
	var bl: Vector2 = sprite.to_global(local_rect.position + Vector2(0.0, local_rect.size.y))
	var br: Vector2 = sprite.to_global(local_rect.position + local_rect.size)

	var min_x: float = min(tl.x, tr.x, bl.x, br.x)
	var max_x: float = max(tl.x, tr.x, bl.x, br.x)
	var min_y: float = min(tl.y, tr.y, bl.y, br.y)
	var max_y: float = max(tl.y, tr.y, bl.y, br.y)

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

## Ritorna true se l’AABB interseca tiles solidi NON consentiti.[br]
## [br]
## [param tilemap] TileMap su cui verificare le celle solide.[br]
## [param sprite_aabb_global] AABB globale dello sprite.[br]
## [param allowed_cells] Set di celle in cui è ammesso il contatto.[br]
## [br]
## @return True se collide con almeno un tile solido non consentito.
func sprite_aabb_intersects_solid_tiles(
	tilemap: TileMapLayer,
	sprite_aabb_global: Rect2,
	allowed_cells: Dictionary[Vector2i, bool]
) -> bool:
	if sprite_aabb_global.size == Vector2.ZERO:
		return false

	var top_left_local: Vector2 = tilemap.to_local(sprite_aabb_global.position)
	var bottom_right_local: Vector2 = tilemap.to_local(sprite_aabb_global.position + sprite_aabb_global.size)

	var min_cell: Vector2i = tilemap.local_to_map(top_left_local)
	var max_cell: Vector2i = tilemap.local_to_map(bottom_right_local)

	for y: int in range(min_cell.y, max_cell.y + 1):
		for x: int in range(min_cell.x, max_cell.x + 1):
			var cell: Vector2i = Vector2i(x, y)

			if allowed_cells.has(cell):
				continue

			if tilemap.get_cell_tile_data(cell) != null:
				return true

	return false

# ---------------------------------------------------------------------------
# Instance creation / tracking
# ---------------------------------------------------------------------------

## Crea l'istanza e prepara i dati di spawn.[br]
## [br]
## [param deco_id] ID della decorazione.[br]
## [param deco_type] Tipo decorazione (set_type).[br]
## [param room] Stanza target (serve per tile_size e footprint).[br]
## [br]
## @return Istanza pronta (con footprint_cells valido) o null.
func _create_and_prepare_instance(
	deco_id: DecorationsRegistry.ID,
	deco_type: Decoration.DECO_TYPE,
	room: RoomTemplateMeta
) -> DecorationEntity:
	var deco: Decoration = deco_table.get(deco_id)
	if deco == null:
		return null

	var inst: DecorationEntity = deco.scene.instantiate() as DecorationEntity
	if inst == null:
		return null

	inst.set_type(deco_type)
	inst.prepare_for_spawn()
	inst.footprint_cells = inst.compute_footprint_cells(room.collision.tile_set.tile_size)
	return inst

## Registra la reference nel RoomDecoState e la rimuove quando l'istanza esce dall'albero.[br]
## [br]
## [param room_deco_state] Stato runtime della stanza.[br]
## [param inst] Istanza della decorazione.[br]
func _track_deco_reference(room_deco_state: RoomDecoState, inst: DecorationEntity) -> void:
	room_deco_state.deco_references.append(inst)
	inst.tree_exited.connect(func() -> void:
		room_deco_state.deco_references.erase(inst)
	)

# ---------------------------------------------------------------------------
# Pick posizione “safe”
# ---------------------------------------------------------------------------

## Seleziona una posizione valida tra gli slot (tentativi limitati):[br]
## 1) verifica [code]room.placement.can_place()[/code] (footprint + gap).[br]
## 2) calcola posizione world + offset snap.[br]
## 3) controlla AABB sprite contro tile solidi (con eccezioni consentite).[br]
## [br]
## [param room] Stanza target.[br]
## [param inst] Istanza decorazione (footprint e offset già pronti).[br]
## [param valid_slots] Celle candidate (verrà modificato: rimozioni su fail).[br]
## [param deco_type] Tipo decorazione (snap + allowed contact + gap).[br]
## [param max_attempts] Massimo tentativi (clampato a valid_slots.size()).[br]
## [param rng] Generatore randomico basato sul seed del livello.[br]
## [br]
## @return SpawnPick (cella + pos) oppure null.
func _pick_safe_spawn_position(
	room: RoomTemplateMeta,
	inst: DecorationEntity,
	valid_slots: Array[Vector2i],
	deco_type: Decoration.DECO_TYPE,
	rng: RandomNumberGenerator,
	max_attempts: int = SAFE_SPAWN_DEFAULT_ATTEMPTS,
) -> SpawnPick:
	var tilemap: TileMapLayer = room.collision
	var spawn_offset: Vector2 = inst.get_spawn_offset() + _contact_snap(tilemap, deco_type)
	var gap_cells: int = _min_gap_cells(room, deco_type)

	var attempts: int = min(max_attempts, valid_slots.size())
	while attempts > 0:
		attempts -= 1

		var idx: int = rng.randi() % valid_slots.size()
		var cell: Vector2i = valid_slots[idx]

		if not room.placement.can_place(cell, inst.footprint_cells, gap_cells):
			valid_slots.remove_at(idx)
			continue

		var pos: Vector2 = SmartPlacement.cell_to_world_position(tilemap, cell, spawn_offset)
		inst.global_position = pos

		var aabb: Rect2 = get_sprite_global_aabb(inst)
		var allowed: Dictionary[Vector2i, bool] = _build_allowed_contact_cells(cell, inst.footprint_cells, deco_type)

		if not sprite_aabb_intersects_solid_tiles(tilemap, aabb, allowed):
			return SpawnPick.new(cell, pos)

		valid_slots.remove_at(idx)

	return null

## Costruisce il set di celle in cui è permesso il contatto con tile solidi.[br]
## [br]
## [param center_cell] Cella scelta per il piazzamento.[br]
## [param footprint_cells] Footprint orizzontale in celle.[br]
## [param deco_type] Tipo decorazione (GROUND consente sotto, CEILING consente sopra).[br]
## [br]
## @return Set di celle “allowed” (Dictionary[Vector2i,bool]).
func _build_allowed_contact_cells(
	center_cell: Vector2i,
	footprint_cells: int,
	deco_type: Decoration.DECO_TYPE
) -> Dictionary[Vector2i, bool]:
	var allowed: Dictionary[Vector2i, bool] = {}
	var fp_cells: Array[Vector2i] = SmartPlacement.get_footprint_cells(center_cell, footprint_cells)

	match deco_type:
		Decoration.DECO_TYPE.GROUND:
			for c: Vector2i in fp_cells:
				allowed[c + Vector2i.DOWN] = true
		Decoration.DECO_TYPE.CEILING:
			for c: Vector2i in fp_cells:
				allowed[c + Vector2i.UP] = true
		_:
			pass

	return allowed

# ---------------------------------------------------------------------------
# Gap conversion
# ---------------------------------------------------------------------------

## Converte la distanza minima in pixel in celle, in base al tipo di decorazione.[br]
## [br]
## [param room] Stanza (serve per tile_size).[br]
## [param deco_type] Tipo decorazione (sceglie quale MIN_DIST usare).[br]
## [br]
## @return Gap minimo in CELLE (arrotondato per eccesso).
func _min_gap_cells(room: RoomTemplateMeta, deco_type: Decoration.DECO_TYPE) -> int:
	var tile_size_x: int = room.collision.tile_set.tile_size.x

	match deco_type:
		Decoration.DECO_TYPE.GROUND:
			return RoomPlacementManager.px_to_cells(MIN_DIST_GROUND, tile_size_x)
		Decoration.DECO_TYPE.WALL:
			return RoomPlacementManager.px_to_cells(MIN_DIST_WALL, tile_size_x)
		Decoration.DECO_TYPE.CEILING:
			return RoomPlacementManager.px_to_cells(MIN_DIST_CEILING, tile_size_x)

	return GAP_FALLBACK_CELLS

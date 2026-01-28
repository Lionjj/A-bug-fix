## Modulo che gestice lo spawn delle decorazioni all'interno delle stanze del
## mondo di gioco.
extends Node
class_name DecoSpawner

@export var deco_table : Dictionary[DecorationsRegistry.ID, Decoration] = {
	DecorationsRegistry.ID.TREE: Decoration.new(
		DecorationsRegistry.ID.TREE,
		Decoration.DECO_TYPE.GROUND, 
		4,
		load("res://Scenes/Object/Decoration/FloatingTree.tscn"),
		1,
	),
	
	DecorationsRegistry.ID.BINARY_LAMP_0: Decoration.new(
		DecorationsRegistry.ID.BINARY_LAMP_0,
		Decoration.DECO_TYPE.GROUND, 
		2,
		load("res://Scenes/Object/Decoration/Lamp0.tscn"),
		1,
	),
	
	DecorationsRegistry.ID.BINARY_LAMP_1: Decoration.new(
		DecorationsRegistry.ID.BINARY_LAMP_1,
		Decoration.DECO_TYPE.GROUND, 
		2,
		load("res://Scenes/Object/Decoration/Lamp1.tscn"),
		0.4,
	),
	
	DecorationsRegistry.ID.ROCK: Decoration.new(
		DecorationsRegistry.ID.ROCK,
		Decoration.DECO_TYPE.GROUND, 
		2,
		load("res://Scenes/Object/Decoration/Rock.tscn"),
		1,
	),
	
	DecorationsRegistry.ID.CABLE_LIGHT: Decoration.new(
		DecorationsRegistry.ID.CABLE_LIGHT,
		Decoration.DECO_TYPE.CEILING, 
		2,
		load("res://Scenes/Object/Decoration/Light.tscn"),
		1,
	),
}

## Budget degli oggetti che devono essere piazzati a terra.
@export var base_budget_ground: int = 4
## Budget degli oggetti che devono essere piazzati sui muri.
@export var base_budget_wall: int = 2
## Budget degli oggetti che devono essere piazzati sul soffitto.
@export var base_budget_ceiling: int = 1

## Limite inferiore rapprsentante la quantità minima di decorazioni.
const MIN_BUDGET: int = 1
## Limite superiore rapprsentante la quantità massima di decorazioni.
const MAX_BUDGET: int = 10

## Distanza minima (in pixel) tra decorazioni del tipo GROUND per 
## evitare i cluster.
const MIN_DIST_GROUND: float = 32.0
## Distanza minima (in pixel) tra decorazioni del tipo WALL per 
## evitare i cluster.
const MIN_DIST_WALL: float = 48.0
## Distanza minima (in pixel) tra decorazioni del tipo CEIL per 
## evitare i cluster.
const MIN_DIST_CEILING: float = 64.0

const AREA_PER_BUDGET_GROUND := 60
const AREA_PER_BUDGET_WALL := 120
const AREA_PER_BUDGET_CEILING := 180


## Classe di supporto per la scelta pesata delle decorazioni.
class DecoId_Weight:
	var id : DecorationsRegistry.ID
	var weight: float
	
	func _init(_id: DecorationsRegistry.ID, _weight: float) -> void:
		id = _id
		weight = _weight

class SpawnPick:
	var cell: Vector2i
	var global_pos: Vector2
	func _init(c: Vector2i, p: Vector2):
		cell = c
		global_pos = p


func spawn_room_decos(
	room: RoomTemplateMeta,
	decos_state: RoomDecoState,
	deco_type: Decoration.DECO_TYPE
) -> void:
	
	var budget: int = compute_budget(room, deco_type )
	
	var decos: Array[DecorationsRegistry.ID] = chose_decorations(deco_type, budget)
	if decos.is_empty(): return 
	
	var spawn_points : Array[Vector2i] = get_spawn_points(room, decos.size(), deco_type)
	if spawn_points.is_empty(): return 
	
	istanziate_in_position(
		spawn_points,
		decos,
		room,
		decos_state,
		deco_type
	)


## Individua un insieme di n: [param slots_count] all'itnerno della stanza 
## [param room] per le decorazioni di tipo [param deco_type].
func get_spawn_points(
	room: RoomTemplateMeta, 
	slots_count: int, 
	deco_type: Decoration.DECO_TYPE
) -> Array[Vector2i]:
	var inner_cells: Array[Vector2i] = room.spawn_points
	if inner_cells.is_empty(): return []
	
	var candidates: Array[Vector2i] = []
	match deco_type:
		Decoration.DECO_TYPE.GROUND:
			candidates = SmartPlacement.get_floor_air_cells(room, inner_cells)
		Decoration.DECO_TYPE.WALL:
			candidates = SmartPlacement.get_wall_recesses(inner_cells)
		Decoration.DECO_TYPE.CEILING:
			candidates = SmartPlacement.get_ceiling_air_cells(room, inner_cells)

	
	return candidates
	
	### Uso Voronoi per selezionare delle are macro aree e utilizzo i centroidi delle 
	### macro are per selesionare dei punti esteticamente belli
	return SmartPlacement.beautify(candidates, slots_count * 3)

func filter_spawn_point(
	room: RoomTemplateMeta,
	candidates: Array[Vector2i], 
	deco_type: Decoration.DECO_TYPE,
	footprint: int,
) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if candidates.is_empty(): return out
	
	var inner_lookup: Dictionary[Vector2i, bool] = {}
	for c in room.spawn_points:
		inner_lookup[c] = true
		
	match deco_type:
		Decoration.DECO_TYPE.GROUND:
			out = SmartPlacement.filter_candidates_by_footprint_ground(
				room,
				candidates,
				inner_lookup,
				footprint
			)
		Decoration.DECO_TYPE.CEILING:
			out = SmartPlacement.filter_candidates_by_footprint_ceiling(
				room,
				candidates,
				inner_lookup,
				footprint
			)
		_:
			out = candidates
	
	return out
			
## Calcola il buget che la stanza [param room] possiede in base a quanti punti 
## sono disponibili nella stanza, e al tipo di decorazione [param deco_type].
func compute_budget(room: RoomTemplateMeta, deco_type: Decoration.DECO_TYPE) -> int:
	var area: int = room.spawn_points.size()
	
	var base_budget: int = 0
	
	match deco_type:
		Decoration.DECO_TYPE.GROUND:
			base_budget = base_budget_ground + int(area / AREA_PER_BUDGET_GROUND)
		Decoration.DECO_TYPE.WALL:
			base_budget = base_budget_wall + int(area / AREA_PER_BUDGET_WALL)
		Decoration.DECO_TYPE.CEILING:
			base_budget = base_budget_ceiling + int(area / AREA_PER_BUDGET_CEILING)

	return clamp(base_budget, MIN_BUDGET, MAX_BUDGET)

func chose_decorations(
	deco_type: Decoration.DECO_TYPE, 
	budget: int,

) -> Array[DecorationsRegistry.ID]:
	
	var out: Array[DecorationsRegistry.ID] = []
	if deco_table.is_empty() or budget <= 0: return out
	
	var remaining : int = budget
	var counts: Dictionary[EnemiesRegistry.ID, int] = {}
	var safety : int = 10_000
	
	while remaining > 0 and safety > 0:
		safety -= 1
		
		var candidates: Array[DecoId_Weight] = []
		for id in deco_table.keys():
			var deco: Decoration = deco_table.get(id)
			if deco == null: continue
			## Filtro per tipo di decorazione scelta.
			if deco.type != deco_type: continue
			
			## Filtro per il budget.
			if deco.cost > remaining: continue
			
			## Filtro il nmero massimo di quel tipo di decorazione che possono 
			## essere inserite nella stanza.
			var current : int = counts.get(id, 0)
			if current >= deco.max_per_room: continue
			
			var w : float = max(0.0, deco.weight)
			if w <= 0.0: continue
			
			candidates.append(DecoId_Weight.new(id, w))
		
		if candidates.is_empty(): break
		
		var picked_id: DecorationsRegistry.ID = _pick_deco_weighted(candidates)
		var picked_deco: Decoration = deco_table[picked_id]
		
		out.append(picked_id)
		counts[picked_id] = counts.get(picked_id, 0) + 1
		remaining -= picked_deco.cost
			
	return out


## Seleziona in modo pesato una decorazione da [param candidates].
static func _pick_deco_weighted(
	candidates: Array[DecoId_Weight],
) -> DecorationsRegistry.ID:
	var total : float = 0.0
	
	for candiate in candidates: total += candiate.weight
	
	var roll : float = Rng.randf() * total
	
	for candiate in candidates: 
		roll -= candiate.weight
		if roll <= 0.0: return candiate.id
	
	return candidates.back().id

func spawn_deco_at_free_slot(
	room: RoomTemplateMeta,
	room_deco_state: RoomDecoState,
	deco_id: DecorationsRegistry.ID,
	slots: Array[Vector2i],
	deco_type: Decoration.DECO_TYPE
) -> DecorationEntity:

	if slots.is_empty(): return null

	var inst: DecorationEntity = _create_and_prepare_instance(deco_id, deco_type, room)
	if inst == null: return null

	var valid_slots: Array[Vector2i] = _compute_valid_slots(room, slots, inst, deco_type)
	if valid_slots.is_empty():
		inst.queue_free()
		return null

	room.add_child(inst)
	_track_deco_reference(room_deco_state, inst)

	var pick: SpawnPick = _pick_safe_spawn_position(room, inst, valid_slots, deco_type)
	if pick == null:
		inst.queue_free()
		return null

	inst.global_position = pick.global_pos
	_consume_used_slots(slots, pick.cell, inst.footprint_cells)

	return inst

func istanziate_in_position(
	slots: Array[Vector2i],
	decos: Array[DecorationsRegistry.ID],
	room: RoomTemplateMeta,
	room_deco_state: RoomDecoState,
	deco_type: Decoration.DECO_TYPE,
) -> void:
	for id in decos:
		spawn_deco_at_free_slot(room, room_deco_state, id, slots, deco_type)
	

func _contact_snap(tilemap: TileMapLayer, deco_type: Decoration.DECO_TYPE) -> Vector2:
	var ts : Vector2i = tilemap.tile_set.tile_size
	match deco_type:
		Decoration.DECO_TYPE.GROUND:
			return Vector2(0, ts.y * 0.5) # dal centro cella aria al bordo basso della cella
		Decoration.DECO_TYPE.CEILING:
			return Vector2(0, -ts.y * 0.5) # dal centro cella aria al bordo alto della cella
		_:
			return Vector2.ZERO

func get_sprite_global_aabb(inst: DecorationEntity) -> Rect2:
	var sprite: Sprite2D = inst.sprite
	
	if sprite == null:
		sprite = inst.get_node_or_null("Sprite2D") as Sprite2D
		if sprite == null or sprite.texture == null:
			return Rect2(inst.global_position, Vector2.ZERO)

	# Rect locale dello Sprite2D (tiene conto di centered / offset)
	var local_rect: Rect2 = sprite.get_rect()

	# Converto i 4 vertici in globale
	var tl: Vector2 = sprite.to_global(local_rect.position)
	var tr: Vector2 = sprite.to_global(local_rect.position + Vector2(local_rect.size.x, 0))
	var bl: Vector2 = sprite.to_global(local_rect.position + Vector2(0, local_rect.size.y))
	var br: Vector2 = sprite.to_global(local_rect.position + local_rect.size)

	var min_x: float = min(tl.x, tr.x, bl.x, br.x)
	var max_x: float = max(tl.x, tr.x, bl.x, br.x)
	var min_y: float = min(tl.y, tr.y, bl.y, br.y)
	var max_y: float = max(tl.y, tr.y, bl.y, br.y)

	return Rect2(
		Vector2(min_x, min_y),
		Vector2(max_x - min_x, max_y - min_y)
	)

func sprite_aabb_intersects_solid_tiles(
	tilemap: TileMapLayer,
	sprite_aabb_global: Rect2,
	allowed_cells: Dictionary[Vector2i, bool]
) -> bool:
	if sprite_aabb_global.size == Vector2.ZERO:
		return false

	# Globale → locale tilemap
	var top_left_local: Vector2 = tilemap.to_local(sprite_aabb_global.position)
	var bottom_right_local: Vector2 = tilemap.to_local(
		sprite_aabb_global.position + sprite_aabb_global.size
	)

	# Locale → coordinate cella
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

func _create_and_prepare_instance(
	deco_id: DecorationsRegistry.ID,
	deco_type: Decoration.DECO_TYPE,
	room: RoomTemplateMeta
) -> DecorationEntity:
	var deco: Decoration = deco_table.get(deco_id)
	if deco == null: return null

	var inst: DecorationEntity = deco.scene.instantiate() as DecorationEntity
	if inst == null: return null

	inst.set_type(deco_type)

	# IMPORTANTISSIMO: prepara prima (texture random, ecc.)
	inst.prepare_for_spawn()

	# ora la footprint è affidabile
	inst.footprint_cells = inst.compute_footprint_cells(room.collision.tile_set.tile_size)
	return inst

func _compute_valid_slots(
	room: RoomTemplateMeta,
	slots: Array[Vector2i],
	inst: DecorationEntity,
	deco_type: Decoration.DECO_TYPE
) -> Array[Vector2i]:
	return filter_spawn_point(
		room,
		slots,
		deco_type,
		inst.footprint_cells
	)

func _track_deco_reference(room_deco_state: RoomDecoState, inst: DecorationEntity) -> void:
	room_deco_state.deco_references.append(inst)
	inst.tree_exited.connect(func():
		room_deco_state.deco_references.erase(inst)
	)

func _pick_safe_spawn_position(
	room: RoomTemplateMeta,
	inst: DecorationEntity,
	valid_slots: Array[Vector2i],
	deco_type: Decoration.DECO_TYPE,
	max_attempts: int = 30
) -> SpawnPick:

	var tilemap: TileMapLayer = room.collision
	var spawn_offset: Vector2 = inst.get_spawn_offset() + _contact_snap(tilemap, deco_type)

	var attempts: int = min(max_attempts, valid_slots.size())
	while attempts > 0:
		attempts -= 1

		var idx: int = Rng.randi() % valid_slots.size()
		var cell: Vector2i = valid_slots[idx]

		var pos: Vector2 = SmartPlacement.cell_to_world_position(tilemap, cell, spawn_offset)
		inst.global_position = pos

		var aabb: Rect2 = get_sprite_global_aabb(inst)
		var allowed: Dictionary[Vector2i, bool] = _build_allowed_contact_cells(
			cell,
			inst.footprint_cells,
			deco_type
		)
		if not sprite_aabb_intersects_solid_tiles(tilemap, aabb, allowed):
			return SpawnPick.new(cell, pos)

		valid_slots.remove_at(idx)

	return null

func _consume_used_slots(
	slots: Array[Vector2i],
	center_cell: Vector2i,
	footprint: int
) -> void:
	slots.erase(center_cell)
	var occupied: Array[Vector2i] = SmartPlacement.get_footprint_cells(center_cell, footprint)
	for c in occupied:
		slots.erase(c)

func _build_allowed_contact_cells(
	center_cell: Vector2i,
	footprint: int,
	deco_type: Decoration.DECO_TYPE
) -> Dictionary[Vector2i, bool]:
	var allowed: Dictionary[Vector2i, bool] = {} # Dictionary[Vector2i, bool]

	var fp_cells: Array[Vector2i] = SmartPlacement.get_footprint_cells(center_cell, footprint)

	match deco_type:
		Decoration.DECO_TYPE.GROUND:
			# consenti i tile di pavimento sotto il footprint
			for c in fp_cells:
				allowed[c + Vector2i.DOWN] = true
		Decoration.DECO_TYPE.CEILING:
			# consenti i tile di soffitto sopra il footprint
			for c in fp_cells:
				allowed[c + Vector2i.UP] = true
		_:
			# WALL ecc: per ora nessuna eccezione
			pass

	return allowed

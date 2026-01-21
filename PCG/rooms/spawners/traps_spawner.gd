extends Node
class_name TrapsSpawner

@export var trap_table: Dictionary[TrapRegistry.ID, Trap] = {
	TrapRegistry.ID.DAMAGED_BIT: Trap.new(
		TrapRegistry.ID.DAMAGED_BIT, 1, load("res://Scenes/Interactable/damaged_bit_trap.tscn")
	)
}

## Budget di base dipsonibile per una stanza
@export var base_budget: int = 1
## Moltiplicatore del budget per livello
@export var budget_per_level : float = 0.8
## Mottiplicatore per la difficoltà del livello
@export var room_diff_mult: float = 0.25

## Limite inferiore del moltiplicatore del budget
const LOGIC_BUDGET_MULT_MIN: float = 0.5
## Limite superiore del moltiplicatore del budget
const LOGIC_BUDGET_MULT_MAX: float = 2.5
## Coefficente di smorzamento usato per evitare che la difficolta cresca troppo velocemente.
const DAMPING_COEFFICENT: float = 0.8

const PIT_WEIGHT: float = 0.6
const MIN_PIT_DEPTH: int = 3
const PIT_BOTTOM_OFFSET: int = 1

## Limite inferiore di budget dipsonibile per una stanza
const MIN_BUDGET: int = 0
## Limite superiore di budget dipsonibile per una stanza
const MAX_BUDGET: int = 12

const MIN_DIST_FROM_ENTRY: int = 5

## Classe di supporto per la scelta pesata delle trappole, vedi anche: [method chose_trap]
class TrapId_Weight:
	var id : TrapRegistry.ID
	var weight: float
	
	func _init(_id: TrapRegistry.ID, _weight: float) -> void:
		id = _id
		weight = _weight

## Individua un insieme di n: [param slots_count] all'itnerno della stanza [param room]
## evitando il soft-lock del [param player] utilizzando la sua velocita di salto.
func get_spawn_points(room: RoomTemplateMeta, slots_count: int, player: Player) -> Array[Vector2i]:
	var inner_cells: Array[Vector2i] = room.spawn_points
	if inner_cells.is_empty(): return []
	
	var candidates: Array[Vector2i] = SmartPlacement.get_trap_candidates_local(
		room, 
		inner_cells,
		PIT_WEIGHT,
		MIN_PIT_DEPTH,
		PIT_BOTTOM_OFFSET
	)
	if candidates.is_empty(): return []
	
	var walkable: Array[Vector2i] = SmartPlacement.get_floor_air_cells(room, inner_cells)
	if walkable.is_empty(): return []
	
	var tile_size_y: int = room.collision.tile_set.tile_size.y
	var jump_tiles: float = TrapPlcacementPolicy.compute_jump_height_tiles(
		abs(player.jump_velocity),
		player.gravity,
		tile_size_y
	)
	var wall_reach_tiles: int = int(ceil(jump_tiles)) + TrapPlcacementPolicy.WALL_JUMP_MARGIN_TILES
	
	var protected_cell: Dictionary[Vector2i, bool] = TrapPlcacementPolicy.build_protected_cells(
		inner_cells,
		walkable,
		wall_reach_tiles
	)
	
	candidates = TrapPlcacementPolicy.filter_not_blocked(candidates, protected_cell)
	if candidates.is_empty(): return []
	
	var entry: Vector2i = SmartPlacement._find_entry_point(room.collision)
	var scored_list: Array[Vector2i] = SmartPlacement.score_list(
		room,
		candidates,
		inner_cells,
		slots_count,
		MIN_DIST_FROM_ENTRY
		)
	
	if scored_list.is_empty(): return []
	
	return SmartPlacement.beautify(scored_list, slots_count)

func instantiate_in_position(slots: Array[Vector2i], traps: Array[TrapRegistry.ID], room: RoomTemplateMeta, trap_state: RoomTrapState) -> void:
	var slots_copy : Array[Vector2i] = slots.duplicate()
	for t in traps:
		var data: Trap = trap_table[t]
		var inst: TrapEntity = data.scene.instantiate()
		room.add_child(inst)
		var cell: Vector2i = slots_copy.pop_front()
		inst.global_position = SmartPlacement.cell_to_world_position(room.collision, cell)
		trap_state.traps_references.append(inst)

## Calcola il buget che la stanza [param room] possiede per livello [param run_level], questo indica 
## il numero di trappole che possiamo isnerire per stanza.
func compute_budget(run_level: int , room: RoomTemplateMeta) -> int:
	var budget : int = base_budget + int(round(float(run_level) * budget_per_level))
	budget = int(round(float(budget) * (1.0 + float(room.logic_node.diff - 1) * room_diff_mult)))
	budget = int(round(float(budget) * clamp(room.logic_node.trap_directive.budget_mult, LOGIC_BUDGET_MULT_MIN, LOGIC_BUDGET_MULT_MAX)))
	
	return clamp(budget, MIN_BUDGET, MAX_BUDGET)

## Metodo che restituisce una lista di nemici calcolata sulla base della difficoltà della stanza
## [param room_difficulty], quella del livello [param run_level] e sul budget disponibile [param budget].
func chose_traps(room_difficulty: int, run_level: int, budget: int) -> Array[TrapRegistry.ID]:
	var out: Array[TrapRegistry.ID] = []
	if trap_table.is_empty() or budget <= 0: return out
	
	var run_difficulty: float = float(run_level) + float(room_difficulty) * DAMPING_COEFFICENT
	var remaining : int = budget
	
	var counts: Dictionary[EnemiesRegistry.ID, int] = {}
	
	var safety : int = 10_000
	
	while remaining > 0 and safety > 0:
		safety -= 1
		
		var candidates: Array[TrapId_Weight] = []
		for id in trap_table.keys():
			var trap: Trap = trap_table.get(id)
			
			var weighed_trap: float = _compute_spawn_weight(trap, run_difficulty)
			if weighed_trap <= 0.0: continue
			
			if trap.cost > remaining: continue
			
			## Se ho raggiunto il numero massimo di nemici per quella stanza passa alla prossima 
			## iterazione del ciclo.
			var current_trap_count: int = counts.get(id, 0)
			if current_trap_count >= trap.max_per_room: continue
			
			candidates.append(TrapId_Weight.new(id, weighed_trap))
		
		if candidates.is_empty(): break
		
		var picked_id: TrapRegistry.ID = _pick_trap_weighted(candidates)
		var picked_trap: Trap = trap_table[picked_id]
		
		out.append(picked_id)
		counts[picked_id] = counts.get(picked_id, 0) + 1
		remaining -= picked_trap.cost
			
	return out

func _pick_trap_weighted(candidates: Array[TrapId_Weight]) -> TrapRegistry.ID:
	var total : float = 0.0
	for c in candidates:
		total += c.weight

	var rng := Rng.randf() * total
	for c in candidates:
		rng -= c.weight
		if rng <= 0.0:
			return c.id

	return candidates.back().id

func _compute_spawn_weight(trap: Trap, difficulty: float) -> float:
	if difficulty < trap.min_difficulty: return 0.0
	if difficulty > trap.max_difficulty: return 0.0

	var window : float = max(0.0001, trap.max_difficulty - trap.min_difficulty)
	var prog : float = (difficulty - trap.min_difficulty) / window
	prog = clamp(prog, 0.0, 1.0)

	var rarity_ramp := prog * prog
	return trap.weight * (0.3 + 0.7 * rarity_ramp)

## Modulo per gestire e istanziare in posizione i nemici contenuti in una stanza.
extends Node
class_name EnemiesSpawner

## Lista di scene che rappresentano i nemicici fisici in gioco
@export var enemy_table: Dictionary[EnemiesRegistry.ID, Enemy] = {
	EnemiesRegistry.ID.MINION : Enemy.new(
		EnemiesRegistry.ID.MINION, 1, load("res://Scenes/Enemy/Minion.tscn"), 1.0, 0.0, 9999.0, 10
	),
	EnemiesRegistry.ID.GUNNER : Enemy.new(
		EnemiesRegistry.ID.GUNNER, 2, load("res://Scenes/Enemy/Gunner.tscn"), 0.55, 2.0, 9999.0, 4
	),
}

const LOGIC_BUDGET_MULT_MIN: float = 0.5
const LOGIC_BUDGET_MULT_MAX: float = 2.5
## Coefficente di smorzamento usato per evitare che la difficolta cresca troppo velocemente.
const DAMPING_COEFFICENT: float = 0.8
## Distanza fra un nemico e l'altro
const MIN_DISTANCE: float = 48.0

var base_budget: int = 3
var budget_per_level : float = 1.2
var room_diff_mult: float = 0.35

var min_budget: int = 0
var max_budget: int = 20

var alive_enemies: Array[EnemyEntity] = []

class EnemyId_Weight:
	var id : EnemiesRegistry.ID
	var weight: float
	
	func _init(_id: EnemiesRegistry.ID, _weight: float) -> void:
		id = _id
		weight = _weight
	
	
## trova le posizioni per i nemici
func _get_spawn_points(room: RoomTemplateMeta, slots_count: int) -> Array[Vector2i]:
	var inner_cells: Array[Vector2i] = room.spawn_points
	if inner_cells.is_empty(): return []
	
	var spawnable_air_cells: Array[Vector2i] = SmartPlacement.get_floor_air_cells(room, inner_cells)
	if spawnable_air_cells.is_empty(): return []
	
	return SmartPlacement.beautify(spawnable_air_cells, slots_count)
	
func _find_free_slot_index(slots: Array[Vector2i], alive_enemies: Array[EnemyEntity], min_dist: float) -> int:
	for i: int in range(slots.size()):
		var current: Vector2i = slots[i]
		var ok: bool = true
		for enemy: EnemyEntity in alive_enemies:
			if enemy.global_position.distance_to(current) >= min_dist: continue
			
			ok = false
			break
		
		if ok: return i
	return -1

func spawn_enemy_at_free_slot(room: RoomTemplateMeta, enemy_id: EnemiesRegistry.ID, slots: Array[Vector2i]) -> bool:
	var slot_index: int = _find_free_slot_index(slots, alive_enemies, MIN_DISTANCE)
	if slot_index == -1: return false
	
	var data : Enemy = enemy_table[enemy_id]
	var inst: EnemyEntity = data.scene.instantiate()
	
	var world_pos: Vector2 = slots[slot_index] as Vector2
	inst.global_position = room.to_local(world_pos)
	room.add_child(inst)
	
	alive_enemies.append(inst)
	inst.tree_exited.connect(func() -> void: alive_enemies.erase(inst))
	
	return true

## Calcola il buget che la stanza [param room] possiede per livello [param run_level], questo indica 
## il numero di nemcici che possiamo isnerire per stanza.
func _compute_budget(run_level: int , room: RoomTemplateMeta) -> int:
	var budget : int = base_budget + int(round(float(run_level) * budget_per_level))
	budget = int(round(float(budget) * (1.0 + float(room.logic_node.diff - 1) * room_diff_mult)))
	budget = int(round(float(budget) * clamp(room.logic_node.enemy_directive.budget_mult, LOGIC_BUDGET_MULT_MIN, LOGIC_BUDGET_MULT_MAX)))
	
	return clamp(budget, min_budget, max_budget)

## Calcolo il peso normalizzato dello spawn dei [param enemy] con una curva di progressione 
## lenta all'inizio e poi accella con il progredire della [param difficulty] dei livelli.
func _compute_spawn_weight(enemy: Enemy, difficulty: float) -> float:
	if difficulty < enemy.min_difficulty: return 0.0
	if difficulty > enemy.max_difficulty: return 0.0
	
	var difficulty_window : float = max(0.0001, enemy.max_difficulty - enemy.min_difficulty)
	var progression : float = (difficulty - enemy.min_difficulty) / difficulty_window
	progression = clamp(progression, 0.0, 1.0)
	
	## Progressione dei livvelli non lineare
	var rarity_ramp: float = progression * progression
	
	return enemy.weight * (0.3 + 0.7 * rarity_ramp)

## Sualla base del numero totale di nemici [param total_budget] e di ondate [param waves] definsico
## quanti nemici devono esserci per ondata.
func _build_wave_plan(total_budget: int, waves: int) -> Array[int]:
	var plan: Array[int] = []
	## Calcolo in quante ondate vengono distribuiti tutti i nemici da istanziare.
	var base: int = total_budget / waves
	var rem: int = total_budget % waves
	
	for i in range(waves): plan.append(base)
	
	for i in range(rem): plan[waves - 1 - i] += 1
	
	return plan

## Metodo che restituisce una lista di nemici calcolata sulla base della difficoltà della stanza
## [param room_difficulty], quella del livello [param run_level] e sul budget disponibile [param budget].
func _chose_enemys(room_difficulty: int, run_level: int, budget: int) -> Array[EnemiesRegistry.ID]:
	var out: Array[EnemiesRegistry.ID] = []
	if enemy_table.is_empty() or budget <= 0: return out
	
	var run_difficulty: float = float(run_level) + float(room_difficulty) * DAMPING_COEFFICENT
	var remaining : int = budget
	
	var counts: Dictionary[EnemiesRegistry.ID, int] = {}
	
	var safety : int = 10_000
	
	while remaining > 0 and safety > 0:
		safety -= 1
		
		var candidates: Array[EnemyId_Weight] = []
		for id in enemy_table.keys():
			var enemy: Enemy = enemy_table.get(id)
			
			var weighed_enemy: float = _compute_spawn_weight(enemy, run_difficulty)
			if weighed_enemy <= 0.0: continue
			
			if enemy.cost > remaining: continue
			
			## Se ho raggiunto il numero massimo di nemici per quella stanza passa alla prossima 
			## iterazione del ciclo.
			var current_enemy_count: int = counts.get(id, 0)
			if current_enemy_count >= enemy.max_per_room: continue
			
			candidates.append(EnemyId_Weight.new(id, weighed_enemy))
		
		if candidates.is_empty(): break
		
		var picked_id: EnemiesRegistry.ID = _pick_enemy_weighted(candidates)
		var picked_enemy: Enemy = enemy_table[picked_id]
		
		out.append(picked_id)
		counts[picked_id] = counts.get(picked_id, 0) + 1
		remaining -= picked_enemy.cost
			
	return out

## Metodo privato utilizzato per selezionare l'identificativo da una lista [param candidates] in base 
## al peso contenuto in [class EnemyId_Weight].
func _pick_enemy_weighted(candidates: Array[EnemyId_Weight]) -> EnemiesRegistry.ID:
	var total: float = 0.0
	for candiate in candidates: total += candiate.weight
	
	var rng : float = Rng.randf() * total
	for candidate in candidates:
		rng -= candidate.weight
		if rng <= 0.0: return candidate.id
		
	return candidates.back().id

#func _make_waves() -> int:
	

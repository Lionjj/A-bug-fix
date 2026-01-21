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
## Budget di base dipsonibile per una stanza
@export var base_budget: int = 3
## Moltiplicatore del budget per livello
@export var budget_per_level : float = 1.2
## Mottiplicatore per la difficoltà del livello
@export var room_diff_mult: float = 0.35

## Limite inferiore del moltiplicatore del budget
const LOGIC_BUDGET_MULT_MIN: float = 0.5
## Limite superiore del moltiplicatore del budget
const LOGIC_BUDGET_MULT_MAX: float = 2.5
## Coefficente di smorzamento usato per evitare che la difficolta cresca troppo velocemente.
const DAMPING_COEFFICENT: float = 0.8
## Distanza fra un nemico e l'altro
const MIN_DISTANCE: float = 48.0
## Limite inferiore di budget dipsonibile per una stanza
const MIN_BUDGET: int = 0
## Limite superiore di budget dipsonibile per una stanza
const MAX_BUDGET: int = 20

## Classe di supporto per la scelta pesata dei nemici, vedi anche: [method chose_enemys]
class EnemyId_Weight:
	var id : EnemiesRegistry.ID
	var weight: float
	
	func _init(_id: EnemiesRegistry.ID, _weight: float) -> void:
		id = _id
		weight = _weight
	
	
## Individua un insieme di n: [param slots_count] all'itnerno della stanza [param room].
func get_spawn_points(room: RoomTemplateMeta, slots_count: int) -> Array[Vector2i]:
	var inner_cells: Array[Vector2i] = room.spawn_points
	if inner_cells.is_empty(): return []
	
	var spawnable_air_cells: Array[Vector2i] = SmartPlacement.get_floor_air_cells(room, inner_cells)
	if spawnable_air_cells.is_empty(): return []
	
	return SmartPlacement.beautify(spawnable_air_cells, slots_count)

## Trova uno spazio libero tra quelli disponibili [param slots] mantenendo una distanza minima [param min_dist]
## tra i nemici vivi [param alive_enemies].
func find_free_slot_index(slots: Array[Vector2i], alive_enemies: Array[EnemyEntity], tilemap: TileMapLayer ,min_dist: float = MIN_DISTANCE) -> int:
	for i: int in range(slots.size()):
		var current: Vector2i = slots[i]
		var ok: bool = true
		for enemy: EnemyEntity in alive_enemies:
			var real_current: Vector2 = SmartPlacement.cell_to_world_position(tilemap, current)
			if enemy.global_position.distance_to(real_current) >= min_dist: continue
			
			ok = false
			break
		
		if ok: return i
	return -1

## Istanzia nella stanza [param room] il nemico idetificato da [param enemy_id] nelle poszioni possibili [param slots]
## aggiornando lo stato dei nemici nella stanza [param room_enemy_state].
func spawn_enemy_at_free_slot(room: RoomTemplateMeta, room_enemy_state: RoomEnemyState, enemy_id: EnemiesRegistry.ID, slots: Array[Vector2i]) -> EnemyEntity:
	var data : Enemy = enemy_table[enemy_id]
	var inst: EnemyEntity = data.scene.instantiate()
	
	room.add_child(inst)
	
	room_enemy_state.enemies_references.append(inst)
	room_enemy_state.to_eliminate += 1
	
	var idx: int = Rng.randi() % slots.size()
	
	inst.global_position = SmartPlacement.cell_to_world_position(room.collision, slots[idx], inst.spawn_offset)
	inst.hide_entity()
	
	return inst

## Istanzia una lista di nemici [param enemies] nelle posizioni possibili [param slots] all'iterno della stanza [param room] aggiornado lo stato
## dei nemici nella stanza [param room_enemy_state].
func istanziate_in_position(slots: Array[Vector2i], enemies : Array[EnemiesRegistry.ID], room: RoomTemplateMeta, room_enemy_state: RoomEnemyState):
	var pos = slots.duplicate()
	
	for enemy: EnemiesRegistry.ID in enemies:
		spawn_enemy_at_free_slot(room, room_enemy_state, enemy, slots)
	
	var e_list: Array[EnemyEntity] = room_enemy_state.enemies_references
	for enemy: EnemyEntity in e_list:
		var idx : int = find_free_slot_index(slots, e_list, room.collision)
		if idx == -1: continue
		
		enemy.global_position = SmartPlacement.cell_to_world_position(room.collision, slots[idx], enemy.spawn_offset)

## Calcola il buget che la stanza [param room] possiede per livello [param run_level], questo indica 
## il numero di nemcici che possiamo isnerire per stanza.
func compute_budget(run_level: int , room: RoomTemplateMeta) -> int:
	var budget : int = base_budget + int(round(float(run_level) * budget_per_level))
	budget = int(round(float(budget) * (1.0 + float(room.logic_node.diff - 1) * room_diff_mult)))
	budget = int(round(float(budget) * clamp(room.logic_node.enemy_directive.budget_mult, LOGIC_BUDGET_MULT_MIN, LOGIC_BUDGET_MULT_MAX)))
	
	return clamp(budget, MIN_BUDGET, MAX_BUDGET)

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
func build_wave_plan(total_budget: int, waves: int) -> Array[int]:
	var plan: Array[int] = []
	## Calcolo in quante ondate vengono distribuiti tutti i nemici da istanziare.
	var base: int = total_budget / waves
	var rem: int = total_budget % waves
	
	for i in range(waves): plan.append(base)
	
	for i in range(rem): plan[waves - 1 - i] += 1
	
	return plan

## Metodo che restituisce una lista di nemici calcolata sulla base della difficoltà della stanza
## [param room_difficulty], quella del livello [param run_level] e sul budget disponibile [param budget].
func chose_enemys(room_difficulty: int, run_level: int, budget: int) -> Array[EnemiesRegistry.ID]:
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
	

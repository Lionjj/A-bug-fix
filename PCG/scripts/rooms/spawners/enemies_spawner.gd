# ============================================================================
# EnemiesSpawner
# ============================================================================
## Modulo responsabile della selezione, pianificazione e istanziazione
## dei nemici all'interno di una stanza.
##
## Responsabilità:
## - Calcolare il budget di nemici per stanza
## - Selezionare i tipi di nemici in modo pesato
## - Individuare celle candidate di spawn
## - Posizionare i nemici rispettando una distanza minima iniziale
##
## Note di design:
## - I nemici sono entità MOBILI
## - NON occupano celle in modo permanente
## - NON usano footprint o RoomPlacementManager.reserve()
## - La validazione è solo iniziale (spawn-time)
##
## Coordinate:
## - Le celle (Vector2i) servono solo come punti di partenza
## - Le distanze sono valutate in world-space (pixel)
# ============================================================================

extends Node
class_name EnemiesSpawner


# ---------------------------------------------------------------------------
# Enemy catalog
# ---------------------------------------------------------------------------

## Catalogo dei nemici disponibili.
## - Chiave: EnemiesRegistry.ID
## - Valore: Enemy (costo, scena, peso, range di difficoltà, max_per_room)
@export var enemy_table: Dictionary[EnemiesRegistry.ID, Enemy] = {
	EnemiesRegistry.ID.MINION: Enemy.new(
		EnemiesRegistry.ID.MINION,
		1,
		load("res://Scenes/Enemy/Minion.tscn"),
		1.0,
		0.0,
		9999.0,
		10
	),
	EnemiesRegistry.ID.GUNNER: Enemy.new(
		EnemiesRegistry.ID.GUNNER,
		2,
		load("res://Scenes/Enemy/Gunner.tscn"),
		0.55,
		2.0,
		9999.0,
		4
	),
}


# ---------------------------------------------------------------------------
# Budget parameters
# ---------------------------------------------------------------------------

## Budget base disponibile per stanza.
@export var base_budget: int = 3

## Incremento del budget per livello.
@export var budget_per_level: float = 1.2

## Moltiplicatore del budget in base alla difficoltà della stanza.
@export var room_diff_mult: float = 0.35

## Limite minimo del moltiplicatore logico.
const LOGIC_BUDGET_MULT_MIN: float = 0.5
## Limite massimo del moltiplicatore logico.
const LOGIC_BUDGET_MULT_MAX: float = 2.5

## Coefficiente di smorzamento della progressione di difficoltà.
const DAMPING_COEFFICENT: float = 0.8

## Distanza minima iniziale (in pixel) tra nemici spawnati.
const MIN_DISTANCE: float = 48.0

## Limiti assoluti di budget.
const MIN_BUDGET: int = 0
const MAX_BUDGET: int = 20


# ---------------------------------------------------------------------------
# Support types
# ---------------------------------------------------------------------------

## Classe di supporto per la selezione pesata dei nemici.
class EnemyId_Weight:
	var id: EnemiesRegistry.ID
	var weight: float

	func _init(_id: EnemiesRegistry.ID, _weight: float) -> void:
		id = _id
		weight = _weight


# ---------------------------------------------------------------------------
# Spawn points
# ---------------------------------------------------------------------------

## Restituisce un insieme di celle candidate per lo spawn dei nemici.
##
## Usa solo celle aria su pavimento e le distribuisce
## tramite [method SmartPlacement.beautify].
##
## [param room] Stanza target.
## [param rng] Generatore randomico basato sul seed del livello.[br]
## [param slots_count] Numero di punti richiesti.
##
## @return Array di celle candidate (Vector2i).
func get_spawn_points(room: RoomTemplateMeta, rng: RandomNumberGenerator, slots_count: int) -> Array[Vector2i]:
	var spawnable_air_cells: Array[Vector2i] = room.placement.floor_air_cells
	if spawnable_air_cells.is_empty():
		return []

	return SmartPlacement.beautify(spawnable_air_cells, rng ,slots_count)


# ---------------------------------------------------------------------------
# Slot validation
# ---------------------------------------------------------------------------

## Trova un indice valido in [param slots] tale che la posizione
## rispetti una distanza minima da tutti i nemici vivi.
##
## [param slots] Celle candidate.
## [param alive_enemies] Nemici già istanziati e vivi.
## [param tilemap] TileMapLayer della stanza.
## [param min_dist] Distanza minima in pixel.
##
## @return Indice valido oppure -1 se nessuna posizione è valida.
func find_free_slot_index(
	slots: Array[Vector2i],
	alive_enemies: Array[EnemyEntity],
	tilemap: TileMapLayer,
	min_dist: float = MIN_DISTANCE
) -> int:
	for i: int in range(slots.size()):
		var cell: Vector2i = slots[i]
		var world_pos: Vector2 = SmartPlacement.cell_to_world_position(tilemap, cell)
		
		var is_blocked: bool = false

		for enemy: EnemyEntity in alive_enemies:
			if enemy.global_position.distance_to(world_pos) >= min_dist:
				continue
			
			is_blocked = true
			break
			
		if is_blocked: continue
		
		return i
		
	return -1


# ---------------------------------------------------------------------------
# Spawn single enemy
# ---------------------------------------------------------------------------

## Istanzia un singolo nemico in una posizione casuale tra gli slot disponibili.
##
## Nota:
## - Non riserva celle
## - Non verifica footprint
## - Il posizionamento finale viene raffinato successivamente
##
## [param room] Stanza target.
## [param room_enemy_state] Stato runtime dei nemici.
## [param enemy_id] ID del nemico da istanziare.
## [param slots] Celle candidate.
## [param rng] Generatore randomico basato sul seed del livello.[br]
##
## @return Istanza del nemico creata.
func spawn_enemy_at_free_slot(
	room: RoomTemplateMeta,
	room_enemy_state: RoomEnemyState,
	enemy_id: EnemiesRegistry.ID,
	slots: Array[Vector2i],
	rng: RandomNumberGenerator
) -> EnemyEntity:
	var data: Enemy = enemy_table[enemy_id]
	var inst: EnemyEntity = data.scene.instantiate()

	room.add_child(inst)

	room_enemy_state.enemies_references.append(inst)
	room_enemy_state.to_eliminate += 1

	var idx: int = rng.randi() % slots.size()
	inst.global_position = SmartPlacement.cell_to_world_position(
		room.collision,
		slots[idx],
		inst.spawn_offset
	)

	inst.hide_entity()
	return inst


# ---------------------------------------------------------------------------
# Spawn batch
# ---------------------------------------------------------------------------

## Istanzia una lista di nemici distribuendoli nello spazio
## in modo da rispettare la distanza minima iniziale.
##
## [param slots] Celle candidate.
## [param enemies] Lista di ID nemici da spawnare.
## [param room] Stanza target.
## [param room_enemy_state] Stato runtime dei nemici.
## [param rng] Generatore randomico basato sul seed del livello.[br]
func istanziate_in_position(
	slots: Array[Vector2i],
	enemies: Array[EnemiesRegistry.ID],
	room: RoomTemplateMeta,
	room_enemy_state: RoomEnemyState,
	rng: RandomNumberGenerator
) -> void:
	for enemy_id: EnemiesRegistry.ID in enemies:
		spawn_enemy_at_free_slot(room, room_enemy_state, enemy_id, slots, rng)

	var alive: Array[EnemyEntity] = room_enemy_state.enemies_references
	for enemy: EnemyEntity in alive:
		var idx: int = find_free_slot_index(slots, alive, room.collision)
		if idx == -1:
			continue

		enemy.global_position = SmartPlacement.cell_to_world_position(
			room.collision,
			slots[idx],
			enemy.spawn_offset
		)


# ---------------------------------------------------------------------------
# Budget computation
# ---------------------------------------------------------------------------

## Calcola il budget di nemici disponibile per una stanza.
##
## [param run_level] Livello corrente della run.
## [param room] Stanza target.
##
## @return Budget finale clampato.
func compute_budget(run_level: int, room: RoomTemplateMeta) -> int:
	var budget: int = base_budget + int(round(run_level * budget_per_level))
	budget = int(round(budget * (1.0 + float(room.logic_node.diff - 1) * room_diff_mult)))
	budget = int(round(
		budget * clamp(
			room.logic_node.enemy_directive.budget_mult,
			LOGIC_BUDGET_MULT_MIN,
			LOGIC_BUDGET_MULT_MAX
		)
	))

	return clamp(budget, MIN_BUDGET, MAX_BUDGET)


# ---------------------------------------------------------------------------
# Enemy selection (weighted)
# ---------------------------------------------------------------------------

## Calcola il peso di spawn di un nemico in funzione della difficoltà.
##
## [param enemy] Dati del nemico.
## [param difficulty] Difficoltà complessiva.
##
## @return Peso finale (0 se non spawnabile).
func _compute_spawn_weight(enemy: Enemy, difficulty: float) -> float:
	if difficulty < enemy.min_difficulty:
		return 0.0
	if difficulty > enemy.max_difficulty:
		return 0.0

	var window: float = max(0.0001, enemy.max_difficulty - enemy.min_difficulty)
	var progression: float = clamp((difficulty - enemy.min_difficulty) / window, 0.0, 1.0)

	var rarity_ramp: float = progression * progression
	return enemy.weight * (0.3 + 0.7 * rarity_ramp)


## Costruisce il piano di distribuzione dei nemici per ondate.
##
## [param total_budget] Numero totale di nemici.
## [param waves] Numero di ondate.
##
## @return Array con il numero di nemici per ondata.
func build_wave_plan(total_budget: int, waves: int) -> Array[int]:
	var plan: Array[int] = []
	var base: int = total_budget / waves
	var rem: int = total_budget % waves

	for _i in range(waves):
		plan.append(base)

	for i in range(rem):
		plan[waves - 1 - i] += 1

	return plan


## Seleziona una lista di nemici in base a difficoltà e budget.
##
## [param room_difficulty] Difficoltà della stanza.
## [param run_level] Livello corrente.
## [param budget] Budget disponibile.
## [param rng] Generatore randomico basato sul seed del livello.[br]
##
## @return Lista di ID nemici.
func chose_enemys(room_difficulty: int, run_level: int, budget: int, rng: RandomNumberGenerator) -> Array[EnemiesRegistry.ID]:
	var out: Array[EnemiesRegistry.ID] = []
	if enemy_table.is_empty() or budget <= 0:
		return out

	var run_difficulty: float = float(run_level) + room_difficulty * DAMPING_COEFFICENT
	var remaining: int = budget
	var counts: Dictionary[EnemiesRegistry.ID, int] = {}
	var safety: int = 10_000

	while remaining > 0 and safety > 0:
		safety -= 1

		var candidates: Array[EnemyId_Weight] = []

		for id: EnemiesRegistry.ID in enemy_table.keys():
			var enemy: Enemy = enemy_table[id]
			var weight: float = _compute_spawn_weight(enemy, run_difficulty)

			if weight <= 0.0:
				continue
			if enemy.cost > remaining:
				continue
			if counts.get(id, 0) >= enemy.max_per_room:
				continue

			candidates.append(EnemyId_Weight.new(id, weight))

		if candidates.is_empty():
			break

		var picked: EnemiesRegistry.ID = _pick_enemy_weighted(candidates, rng)
		out.append(picked)
		counts[picked] = counts.get(picked, 0) + 1
		remaining -= enemy_table[picked].cost

	return out


## Pick pesato di un nemico da una lista di candidati.
##
## [param candidates] Lista di EnemyId_Weight.
## [param rng] Generatore randomico basato sul seed del livello.[br]
##
## @return ID del nemico selezionato.
func _pick_enemy_weighted(candidates: Array[EnemyId_Weight], rng: RandomNumberGenerator) -> EnemiesRegistry.ID:
	var total: float = 0.0
	for c: EnemyId_Weight in candidates:
		total += c.weight

	var roll: float = rng.randf() * total
	for c: EnemyId_Weight in candidates:
		roll -= c.weight
		if roll <= 0.0:
			return c.id

	return candidates.back().id

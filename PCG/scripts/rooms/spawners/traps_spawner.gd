# ============================================================================
# TrapsSpawner
# ============================================================================
## Modulo che gestisce lo spawn delle trappole nelle stanze.[br]
##
## Responsabilità principali:[br]
## - Selezionare quali trappole spawnare in base a budget e difficoltà (peso dinamico).[br]
## - Calcolare punti di spawn validi a partire da candidati geometrici (pit/nicchie).[br]
## - Evitare soft-lock tramite policy di protezione (reachability basata sul salto del player).[br]
##
## Convenzioni:[br]
## - Tutto ragiona in CELLE ([Vector2i]).[br]
## - Le liste geometriche (floor_air_cells / trap_candidate_cells / spawnable_cells_list) arrivano da
##   [member RoomTemplateMeta.placement] ([RoomPlacementManager]).[br]
## - Il filtro anti soft-lock è demandato a [TrapPlcacementPolicy].[br]
# ============================================================================

extends Node
class_name TrapsSpawner

# ---------------------------------------------------------------------------
# Tabella trappole (binding id → dati trappola)
# ---------------------------------------------------------------------------

## Catalogo delle trappole disponibili.[br]
## - Chiave: [TrapRegistry.ID].[br]
## - Valore: [Trap] (costo, max_per_room, difficoltà min/max, peso base, scena).[br]
@export var trap_table: Dictionary[TrapRegistry.ID, Trap] = {
	TrapRegistry.ID.DAMAGED_BIT: Trap.new(
		TrapRegistry.ID.DAMAGED_BIT,
		1,
		load("res://Scenes/Interactable/damaged_bit_trap.tscn")
	)
}

# ---------------------------------------------------------------------------
# Budget (base + scaling difficoltà)
# ---------------------------------------------------------------------------

## Budget base disponibile per una stanza (prima dei moltiplicatori).
@export var base_budget: int = 1

## Incremento budget in funzione del livello di run.[br]
## Esempio: run_level * budget_per_level.
@export var budget_per_level: float = 0.8

## Moltiplicatore aggiuntivo in base alla difficoltà logica della stanza.[br]
## Usa [member RoomTemplateMeta.logic_node.diff].
@export var room_diff_mult: float = 0.25

## Limite inferiore del moltiplicatore di budget imposto dalla direttiva logica stanza.
const LOGIC_BUDGET_MULT_MIN: float = 0.5
## Limite superiore del moltiplicatore di budget imposto dalla direttiva logica stanza.
const LOGIC_BUDGET_MULT_MAX: float = 2.5

## Coefficiente di smorzamento per evitare una crescita troppo rapida della difficoltà percepita.
const DAMPING_COEFFICENT: float = 0.8

# ---------------------------------------------------------------------------
# Trap candidate policy (pit / nicchie)
# ---------------------------------------------------------------------------

## Profondità minima di un pozzo (“pit”) per considerarlo valido.
const MIN_PIT_DEPTH: int = 3
## Offset dal fondo del pit per scegliere la cella target (evita il fondo assoluto).
const PIT_BOTTOM_OFFSET: int = 1

# ---------------------------------------------------------------------------
# Limiti budget + fairness
# ---------------------------------------------------------------------------

## Budget minimo clampato per stanza.
const MIN_BUDGET: int = 0
## Budget massimo clampato per stanza.
const MAX_BUDGET: int = 12

## Distanza minima (in celle) dall'entry della stanza per evitare spawn “ingiusti”.
const MIN_DIST_FROM_ENTRY: int = 5

# ---------------------------------------------------------------------------
# Weighted picking tuning (no magic numbers)
# ---------------------------------------------------------------------------

## Safety cap del loop di picking (evita while infinito se qualcosa va storto).
const PICK_LOOP_SAFETY_MAX: int = 10_000

## Epsilon per evitare divisione per zero nella normalizzazione della finestra.
const DIFF_WINDOW_EPS: float = 0.0001

## Parametri della rampa del peso: BASE 
const WEIGHT_RAMP_BASE: float = 0.3
## Parametri della rampa del peso: SCALE 
const WEIGHT_RAMP_SCALE: float = 0.7
## Parametri della rampa del peso: prog^POW
const WEIGHT_RAMP_POWER: float = 2.0

# ---------------------------------------------------------------------------
# Support Types
# ---------------------------------------------------------------------------

## Classe di supporto per la scelta pesata delle trappole.[br]
## Vedi [method chose_traps].
class TrapId_Weight:
	var id: TrapRegistry.ID
	var weight: float

	func _init(_id: TrapRegistry.ID, _weight: float) -> void:
		id = _id
		weight = _weight

# ---------------------------------------------------------------------------
# Spawn points
# ---------------------------------------------------------------------------

## Individua un insieme di celle di spawn per le trappole.[br]
##
## Pipeline:[br]
## 1) Prende candidati geometrici da [member room.placement.trap_candidate_cells].[br]
## 2) Calcola la reachability del player (altezza salto in tiles) e costruisce celle protette.[br]
## 3) Filtra candidati “non bloccati” dalla protezione anti soft-lock.[br]
## 4) Ordina e valuta con [method SmartPlacement.score_list] (topologia + fairness entry).[br]
## 5) Applica [method SmartPlacement.beautify] per distribuire i pick.[br]
##
## [param room] Stanza target.[br]
## [param slots_count] Numero di slot richiesti (quante celle finali vuoi ottenere).[br]
## [param player] Player usato per stimare la reachability (jump_velocity + gravity).[br]
## [param rng] Generatore randomico basato sul seed del livello.[br]
##
## @return Lista di celle (Vector2i) pronte per l'istanziamento.
func get_spawn_points(room: RoomTemplateMeta, slots_count: int, player: Player, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var inner_cells: Array[Vector2i] = room.placement.spawnable_cells_list
	if inner_cells.is_empty():
		return []

	var candidates: Array[Vector2i] = room.placement.trap_candidate_cells
	if candidates.is_empty():
		return []

	var walkable: Array[Vector2i] = room.placement.floor_air_cells
	if walkable.is_empty():
		return []

	## Stima reach verticale del player in “tiles”
	var tile_size_y: int = room.collision.tile_set.tile_size.y
	var jump_tiles: float = TrapPlcacementPolicy.compute_jump_height_tiles(
		abs(player.jump_velocity),
		player.gravity,
		tile_size_y
	)
	var wall_reach_tiles: int = int(ceil(jump_tiles)) + TrapPlcacementPolicy.WALL_JUMP_MARGIN_TILES

	## Celle protette (non piazzabili per evitare soft-lock)
	var protected_cells: Dictionary[Vector2i, bool] = TrapPlcacementPolicy.build_protected_cells(
		inner_cells,
		walkable,
		wall_reach_tiles
	)

	## Filtra candidati che “rompono” la reachability
	candidates = TrapPlcacementPolicy.filter_not_blocked(candidates, protected_cells)
	if candidates.is_empty():
		return []

	## Fairness + scoring topologico (corridoi / dead-end / near wall, ecc.)
	var scored_list: Array[Vector2i] = SmartPlacement.score_list(
		room,
		candidates,
		slots_count,
		rng,
		MIN_DIST_FROM_ENTRY
	)
	if scored_list.is_empty():
		return []

	## Distribuzione estetica / spaziale
	return SmartPlacement.beautify(scored_list, rng, slots_count)

# ---------------------------------------------------------------------------
# Instantiation
# ---------------------------------------------------------------------------

## Istanzia le trappole nelle celle selezionate.[br]
## NOTA: qui non stai ancora riservando celle nel PlacementManager: se vuoi evitare
## conflitti con altri spawn (deco/item/nemici) conviene fare anche:[br]
## - can_place() prima[br]
## - reserve() dopo[br]
##
## [param slots] Lista di celle disponibili (ordine = ordine spawn).[br]
## [param traps] Lista di [TrapRegistry.ID] da spawnare.[br]
## [param room] Stanza target.[br]
## [param trap_state] Stato runtime per tracciare le reference alle trappole istanziate.[br]
func instantiate_in_position(
	slots: Array[Vector2i],
	traps: Array[TrapRegistry.ID],
	room: RoomTemplateMeta,
	trap_state: RoomTrapState
) -> void:
	var slots_copy: Array[Vector2i] = slots.duplicate()

	for t: TrapRegistry.ID in traps:
		if slots_copy.is_empty():
			return

		var data: Trap = trap_table.get(t)
		if data == null:
			continue

		var inst: TrapEntity = data.scene.instantiate() as TrapEntity
		if inst == null:
			continue

		room.add_child(inst)

		var cell: Vector2i = slots_copy.pop_front()
		inst.global_position = SmartPlacement.cell_to_world_position(room.collision, cell)

		trap_state.traps_references.append(inst)

# ---------------------------------------------------------------------------
# Budget calculation
# ---------------------------------------------------------------------------

## Calcola il budget disponibile per la stanza, dato:[br]
## - livello della run (run_level)[br]
## - difficoltà della stanza (room.logic_node.diff)[br]
## - direttiva di budget del nodo logico (room.logic_node.trap_directive.budget_mult)[br]
##
## [param run_level] Livello corrente della run (progressione globale).[br]
## [param room] Stanza target da cui leggere difficoltà e direttive.[br]
##
## @return Budget finale clampato tra [constant MIN_BUDGET] e [constant MAX_BUDGET].
func compute_budget(run_level: int, room: RoomTemplateMeta) -> int:
	var budget: int = base_budget + int(round(float(run_level) * budget_per_level))

	## Moltiplicatore in base alla difficoltà della stanza (diff parte da 1)
	budget = int(round(float(budget) * (1.0 + float(room.logic_node.diff - 1) * room_diff_mult)))

	## Moltiplicatore da direttiva logica (clampato)
	var mult: float = clamp(
		room.logic_node.trap_directive.budget_mult,
		LOGIC_BUDGET_MULT_MIN,
		LOGIC_BUDGET_MULT_MAX
	)
	budget = int(round(float(budget) * mult))

	return clamp(budget, MIN_BUDGET, MAX_BUDGET)

# ---------------------------------------------------------------------------
# Trap picking (weighted)
# ---------------------------------------------------------------------------

## Sceglie quali trappole spawnare, rispettando:[br]
## - budget disponibile (trap.cost)[br]
## - max_per_room[br]
## - finestra di difficoltà (min/max) → peso dinamico[br]
##
## [param room_difficulty] Difficoltà della stanza (valore logico).[br]
## [param run_level] Livello corrente della run.[br]
## [param budget] Budget disponibile per la stanza.[br]
## [param rng] Generatore randomico basato sul seed del livello.[br]
##
## @return Array di [TrapRegistry.ID] nell'ordine di spawn.
func chose_traps(room_difficulty: int, run_level: int, budget: int, rng: RandomNumberGenerator) -> Array[TrapRegistry.ID]:
	var out: Array[TrapRegistry.ID] = []
	if trap_table.is_empty():
		return out
	if budget <= 0:
		return out

	## Difficoltà “effettiva” usata per pesare le trappole
	var run_difficulty: float = float(run_level) + float(room_difficulty) * DAMPING_COEFFICENT
	var remaining: int = budget

	var counts: Dictionary[TrapRegistry.ID, int] = {}
	var safety: int = PICK_LOOP_SAFETY_MAX

	while remaining > 0 and safety > 0:
		safety -= 1

		var candidates: Array[TrapId_Weight] = []

		for id: TrapRegistry.ID in trap_table.keys():
			var trap: Trap = trap_table.get(id)
			if trap == null:
				continue

			var weighted_trap: float = _compute_spawn_weight(trap, run_difficulty)
			if weighted_trap <= 0.0:
				continue

			if trap.cost > remaining:
				continue

			var current_trap_count: int = counts.get(id, 0)
			if current_trap_count >= trap.max_per_room:
				continue

			candidates.append(TrapId_Weight.new(id, weighted_trap))

		if candidates.is_empty():
			break

		var picked_id: TrapRegistry.ID = _pick_trap_weighted(candidates, rng)
		var picked_trap: Trap = trap_table[picked_id]

		out.append(picked_id)
		counts[picked_id] = counts.get(picked_id, 0) + 1
		remaining -= picked_trap.cost

	return out

## Pick pesato su una lista di candidati.[br]
##
## [param candidates] Lista di coppie (id, weight) con weight > 0.[br]
## [param rng] Generatore randomico basato sul seed del livello.[br]
##
## @return ID selezionato (fallback: ultimo candidato).
func _pick_trap_weighted(candidates: Array[TrapId_Weight], rng: RandomNumberGenerator) -> TrapRegistry.ID:
	var total: float = 0.0
	for c: TrapId_Weight in candidates:
		total += c.weight

	var rng_weight: float = rng.randf() * total
	for c: TrapId_Weight in candidates:
		rng_weight -= c.weight
		if rng_weight <= 0.0:
			return c.id

	return candidates.back().id

## Calcola il peso dinamico di una trappola in base alla difficoltà.[br]
## - Fuori dalla finestra [min_difficulty, max_difficulty] → peso 0.[br]
## - Dentro la finestra → rampa (prog^POW) per aumentare gradualmente.[br]
##
## [param trap] Dati della trappola (min/max difficulty, weight base).[br]
## [param difficulty] Difficoltà effettiva corrente (run_level + room_difficulty smorzata).[br]
##
## @return Peso finale (>= 0).
func _compute_spawn_weight(trap: Trap, difficulty: float) -> float:
	if difficulty < trap.min_difficulty:
		return 0.0
	if difficulty > trap.max_difficulty:
		return 0.0

	var window: float = max(DIFF_WINDOW_EPS, trap.max_difficulty - trap.min_difficulty)
	var prog: float = (difficulty - trap.min_difficulty) / window
	prog = clamp(prog, 0.0, 1.0)

	## Rampa controllata via costanti (niente magic number)
	var rarity_ramp: float = pow(prog, WEIGHT_RAMP_POWER)
	return trap.weight * (WEIGHT_RAMP_BASE + WEIGHT_RAMP_SCALE * rarity_ramp)

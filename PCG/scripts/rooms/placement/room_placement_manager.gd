# ============================================================================
# RoomPlacementManager
# ============================================================================
## Gestore centrale del piazzamento per una singola stanza.
##
## Responsabilità:
## - Conservare l’insieme delle celle SPAWNABILI (geometria valida)
## - Conservare l’insieme delle celle BLOCCATE (occupazione + buffer distanza)
## - Fornire un’API unica per:
##     - verificare se una posizione è valida
##     - riservare celle dopo uno spawn riuscito
##
## Tutti gli spawner (decorazioni, oggetti, nemici, trappole, ecc.)
## DEVONO passare da questo manager per garantire:
## - distanza minima reciproca
## - assenza di conflitti tra sistemi diversi
##
## Coordinate:
## - Tutto è espresso in CELLE ([Vector2i])
## - Le distanze in pixel devono essere convertite in celle PRIMA
##
## Lifecycle:
## - Un'istanza per stanza ([RoomTemplateMeta])
## - Inizializzato una sola volta alla creazione della stanza
## ============================================================================

extends Node
class_name RoomPlacementManager


# ---------------------------------------------------------------------------
# Tuning constants (no magic numbers)
# ---------------------------------------------------------------------------

## Inclusività dei range: Godot range(a,b) esclude b, quindi usiamo +1 per includere il bordo.
const RANGE_INCLUSIVE_END_OFFSET: int = 1

## Fallback “sicuro” per footprint/gap negativi (non dovrebbe mai succedere).
const MIN_NON_NEGATIVE: int = 0


# ---------------------------------------------------------------------------
# Celle spawnabili (statiche)
# ---------------------------------------------------------------------------

## Set di celle interne alla stanza in cui è consentito lo spawn.
## Usato per controlli O(1).
var spawnable_cells: Dictionary[Vector2i, bool] = {}

## Lista parallela a [member spawnable_cells], usata per:
## - random pick
## - iterazioni sequenziali
var spawnable_cells_list: Array[Vector2i] = []


# ---------------------------------------------------------------------------
# Cache candidati (statiche, derivate dalla geometria)
# ---------------------------------------------------------------------------

## Celle aria sopra pavimento solido.
## Ideali per:
## - item
## - decorazioni GROUND
var floor_air_cells: Array[Vector2i] = []

## Celle aria con solido sopra.
## Ideali per:
## - decorazioni CEILING
var ceiling_air_cells: Array[Vector2i] = []

## Celle interne adiacenti a pareti.
## Ideali per:
## - decorazioni WALL
## - nicchie
var wall_recess_cells: Array[Vector2i] = []

## Celle candidate per trappole.
## Tipicamente:
## - pit
## - corridoi stretti
## - choke point
var trap_candidate_cells: Array[Vector2i] = []


# ---------------------------------------------------------------------------
# Celle bloccate (dinamiche)
# ---------------------------------------------------------------------------

## Set di celle attualmente occupate o interdette.
## Include:
## - footprint degli oggetti
## - buffer di distanza minima attorno agli oggetti
var blocked_cells: Dictionary[Vector2i, bool] = {}


# ---------------------------------------------------------------------------
# Inizializzazione
# ---------------------------------------------------------------------------

## Inizializza il PlacementManager a partire dalla geometria della stanza.
## Deve essere chiamato UNA SOLA VOLTA alla creazione della stanza.
##
## [param room] Stanza da cui ricavare la geometria e le celle spawnabili.
func init_from_room(room: RoomTemplateMeta) -> void:
	spawnable_cells.clear()
	spawnable_cells_list.clear()
	blocked_cells.clear()

	## Celle interne calcolate da SmartPlacement
	var internal_cells: Array[Vector2i] = SmartPlacement.compute_internal_cells(room)

	for cell: Vector2i in internal_cells:
		spawnable_cells[cell] = true
		spawnable_cells_list.append(cell)

	## Cache geometriche statiche
	floor_air_cells = SmartPlacement.get_floor_air_cells(room)
	ceiling_air_cells = SmartPlacement.get_ceiling_air_cells(room)
	wall_recess_cells = SmartPlacement.get_wall_recesses(room)
	trap_candidate_cells = SmartPlacement.get_trap_candidates(room)


## Resetta completamente lo stato di occupazione.
## Utile se la stanza viene rigenerata o riutilizzata.
func clear_blocked() -> void:
	blocked_cells.clear()


# ---------------------------------------------------------------------------
# Query di stato
# ---------------------------------------------------------------------------

## Ritorna true se la cella è spawnabile dal punto di vista geometrico.
##
## [param cell] Cella da verificare.
func is_spawnable(cell: Vector2i) -> bool:
	return spawnable_cells.has(cell)


## Ritorna true se la cella è attualmente bloccata.
##
## [param cell] Cella da verificare.
func is_blocked(cell: Vector2i) -> bool:
	return blocked_cells.has(cell)


# ---------------------------------------------------------------------------
# Verifica piazzamento
# ---------------------------------------------------------------------------

## Verifica se un oggetto può essere piazzato rispettando:
## - celle spawnabili
## - footprint
## - buffer di distanza minima globale
##
## NON modifica lo stato interno.
##
## [param center_cell] Cella centrale candidata.
## [param footprint_width_cells] Raggio del footprint in celle
##        (0 = solo la cella centrale).
## [param gap_cells] Buffer di distanza minima in celle.
##
## @return True se il piazzamento è valido.
func can_place(
	center_cell: Vector2i,
	footprint_width_cells: int,
	gap_cells: int
) -> bool:
	## Clamp difensivo: niente valori negativi
	var fp: int = max(MIN_NON_NEGATIVE, footprint_width_cells)
	var gap: int = max(MIN_NON_NEGATIVE, gap_cells)

	## La cella centrale deve essere spawnabile
	if not spawnable_cells.has(center_cell):
		return false

	## Celle occupate dall’oggetto (footprint)
	var occupied_cells: Array[Vector2i] = SmartPlacement.get_footprint_cells(center_cell, fp)

	## Tutte le celle del footprint devono essere spawnabili
	for cell: Vector2i in occupied_cells:
		if not spawnable_cells.has(cell):
			return false

	## Controllo collisione con celle bloccate,
	## includendo il buffer di distanza
	for cell: Vector2i in occupied_cells:
		var y0: int = cell.y - gap
		var y1: int = cell.y + gap + RANGE_INCLUSIVE_END_OFFSET
		var x0: int = cell.x - gap
		var x1: int = cell.x + gap + RANGE_INCLUSIVE_END_OFFSET

		for y: int in range(y0, y1):
			for x: int in range(x0, x1):
				if blocked_cells.has(Vector2i(x, y)):
					return false

	return true


# ---------------------------------------------------------------------------
# Riserva celle
# ---------------------------------------------------------------------------

## Riserva definitivamente le celle occupate da un oggetto.
## Blocca:
## - footprint
## - buffer di distanza attorno
##
## [param center_cell] Cella centrale piazzata.
## [param footprint_cells] Raggio footprint in celle.
## [param gap_cells] Buffer di distanza minima in celle.
func reserve(
	center_cell: Vector2i,
	footprint_cells: int,
	gap_cells: int
) -> void:
	## Clamp difensivo: niente valori negativi
	var fp: int = max(MIN_NON_NEGATIVE, footprint_cells)
	var gap: int = max(MIN_NON_NEGATIVE, gap_cells)

	var occupied_cells: Array[Vector2i] = SmartPlacement.get_footprint_cells(center_cell, fp)

	## Blocca footprint
	for cell: Vector2i in occupied_cells:
		blocked_cells[cell] = true

	## Blocca buffer di distanza
	for cell: Vector2i in occupied_cells:
		var y0: int = cell.y - gap
		var y1: int = cell.y + gap + RANGE_INCLUSIVE_END_OFFSET
		var x0: int = cell.x - gap
		var x1: int = cell.x + gap + RANGE_INCLUSIVE_END_OFFSET

		for y: int in range(y0, y1):
			for x: int in range(x0, x1):
				blocked_cells[Vector2i(x, y)] = true


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

## Converte una distanza in pixel in celle.
##
## [param px] Distanza in pixel.
## [param tile_size] Dimensione del tile (es. 16).
##
## @return Distanza equivalente in celle (arrotondata per eccesso).
static func px_to_cells(px: float, tile_size: int) -> int:
	return int(ceil(px / float(tile_size)))

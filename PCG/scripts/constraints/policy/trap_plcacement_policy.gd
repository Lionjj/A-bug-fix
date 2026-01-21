## Modulo di utilità utilizzato per verificare che le trappole non creino un
## soft-lock che impedisca al giocatore di proseguire nel gioco.
extends Node
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
##
##	- [param inner_cells]: celle interne della stanza (aria), coordinate locali;
##	- [param walkable_cells]: celle walkable (aria sopra pavimento), coordinate locali;
##	- [param near_walkable_radius]: raggio (in celle) attorno alle walkable da proteggere 
##	  (1 consigliato, 2 se vuoi più safe);
##	- [param wall_reach_tiles]: quanti tile di parete proteggere in verticale 
##	  (tipico: ceil(jump_height_tiles)+1);
static func build_protected_cells(
	inner_cells: Array[Vector2i],
	walkable_cells: Array[Vector2i],
	wall_reach_tiles: int,
	near_walkable_radius: int = NEAR_WALKABLE_RADIUS,
) -> Dictionary[Vector2i, bool]:
	var protected: Dictionary[Vector2i, bool] = {}
	var inner := _to_set(inner_cells)

	# (A) Protezione attorno alle walkable (non bloccare passaggi/step)
	for w in walkable_cells:
		for dx in range(-near_walkable_radius, near_walkable_radius + 1):
			for dy in range(-near_walkable_radius, near_walkable_radius + 1):
				protected[w + Vector2i(dx, dy)] = true

	# (B) Protezione pareti utili a wall-jump (adiacenti alle walkable)
	for w in walkable_cells:
		# parete sinistra: se non è interna => muro
		if !inner.has(w + Vector2i.LEFT):
			for t in range(0, wall_reach_tiles + 1):
				protected[w + Vector2i.LEFT + Vector2i(0, -t)] = true

		# parete destra
		if !inner.has(w + Vector2i.RIGHT):
			for t in range(0, wall_reach_tiles + 1):
				protected[w + Vector2i.RIGHT + Vector2i(0, -t)] = true

	return protected

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

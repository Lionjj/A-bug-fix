# ============================================================================
# GridPlacerBFS
# ============================================================================
## Modulo responsabile del piazzamento su griglia dei nodi del [MissionGraph]
## usando una visita BFS (breadth-first) a partire dallo start.[br]
##
## Responsabilità principali:[br]
## - Assegnare una cella [Vector2i] a ciascun nodo del grafo.[br]
## - Mantenere una mappa inversa "occupied" per lookup O(1) delle celle occupate.[br]
## - Gestire i nodi non piazzabili subito (deferred) con una passata di recovery.[br]
##
## Note architetturali:[br]
## - Il modulo è stateless: espone solo funzioni statiche.[br]
## - La scelta tra celle candidate usa [param rng] per determinismo controllato.[br]
## - La fase di recovery può modificare il grafo (add_edge / erase_edge) 
##   per mantenere connettività.[br]
# ============================================================================

extends RefCounted
class_name GridPlacerBFS


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

## Direzioni 4-neighbors (grid).
const DIRS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
]


# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------

## Risultato del placer. [br]
## [br]
## - [member positions] mappa { id -> Vector2i } con la cella assegnata a ciascun nodo. [br]
## - [member occupied]  mappa inversa { Vector2i -> id } per lookup O(1) delle celle occupate. [br]
## - [member _deferred] nodi rimandati perché senza spazio immediato. [br]
class Result:
	var positions: Dictionary[String, Vector2i] = {}
	var occupied: Dictionary[Vector2i, String] = {}
	var _deferred: Array[String] = []


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Assegna posizioni su griglia ai nodi del grafo usando BFS. [br]
## [br]
## Strategia: [br]
## 1) piazza lo start in (0,0); [br]
## 2) visita i vicini in BFS; [br]
## 3) per ogni vicino non ancora piazzato, sceglie una cella adiacente libera; [br]
## 4) se non ci sono celle libere, il nodo viene rimandato (_deferred) e gestito dopo. [br]
## [br]
## [param G] MissionGraph da piazzare. [br]
## [param rng] RandomNumberGenerator già seedato (deterministico se desiderato). [br]
## [return] [GridPlacerBFS.Result] con positions + occupied. [br]
static func place(G: MissionGraph, rng: RandomNumberGenerator) -> Result:
	var r: Result = Result.new()

	## Guard: grafo nullo o senza start
	if G == null:
		return r
	if String(G.start_id) == "":
		return r

	## 1) Start in (0,0)
	var start: String = String(G.start_id)
	r.positions[start] = Vector2i.ZERO
	r.occupied[Vector2i.ZERO] = start

	var queue: Array[String] = [start]

	## 2) BFS
	while not queue.is_empty():
		var u: String = queue.pop_front()
		var u_pos: Vector2i = r.positions[u]

		## Nota: neighbors può essere Array qualsiasi (String/Variant) → normalizzo a String
		for v_any in G.neighbors(u):
			var v: String = String(v_any)

			## già piazzato?
			if r.positions.has(v):
				continue

			## 3) candidate cells adiacenti libere
			var candidates: Array[Vector2i] = _free_adjacent_cells(u_pos, r.occupied)

			## nessuno spazio: rimando
			if candidates.is_empty():
				r._deferred.append(v)
				push_warning("Nessuna posizione disponibile vicino a %s per %s" % [u, v])
				continue

			## 4) scelta casuale tra candidates
			var chosen: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]

			## 5) registra posizione
			r.positions[v] = chosen
			r.occupied[chosen] = v
			queue.append(v)

	## 6) piazza i nodi rimandati (se presenti)
	if not r._deferred.is_empty():
		_place_deferred_nodes(G, r._deferred, r.positions, r.occupied, rng)

	return r


# ---------------------------------------------------------------------------
# Deferred recovery
# ---------------------------------------------------------------------------

## Prova a piazzare nodi rimandati (_deferred) agganciandoli a nodi già piazzati. [br]
## [br]
## Comportamento: [br]
## - cerca un adiacente già piazzato (anchor); [br]
## - se trova spazio, piazza e forza un edge (add_edge) verso l’anchor; [br]
## - se non trova spazio, rimuove edge (erase_edge) e cerca nuove anchor esplorando vicini già piazzati. [br]
## [br]
## Ottimizzazioni:[br]
## - evita duplicati nelle anchor (set di supporto). [br]
## - evita loop su anchor già testate senza progresso. [br]
## [br]
## [param G] MissionGraph da aggiornare (può aggiungere/rimuovere edge). [br]
## [param to_place] Lista nodi da piazzare. [br]
## [param positions] Mappa { id -> cell }. [br]
## [param occupied] Mappa { cell -> id }. [br]
## [param rng] RNG per scelta candidate cell. [br]
## [param last_room] Nodo da escludere, rappresenta l'ultima stanza dell'livello
## ala quale si accede da una sola altra stanza e che non ha altre stanze dopo.[br]
static func _place_deferred_nodes(
	G: MissionGraph,
	to_place: Array[String],
	positions: Dictionary[String, Vector2i],
	occupied: Dictionary[Vector2i, String],
	rng: RandomNumberGenerator,
	last_room: String = "B"
) -> void:
	var queue: Array[String] = to_place.duplicate()

	## Set di nodi già piazzati in questa fase (per evitare re-process)
	var done: Dictionary[String, bool] = {}

	while not queue.is_empty():
		var current: String = String(queue.pop_front())
		if positions.has(current):
			continue

		## Anchor candidates: vicini già piazzati
		var anchors: Array[String] = []
		var anchors_seen: Dictionary[String, bool] = {}  ## evita duplicati

		for a_any in G.neighbors(current):
			var a: String = String(a_any)
			if a == last_room:
				continue
			if positions.has(a) and not anchors_seen.has(a):
				anchors_seen[a] = true
				anchors.append(a)

		## Se non ho anchor piazzate, non posso fare nulla
		if anchors.is_empty():
			continue

		while not anchors.is_empty():
			var ad: String = anchors.pop_front()

			## Se current-ad non ha spazio, non voglio ciclare infinite volte sulle stesse anchor.
			## Lo gestisco espandendo anchor solo su nodi piazzati non ancora visti.
			var pos: Vector2i = positions[ad]
			var candidates: Array[Vector2i] = _free_adjacent_cells(pos, occupied)

			if not candidates.is_empty():
				var chosen: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]

				positions[current] = chosen
				occupied[chosen] = current
				done[current] = true

				## Forza collegamento (mantengo la tua semantica)
				G.add_edge(current, ad)

				## Espandi: se ho piazzato current, prova a piazzare anche i suoi vicini non ancora done
				for n_any in G.neighbors(current):
					var n: String = String(n_any)
					if n == ad:
						continue
					if done.has(n):
						continue
					if positions.has(n):
						continue
					if not queue.has(n):
						queue.append(n)

				break

			## Nessuno spazio attorno a questa anchor: prova a rimuovere edge e cercare alternative
			G.erase_edge(ad, current)

			## Espandi anchor set: vicini dell’anchor ad che sono già piazzati e non ancora visti
			for n_any in G.neighbors(ad):
				var n: String = String(n_any)
				if n == last_room:
					continue
				if positions.has(n) and not anchors_seen.has(n):
					anchors_seen[n] = true
					anchors.append(n)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Ritorna la lista di celle adiacenti libere (4-neighbors). [br]
## [br]
## [param pos] Cella di riferimento. [br]
## [param occupied] Mappa { cell -> id } per verificare occupazione. [br]
## [return] Array di [Vector2i] liberi. [br]
static func _free_adjacent_cells(pos: Vector2i, occupied: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		var c: Vector2i = pos + d
		if not occupied.has(c):
			out.append(c)
	return out

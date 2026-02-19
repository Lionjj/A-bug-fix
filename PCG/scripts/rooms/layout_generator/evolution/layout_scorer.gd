# ============================================================================
# LayoutScorer
# ============================================================================
## Questa classe assegna un punteggio di qualità ad una RoomLayoutMask.
##
## La fitness è:
## - Normalizzata nell'intervallo [0,1];
## - Basata su metriche morfologiche strutturali;
## - Separata dai vincoli di giocabilità (gestiti da TraversalAnalyzer).
##
## Le metriche valutano:
## - Equilibrio tra pieno e vuoto;
## - Distribuzione verticale delle piattaforme;
## - Monotonia orizzontale;
## - Simmetria strutturale.
# ============================================================================

class_name LayoutScorer
extends RefCounted


# ----------------------------------------------------------------------------
# CONFIGURAZIONE PESI
# ----------------------------------------------------------------------------

## Peso complessivo assegnato alla qualità strutturale della stanza.
## Valore in [0,1].
## Indica quanto la forma del layout incide sul punteggio finale.
## Un valore alto privilegia la morfologia rispetto alla novità.
const WEIGHT_STRUCTURE: float = 0.75


## Peso assegnato alla componente di novità.
## Valore in [0,1].
## Determina quanto il layout viene premiato per essere diverso
## da quelli già generati.
## WEIGHT_STRUCTURE + WEIGHT_NOVELTY dovrebbe essere = 1.
const WEIGHT_NOVELTY: float = 0.25


# ----------------------------------------------------------------------------
# PESI INTERNI DELLE METRICHE STRUTTURALI
# ----------------------------------------------------------------------------

## Peso della metrica di densità.
## Influenza quanto l'equilibrio tra pieno e vuoto
## contribuisce alla qualità strutturale.
const W_DENSITY: float = 1.0


## Peso della distribuzione verticale.
## Valuta l'uso dello spazio in altezza.
## Più è alto, più la verticalità incide sul punteggio.
const W_HEIGHT: float = 1.0


## Peso dell’asimmetria strutturale.
## Premia layout non speculari, evitando stanze troppo artificiali.
const W_ASYMMETRY: float = 1.0


## Peso dell’irregolarità orizzontale.
## Penalizza segmenti piatti e monotoni troppo lunghi.
const W_IRREGULARITY: float = 1.0


# ----------------------------------------------------------------------------
# PARAMETRI MORFOLOGICI
# ----------------------------------------------------------------------------

## Rapporto ideale tra celle solide e celle totali.
## Indica la densità strutturale desiderata.
## Un valore troppo alto produce stanze chiuse;
## troppo basso produce stanze vuote.
const IDEAL_SOLID_RATIO: float = 0.30


## Fattore di tolleranza per la densità.
## Controlla quanto velocemente il punteggio decresce
## quando il rapporto reale si allontana da quello ideale.
## Valori alti rendono la penalità più severa.
const DENSITY_TOLERANCE_FACTOR: float = 3.0


# ----------------------------------------------------------------------------
# PARAMETRI MONOTONIA ORIZZONTALE
# ----------------------------------------------------------------------------

## Soglia minima oltre la quale un segmento orizzontale
## viene considerato eccessivamente piatto.
## Rappresenta la proporzione della larghezza totale.
## Esempio: 0.4 significa 40% della larghezza.
const HORIZONTAL_RUN_THRESHOLD_RATIO: float = 0.4


# ----------------------------------------------------------------------------
# PARAMETRI NOVELTY
# ----------------------------------------------------------------------------

## Numero massimo di firme strutturali memorizzate.
## Serve a limitare memoria e costo computazionale.
## La novità viene calcolata solo rispetto agli ultimi N layout.
const NOVELTY_HISTORY_LIMIT: int = 50



# ----------------------------------------------------------------------------
# STORICO NOVELTY
# ----------------------------------------------------------------------------

static var _history: Array[Array] = []


# ----------------------------------------------------------------------------
# ENTRY POINT
# ----------------------------------------------------------------------------

static func score(mask: RoomLayoutMask) -> float:
	
	# ----------------------------
	# Componenti strutturali
	# ----------------------------
	
	var density_score: float = _density_balance(mask)
	var height_score: float = _height_distribution(mask)
	var asymmetry_score: float = 1.0 - _symmetry(mask)
	var irregularity_score: float = 1.0 - _horizontal_monotony(mask)
	
	var structural_score: float = (
		density_score * W_DENSITY +
		height_score * W_HEIGHT +
		asymmetry_score * W_ASYMMETRY +
		irregularity_score * W_IRREGULARITY
	) / (W_DENSITY + W_HEIGHT + W_ASYMMETRY + W_IRREGULARITY)
	
	
	# ----------------------------
	# Novità
	# ----------------------------
	
	var novelty_score: float = _novelty([
		density_score,
		height_score,
		asymmetry_score,
		irregularity_score
	])
	
	
	# ----------------------------
	# Score finale
	# ----------------------------
	
	var final_score: float = (
		structural_score * WEIGHT_STRUCTURE +
		novelty_score * WEIGHT_NOVELTY
	)
	
	return clamp(final_score, 0.0, 1.0)


# ----------------------------------------------------------------------------
# METRICHE STRUTTURALI
# ----------------------------------------------------------------------------

## Valuta se la densità dei solidi è bilanciata rispetto a un valore ideale.
static func _density_balance(mask: RoomLayoutMask) -> float:
	
	var total: int = mask.size.x * mask.size.y
	if total <= 0:
		return 0.0
	
	var solid: float = 0.0
	
	for y in range(mask.size.y):
		for x in range(mask.size.x):
			if mask.is_solid(x, y):
				solid += 1.0
	
	var ratio: float = solid / float(total)
	var deviation: float = abs(ratio - IDEAL_SOLID_RATIO)
	
	return clamp(1.0 - deviation * DENSITY_TOLERANCE_FACTOR, 0.0, 1.0)


## Misura l'estensione verticale effettivamente utilizzata.
static func _height_distribution(mask: RoomLayoutMask) -> float:
	
	var min_y: float = INF
	var max_y: float = -INF
	
	for y in range(mask.size.y):
		for x in range(mask.size.x):
			if mask.is_empty(x, y):
				min_y = min(min_y, y)
				max_y = max(max_y, y)
	
	if min_y == INF:
		return 0.0
	
	var span: float = max_y - min_y
	
	return clamp(span / float(mask.size.y), 0.0, 1.0)


## Calcola il grado di simmetria orizzontale.
static func _symmetry(mask: RoomLayoutMask) -> float:
	
	var mid_x: int = mask.size.x / 2
	if mid_x <= 0:
		return 0.0
	
	var mismatches: float = 0.0
	var checks: float = 0.0
	
	for y in range(mask.size.y):
		for x in range(mid_x):
			var a: bool = mask.is_solid(x, y)
			var b: bool = mask.is_solid(mask.size.x - 1 - x, y)
			
			checks += 1.0
			if a != b:
				mismatches += 1.0
	
	if checks <= 0.0:
		return 0.0
	
	return mismatches / checks


## Penalizza segmenti solidi troppo lunghi e piatti.
static func _horizontal_monotony(mask: RoomLayoutMask) -> float:
	
	var total_penalty: float = 0.0
	var max_width: int = mask.size.x
	
	if max_width <= 0:
		return 0.0
	
	for y in range(mask.size.y):
		var run_length: int = 0
		
		for x in range(mask.size.x):
			if mask.is_solid(x, y):
				run_length += 1
			else:
				total_penalty += _run_penalty(run_length, max_width)
				run_length = 0
		
		total_penalty += _run_penalty(run_length, max_width)
	
	return clamp(total_penalty / float(mask.size.y), 0.0, 1.0)


static func _run_penalty(run: int, max_width: int) -> float:
	
	if run <= 0:
		return 0.0
	
	var ratio: float = run / float(max_width)
	
	if ratio < HORIZONTAL_RUN_THRESHOLD_RATIO:
		return 0.0
	
	return ratio * ratio


# ----------------------------------------------------------------------------
# NOVELTY
# ----------------------------------------------------------------------------

## Calcola la distanza normalizzata rispetto ai layout precedenti.
static func _novelty(signature: Array) -> float:
	
	if _history.is_empty():
		_store_signature(signature)
		return 1.0
	
	var min_distance: float = INF
	
	for previous in _history:
		var dist: float = _distance(signature, previous)
		min_distance = min(min_distance, dist)
	
	_store_signature(signature)
	
	return clamp(min_distance, 0.0, 1.0)


static func _distance(a: Array, b: Array) -> float:
	
	var sum: float = 0.0
	
	for i in range(a.size()):
		var diff: float = a[i] - b[i]
		sum += diff * diff
	
	var max_distance: float = sqrt(float(a.size()))
	
	return sqrt(sum) / max_distance


static func _store_signature(signature: Array) -> void:
	
	_history.append(signature)
	
	if _history.size() > NOVELTY_HISTORY_LIMIT:
		_history.pop_front()

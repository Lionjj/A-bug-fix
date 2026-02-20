# ============================================================================
# LayoutScorer
# ============================================================================
## Responsabile del calcolo della qualità morfologica di una RoomLayoutMask.
##
## CARATTERISTICHE:
## - Restituisce un punteggio normalizzato in [0,1].
## - Non valuta la giocabilità (gestita da TraversalAnalyzer).
## - Misura esclusivamente proprietà strutturali ed estetiche.
##
## OBIETTIVO EVOLUTIVO:
## - Evitare layout triviali o eccessivamente semplici.
## - Favorire verticalità, superfici interne e varietà strutturale.
## - Introdurre componente di novità per evitare convergenza precoce.
# ============================================================================

class_name LayoutScorer
extends RefCounted


# ----------------------------------------------------------------------------
# PESI GLOBALI
# ----------------------------------------------------------------------------

## Peso della componente strutturale sul punteggio finale.
## Valore in [0,1].
const WEIGHT_STRUCTURE: float = 0.75

## Peso della componente di novità sul punteggio finale.
## WEIGHT_STRUCTURE + WEIGHT_NOVELTY dovrebbe essere = 1.
const WEIGHT_NOVELTY: float = 0.25


# ----------------------------------------------------------------------------
# PESI METRICHE STRUTTURALI
# ----------------------------------------------------------------------------

## Peso dell'equilibrio tra pieno e vuoto.
const W_DENSITY: float = 1.0

## Peso dell'utilizzo verticale dello spazio.
const W_HEIGHT: float = 1.0

## Peso dell’asimmetria orizzontale.
const W_ASYMMETRY: float = 1.0

## Peso della penalizzazione per monotonia orizzontale.
const W_IRREGULARITY: float = 1.0

## Peso della presenza di superfici calpestabili interne.
const W_PLATFORM: float = 1.0

## Peso della distribuzione verticale multi-livello.
const W_STRATIFICATION: float = 1.0


# ----------------------------------------------------------------------------
# PARAMETRI MORFOLOGICI
# ----------------------------------------------------------------------------

## Rapporto ideale tra celle solide e celle totali.
## Determina la densità desiderata della stanza.
const IDEAL_SOLID_RATIO: float = 0.30

## Intensità della penalizzazione per deviazione dalla densità ideale.
const DENSITY_TOLERANCE_FACTOR: float = 3.0

## Percentuale di larghezza oltre la quale un segmento solido
## è considerato eccessivamente monotono.
const HORIZONTAL_RUN_THRESHOLD_RATIO: float = 0.4


# ----------------------------------------------------------------------------
# PARAMETRI SUPERFICI INTERNE
# ----------------------------------------------------------------------------

## Fattore di scala per normalizzare il punteggio
## delle superfici interne calpestabili.
const PLATFORM_SURFACE_SCALE: float = 4.0


# ----------------------------------------------------------------------------
# PARAMETRI STRATIFICAZIONE
# ----------------------------------------------------------------------------

## Fattore di scala per enfatizzare layout multi-livello.
const STRATIFICATION_SCALE: float = 1.0


# ----------------------------------------------------------------------------
# PARAMETRI NOVELTY
# ----------------------------------------------------------------------------

## Numero massimo di firme morfologiche memorizzate.
const NOVELTY_HISTORY_LIMIT: int = 50

static var _history: Array[Array] = []


# ----------------------------------------------------------------------------
# ENTRY POINT
# ----------------------------------------------------------------------------

## Calcola il punteggio finale del layout.
##
## [param mask]: RoomLayoutMask da valutare.
##
## return: float in [0,1]
static func score(mask: RoomLayoutMask) -> float:
	
	# Metriche classiche
	var density_score := _density_balance(mask)
	var height_score := _height_distribution(mask)
	var asymmetry_score := 1.0 - _symmetry(mask)
	var irregularity_score := 1.0 - _horizontal_monotony(mask)
	
	# Metriche evolutive aggiuntive
	var platform_score := _internal_platform_score(mask)
	var stratification_score := _vertical_stratification(mask)
	
	var total_weights := (
		W_DENSITY + W_HEIGHT + W_ASYMMETRY +
		W_IRREGULARITY + W_PLATFORM + W_STRATIFICATION
	)
	
	var structural_score := (
		density_score * W_DENSITY +
		height_score * W_HEIGHT +
		asymmetry_score * W_ASYMMETRY +
		irregularity_score * W_IRREGULARITY +
		platform_score * W_PLATFORM +
		stratification_score * W_STRATIFICATION
	) / total_weights
	
	var novelty_score := _novelty([
		density_score,
		height_score,
		asymmetry_score,
		irregularity_score,
		platform_score,
		stratification_score
	])
	
	var final_score := (
		structural_score * WEIGHT_STRUCTURE +
		novelty_score * WEIGHT_NOVELTY
	)
	
	return clamp(final_score, 0.0, 1.0)


# ----------------------------------------------------------------------------
# METRICHE STRUTTURALI
# ----------------------------------------------------------------------------

## Valuta quanto la densità dei solidi si avvicina al valore ideale.
##
## [param mask]: layout da analizzare.
##
## return: punteggio normalizzato.
static func _density_balance(mask: RoomLayoutMask) -> float:
	
	var total := mask.size.x * mask.size.y
	if total <= 0:
		return 0.0
	
	var solid := 0.0
	
	for y in range(mask.size.y):
		for x in range(mask.size.x):
			if mask.is_solid(x, y):
				solid += 1.0
	
	var ratio: float = solid / float(total)
	var deviation: float = abs(ratio - IDEAL_SOLID_RATIO)
	
	return clamp(1.0 - deviation * DENSITY_TOLERANCE_FACTOR, 0.0, 1.0)


## Misura quanto lo spazio verticale viene effettivamente utilizzato.
##
## [param mask]: layout da analizzare.
##
## return: proporzione verticale occupata.
static func _height_distribution(mask: RoomLayoutMask) -> float:
	
	var min_y := INF
	var max_y := -INF
	
	for y in range(mask.size.y):
		for x in range(mask.size.x):
			if mask.is_empty(x, y):
				min_y = min(min_y, y)
				max_y = max(max_y, y)
	
	if min_y == INF:
		return 0.0
	
	var span := max_y - min_y
	return clamp(span / float(mask.size.y), 0.0, 1.0)


## Calcola il grado di simmetria orizzontale.
##
## [param mask]: layout da analizzare.
##
## return: valore in [0,1], dove 0 è perfettamente simmetrico.
static func _symmetry(mask: RoomLayoutMask) -> float:
	
	var mid_x := mask.size.x / 2
	if mid_x <= 0:
		return 0.0
	
	var mismatches := 0.0
	var checks := 0.0
	
	for y in range(mask.size.y):
		for x in range(mid_x):
			var a := mask.is_solid(x, y)
			var b := mask.is_solid(mask.size.x - 1 - x, y)
			
			checks += 1.0
			if a != b:
				mismatches += 1.0
	
	if checks <= 0.0:
		return 0.0
	
	return mismatches / checks


## Penalizza segmenti solidi orizzontali troppo lunghi.
##
## [param mask]: layout da analizzare.
##
## return: valore di monotonia normalizzato.
static func _horizontal_monotony(mask: RoomLayoutMask) -> float:
	
	var total_penalty := 0.0
	var max_width := mask.size.x
	
	for y in range(mask.size.y):
		var run_length := 0
		
		for x in range(mask.size.x):
			if mask.is_solid(x, y):
				run_length += 1
			else:
				total_penalty += _run_penalty(run_length, max_width)
				run_length = 0
		
		total_penalty += _run_penalty(run_length, max_width)
	
	return clamp(total_penalty / float(mask.size.y), 0.0, 1.0)


## Calcola la penalità per un singolo segmento solido.
##
## [param run]: lunghezza segmento
## [param max_width]: larghezza totale stanza
##
## return: penalità normalizzata.
static func _run_penalty(run: int, max_width: int) -> float:
	
	if run <= 0:
		return 0.0
	
	var ratio := run / float(max_width)
	
	if ratio < HORIZONTAL_RUN_THRESHOLD_RATIO:
		return 0.0
	
	return ratio * ratio


# ----------------------------------------------------------------------------
# NUOVE METRICHE EVOLUTIVE
# ----------------------------------------------------------------------------

## Premia superfici interne calpestabili (solido con vuoto sopra).
##
## [param mask]: layout da analizzare.
##
## return: punteggio normalizzato.
static func _internal_platform_score(mask: RoomLayoutMask) -> float:
	
	var count := 0.0
	var total := mask.size.x * mask.size.y
	
	if total <= 0:
		return 0.0
	
	for y in range(1, mask.size.y):
		for x in range(mask.size.x):
			if mask.is_solid(x, y) and mask.is_empty(x, y - 1):
				count += 1.0
	
	var normalized := count / float(total)
	return clamp(normalized * PLATFORM_SURFACE_SCALE, 0.0, 1.0)


## Premia layout con più livelli verticali distinti.
##
## [param mask]: layout da analizzare.
##
## return: punteggio normalizzato.
static func _vertical_stratification(mask: RoomLayoutMask) -> float:
	
	var levels := {}
	
	for y in range(mask.size.y):
		for x in range(mask.size.x):
			if mask.is_solid(x, y):
				levels[y] = true
				break
	
	var normalized := float(levels.size()) / mask.size.y
	return clamp(normalized * STRATIFICATION_SCALE, 0.0, 1.0)


# ----------------------------------------------------------------------------
# NOVELTY
# ----------------------------------------------------------------------------

## Calcola distanza minima rispetto ai layout precedenti.
##
## [param signature]: vettore firme morfologiche.
##
## return: distanza normalizzata.
static func _novelty(signature: Array) -> float:
	
	if _history.is_empty():
		_store_signature(signature)
		return 1.0
	
	var min_distance := INF
	
	for previous in _history:
		var dist := _distance(signature, previous)
		min_distance = min(min_distance, dist)
	
	_store_signature(signature)
	return clamp(min_distance, 0.0, 1.0)


## Distanza euclidea normalizzata tra due firme.
##
## [param a]: firma corrente
## [param b]: firma precedente
##
## return: distanza in [0,1]
static func _distance(a: Array, b: Array) -> float:
	
	var sum := 0.0
	
	for i in range(a.size()):
		var diff: float = a[i] - b[i]
		sum += diff * diff
	
	var max_distance := sqrt(float(a.size()))
	return sqrt(sum) / max_distance


## Memorizza firma nello storico.
##
## [param signature]: firma morfologica da salvare.
static func _store_signature(signature: Array) -> void:
	
	_history.append(signature)
	
	if _history.size() > NOVELTY_HISTORY_LIMIT:
		_history.pop_front()

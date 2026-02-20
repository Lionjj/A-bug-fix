# ============================================================================
# OperatorPicker
# ============================================================================
## Questa classe si occupa della selezione casuale pesata degli operatori
## secondari all'interno del sistema di generazione procedurale.
##
## RESPONSABILITÀ:
## - Selezionare un operatore secondario tra quelli registrati.
## - Applicare una selezione pesata in base all'importanza relativa
##   definita da ciascun operatore.
##
## NON SI OCCUPA DI:
## - Istanziamento dell'operatore.
## - Applicazione dell'operatore.
## - Gestione del contesto.
##
## FILOSOFIA:
## - Gli operatori strutturali (CONNECTOR, BACKBONE) NON vengono scelti qui.
## - Questa classe gestisce solo operatori decorativi/secondari.
## - Il peso è definito come costante statica nella classe operatore.
# ============================================================================

class_name OperatorPicker
extends RefCounted


# ----------------------------------------------------------------------------
# ATTRIBUTI
# ----------------------------------------------------------------------------

## Registro centrale che contiene la mappatura tra tipo operatore e classe.
var registry: OperatorRegistry

## Generatore random condiviso dal sistema evolutivo.
var rng: RandomNumberGenerator


# ----------------------------------------------------------------------------
# COSTRUZIONE
# ----------------------------------------------------------------------------

func _init(
	_operator_registry: OperatorRegistry,
	_rng: RandomNumberGenerator
) -> void:
	registry = _operator_registry
	rng = _rng


# ----------------------------------------------------------------------------
# API PUBBLICA
# ----------------------------------------------------------------------------

## Seleziona un operatore secondario tramite estrazione pesata.
##
## Ritorna:
## - LayoutOperator.Type se disponibile.
## - -1 se non esistono operatori secondari registrati.
##
## Il peso di ciascun operatore è definito come:
##     const WEIGHT: float
## all'interno della classe operatore.
static func _invalid_type() -> int:
	return -1


func pick_secondary() -> int:
	
	# Recupera la lista dei tipi secondari dal registry
	var bucket: Array[LayoutOperator.Type] = registry.get_secondary_types()
	
	if bucket.is_empty():
		return _invalid_type()
	
	return _weighted_pick(bucket)


# ----------------------------------------------------------------------------
# SELEZIONE PESATA
# ----------------------------------------------------------------------------

## Implementa una selezione casuale pesata.
##
## Procedura:
## 1. Somma tutti i pesi.
## 2. Estrae un numero casuale nell'intervallo [0, total_weight].
## 3. Scorre cumulativamente i pesi fino a superare la soglia.
##
## Complessità:
## O(n), con n numero di operatori secondari.
##
## Non utilizza strutture aggiuntive per mantenere semplicità e leggibilità.
func _weighted_pick(
	bucket: Array[LayoutOperator.Type]
) -> LayoutOperator.Type:
	
	var total_weight: float = 0.0
	
	# ------------------------------------------------------------
	# Calcolo del peso totale
	# ------------------------------------------------------------
	for type in bucket:
		var op_class: GDScript = registry.get_operator_class(type)
		total_weight += op_class.get_weight()
	
	# Se per qualsiasi motivo i pesi fossero nulli
	if total_weight <= 0.0:
		return bucket[0]
	
	# ------------------------------------------------------------
	# Estrazione random nel range cumulativo
	# ------------------------------------------------------------
	var threshold: float = rng.randf() * total_weight
	var accumulator: float = 0.0
	
	for type in bucket:
		var op_class: GDScript = registry.get_operator_class(type)
		accumulator += op_class.get_weight()
		
		if threshold <= accumulator:
			return type
	
	# Fallback di sicurezza (teoricamente non dovrebbe mai attivarsi)
	return bucket[0]

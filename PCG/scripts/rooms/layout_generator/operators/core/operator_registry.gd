# ============================================================================
# OperatorRegistry
# ============================================================================
## Registro centrale degli operatori disponibili nel sistema.
##
## RESPONSABILITÀ:
## - Mappare LayoutOperator.Type → classe operatore.
## - Fornire istanziazione dinamica.
## - Fornire accesso agli operatori secondari per selezione pesata.
##
## NON SI OCCUPA DI:
## - Applicare operatori
## - Decidere quanti operatori usare
## - Logica evolutiva
# ============================================================================

class_name OperatorRegistry
extends RefCounted


# ----------------------------------------------------------------------------
# ATTRIBUTI
# ----------------------------------------------------------------------------

## Mappa tra tipo operatore e classe GDScript
var operator_classes: Dictionary[LayoutOperator.Type, GDScript] = {}

## Lista dei soli operatori secondari
var secondary_types: Array[LayoutOperator.Type] = []


# ----------------------------------------------------------------------------
# COSTRUZIONE
# ----------------------------------------------------------------------------

func _init() -> void:
	
	# ------------------------------------------------------------
	# Operatori strutturali (sempre presenti nel genome)
	# ------------------------------------------------------------
	register(LayoutOperator.Type.CONNECTOR, ConnectorOperator)
	register(LayoutOperator.Type.BACKBONE, BackboneOperator)
	
	# ------------------------------------------------------------
	# Operatori secondari (selezionabili random)
	# ------------------------------------------------------------
	register(LayoutOperator.Type.PLATFORM, PlatformOperator)
	register(LayoutOperator.Type.PILLAR, PillarOperator)
	
	secondary_types = [
		LayoutOperator.Type.PLATFORM,
		LayoutOperator.Type.PILLAR
	]


# ----------------------------------------------------------------------------
# REGISTRAZIONE
# ----------------------------------------------------------------------------

## Registra un tipo operatore associato alla sua classe.
func register(
	type: LayoutOperator.Type,
	op_class: GDScript
) -> void:
	operator_classes[type] = op_class


# ----------------------------------------------------------------------------
# ACCESSO
# ----------------------------------------------------------------------------

## Ritorna la classe GDScript associata al tipo.
## Serve per leggere costanti statiche (es. WEIGHT).
func get_operator_class(
	type: LayoutOperator.Type
) -> GDScript:
	return operator_classes.get(type, null)


## Istanzia un operatore dato il tipo, contesto e parametri.
func instantiate(
	type: LayoutOperator.Type,
	context: OperatorContext,
	params: Dictionary
) -> LayoutOperator:
	
	var op_class: GDScript = get_operator_class(type)
	
	if op_class == null:
		return null
	
	return op_class.new(context, params)


## Ritorna la lista dei tipi secondari disponibili.
func get_secondary_types() -> Array[LayoutOperator.Type]:
	return secondary_types

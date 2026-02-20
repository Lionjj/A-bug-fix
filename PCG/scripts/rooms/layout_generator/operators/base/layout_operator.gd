# ============================================================================
# LayoutOperator
# ============================================================================
## Classe base per tutti gli operatori di shape grammar.
##
## RESPONSABILITÀ:
## - Definire l'interfaccia comune degli operatori.
## - Fornire metodi per:
##     • Generazione parametri (fase genetica)
##     • Mutazione parametri (fase genetica)
##     • Applicazione su mask (fase costruttiva)
##
## FILOSOFIA ARCHITETTURALE:
## - La fase genetica NON usa la mask.
## - La fase applicativa USA la mask.
## - Il peso è una proprietà del tipo operatore (static).
##
## Ogni operatore concreto deve:
## - Override get_weight()
## - Implementare create_random_params()
## - Implementare mutate_params()
## - Implementare apply()
# ============================================================================

class_name LayoutOperator
extends RefCounted


# ----------------------------------------------------------------------------
# ENUMERATORI
# ----------------------------------------------------------------------------

## Tipologie di operatori disponibili nel sistema.
enum Type {
	DEFAULT,
	BACKBONE,
	CONNECTOR,
	PILLAR,
	PLATFORM
}


# ----------------------------------------------------------------------------
# METADATI OPERATORE
# ----------------------------------------------------------------------------

## Tipo dell'operatore (assegnato nei figli).
var type: Type = Type.DEFAULT


# ----------------------------------------------------------------------------
# PESO STATICO
# ----------------------------------------------------------------------------

## Peso statico utilizzato durante la selezione pesata.
##
## NOTA:
## - È statico perché rappresenta una proprietà del TIPO,
##   non della singola istanza.
## - Deve essere ridefinito negli operatori concreti.
static func get_weight() -> float:
	return 1.0


# ----------------------------------------------------------------------------
# STATO DI ISTANZA
# ----------------------------------------------------------------------------

## Contesto operativo.
## Contiene:
## - size
## - wall_thickness
## - size_profile
## - rng
## - mask (solo in fase apply)
var context: OperatorContext

## Parametri genetici dell'operatore.
var params: Dictionary


# ----------------------------------------------------------------------------
# COSTRUTTORE
# ----------------------------------------------------------------------------

func _init(
	_context: OperatorContext,
	_params: Dictionary = {}
) -> void:
	context = _context
	params = _params


# ----------------------------------------------------------------------------
# INTERFACCIA GENETICA
# ----------------------------------------------------------------------------

## Genera parametri casuali.
## Deve usare SOLO:
## - context.size
## - context.size_profile
## - context.rng
##
## NON deve usare context.mask.
func create_random_params() -> Dictionary:
	push_error("LayoutOperator.create_random_params() not implemented")
	return {}


## Mutazione dei parametri genetici.
## NON deve usare context.mask.
func mutate_params() -> void:
	push_error("LayoutOperator.mutate_params() not implemented")


# ----------------------------------------------------------------------------
# INTERFACCIA APPLICATIVA
# ----------------------------------------------------------------------------

## Applica la trasformazione sulla mask.
##
## Questa è l'unica fase in cui è consentito usare:
## - context.mask
##
## Deve essere:
## - fallibile
## - rollback-safe
func apply() -> bool:
	push_error("LayoutOperator.apply() not implemented")
	return false


# ----------------------------------------------------------------------------
# UTILITIES TRANSAZIONALI
# ----------------------------------------------------------------------------

## Carve rettangolare con tracciamento modifiche.
## Utilizzato dagli operatori concreti.
##
## Ritorna le celle modificate per eventuale rollback.
func _carve_rect_transaction(
	rect: Rect2i
) -> Array[Vector2i]:

	var changed: Array[Vector2i] = []

	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if context.mask.is_solid(x, y):
				context.mask.set_empty(x, y)
				changed.append(Vector2i(x, y))

	return changed


## Ripristina le celle precedentemente modificate.
func _rollback(cells: Array[Vector2i]) -> void:
	for c in cells:
		context.mask.set_solid(c.x, c.y)

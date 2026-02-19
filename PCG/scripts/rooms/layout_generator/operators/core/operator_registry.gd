class_name OperatorRegistry
extends RefCounted

var operator_classes: Dictionary[LayoutOperator.Type, GDScript] = {}
var primary: Array[LayoutOperator.Type] = []
var secondary: Array[LayoutOperator.Type] = []

var context: OperatorContext = null

func _init():
	## Operatori primari
	register(LayoutOperator.Type.CONNECTOR, LayoutOperator.Role.PRIMARY, ConnectorOperator)
	register(LayoutOperator.Type.BACKBONE, LayoutOperator.Role.PRIMARY, BackboneOperator)
	#register(DividerOperator.new(context))
	#register(RingOperator.new(_context))
	#register(SplitCornerOperator.new(_context))
	#
	### Operatori secondari
	#register(IndentOperator.new(_context))
	register(LayoutOperator.Type.PLATFORM, LayoutOperator.Role.SECONDARY, PlatformOperator)
	register(LayoutOperator.Type.PILLAR, LayoutOperator.Role.SECONDARY, PillarOperator)
	

func register(type: LayoutOperator.Type, role: LayoutOperator.Role, op_class: GDScript) -> void:
	operator_classes[type] = op_class
	register_role(type, role)

func istanziate(type: LayoutOperator.Type, context: OperatorContext, params: Dictionary) -> LayoutOperator:
	var op_class: GDScript = operator_classes.get(type)
	if op_class == null:
		return null
	
	var op: LayoutOperator = op_class.new(context, params)
	return op

func get_random_type(rng: RandomNumberGenerator) -> LayoutOperator.Type:
	var keys: Array = operator_classes.keys()
	if keys.is_empty():
		return -1
	
	return keys[rng.randi() % keys.size()]

func get_operator_class(type: LayoutOperator.Type) -> Script:
	return operator_classes.get(type, null)

func register_role(type: LayoutOperator.Type, role: LayoutOperator.Role):
	match role:
		LayoutOperator.Role.PRIMARY:
			primary.append(type)
		
		LayoutOperator.Role.SECONDARY:
			secondary.append(type)
		_:
			push_warning("Il ruolo dell'operatore: ", type, ", non è definito!")

func get_primary() -> Array[LayoutOperator.Type]:
	return primary

func get_secondary() -> Array[LayoutOperator.Type]:
	return secondary

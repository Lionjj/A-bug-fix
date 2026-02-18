class_name OperatorRegistry
extends RefCounted

var operators: Dictionary[LayoutOperator.Type, LayoutOperator] = {}
var primary: Dictionary[LayoutOperator.Type, LayoutOperator] = {}			
var secondary: Dictionary[LayoutOperator.Type, LayoutOperator] = {}
var context: OperatorContext

func _init(_context: OperatorContext):
	context = _context
	## Operatori primari
	register(DividerOperator.new(context))
	#register(RingOperator.new(_context))
	#register(SplitCornerOperator.new(_context))
	#
	### Operatori secondari
	#register(IndentOperator.new(_context))
	register(PlatformOperator.new(context))
	register(PillarOperator.new(_context))
	

func register(op: LayoutOperator) -> void:
	operators[op.type] = op
	register_role(op)

func get_operator(type: LayoutOperator.Type) -> LayoutOperator:
	return operators.get(type)

func get_random(rng: RandomNumberGenerator):
	var keys: Array[LayoutOperator.Type] = operators.keys()
	return operators[keys[rng.randi() % keys.size()]]

func register_role(op: LayoutOperator):
	match op.role:
		LayoutOperator.Role.PRIMARY:
			primary[op.type] = op
		
		LayoutOperator.Role.SECONDARY:
			secondary[op.type] = op
		_:
			push_warning("Il ruolo dell'operatore: ", op.type, ", non è definito!")

func get_primary() -> Dictionary[LayoutOperator.Type, LayoutOperator]:
	return primary

func get_secondary() -> Dictionary[LayoutOperator.Type, LayoutOperator]:
	return secondary

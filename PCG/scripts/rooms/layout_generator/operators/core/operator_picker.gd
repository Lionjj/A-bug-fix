class_name OperatorPicker
extends RefCounted

var operator_registr: OperatorRegistry
var rng: RandomNumberGenerator

func _init(_operator_registry: OperatorRegistry, _rng: RandomNumberGenerator) -> void:
	operator_registr = _operator_registry
	rng = _rng
	

func pick_operator(role: LayoutOperator.Role) -> int:
	var bucket: Dictionary[LayoutOperator.Type, LayoutOperator] = {}
	
	match role:
		
		LayoutOperator.Role.PRIMARY:
			bucket = operator_registr.primary
			
		LayoutOperator.Role.SECONDARY:
			bucket = operator_registr.secondary
			
		_: 
			push_warning("Il ruolo dell'operatore: ", role, ", non è definito!")
			return -1
	
	if bucket.is_empty(): return -1
	return _weighted_pick(bucket)
	

func _weighted_pick(bucket: Dictionary[LayoutOperator.Type, LayoutOperator]) -> LayoutOperator.Type:
	var total_weight: float = 0.0

	for op in bucket.values():
		total_weight += op.weight

	var r: float = rng.randf() * total_weight
	var acc: float = 0.0

	for type in bucket.keys():
		var op: LayoutOperator = bucket[type]
		acc += op.weight

		if r <= acc:
			return type

	# fallback sicurezza
	return bucket.keys()[0]

extends RefCounted
class_name LayoutValidatorContext

var mask: RoomLayoutMask
var plan: ConnectorPlan

func _init(_mask: RoomLayoutMask, _plan: ConnectorPlan) -> void:
	mask = _mask
	plan = _plan

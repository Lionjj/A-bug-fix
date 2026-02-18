# ============================================================================
# OperatorContext
# ============================================================================

class_name OperatorContext
extends RefCounted

var size_profile: RoomSizeProfile
var rng: RandomNumberGenerator
var connector_plan: ConnectorPlan
var mask: RoomLayoutMask

func _init(
	_size_profile: RoomSizeProfile,
	_rng: RandomNumberGenerator,
	_connector_plan: ConnectorPlan,
	_mask: RoomLayoutMask
) -> void:
	size_profile = _size_profile
	rng = _rng
	connector_plan = _connector_plan
	mask = _mask

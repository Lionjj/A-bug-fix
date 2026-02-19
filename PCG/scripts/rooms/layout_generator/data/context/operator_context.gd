# ============================================================================
# OperatorContext
# ============================================================================

class_name OperatorContext
extends RefCounted

var size_profile: RoomSizeProfile
var rng: RandomNumberGenerator
var mask: RoomLayoutMask

var connector_plan: ConnectorPlan = null

func _init(
	_size_profile: RoomSizeProfile,
	_rng: RandomNumberGenerator,
	_mask: RoomLayoutMask,
	_connector_plan: ConnectorPlan = null,
) -> void:
	size_profile = _size_profile
	rng = _rng
	connector_plan = _connector_plan
	mask = _mask

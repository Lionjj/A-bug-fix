# ============================================================================
# OperatorContext
# ============================================================================

class_name OperatorContext
extends RefCounted

var size_profile: RoomSizeProfile
var rng: RandomNumberGenerator
var size: Vector2i

var mask: RoomLayoutMask = null
var connector_plan: ConnectorPlan = null

func _init(
	_size_profile: RoomSizeProfile,
	_rng: RandomNumberGenerator,
	_size: Vector2i,
	_mask: RoomLayoutMask = null,
	_connector_plan: ConnectorPlan = null,
) -> void:
	size_profile = _size_profile
	rng = _rng
	size = _size
	connector_plan = _connector_plan
	mask = _mask

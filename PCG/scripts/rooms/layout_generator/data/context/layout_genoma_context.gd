# ============================================================================
# LayoutGenomaContext
# ============================================================================

class_name LayoutGenomaContext
extends RefCounted

var size_profile: RoomSizeProfile
var rng: RandomNumberGenerator
var operator_registry: OperatorRegistry
var traversal_profile: PlayerTraversalProfile

func _init(
	_size_profile: RoomSizeProfile,
	_rng: RandomNumberGenerator,
	_operator_registry: OperatorRegistry,
	_traversal_profile: PlayerTraversalProfile
) -> void:
	size_profile = _size_profile
	rng = _rng
	operator_registry = _operator_registry
	traversal_profile = _traversal_profile

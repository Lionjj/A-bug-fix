# ============================================================================
# LayoutContext
# ============================================================================

class_name LayoutContext
extends RefCounted

var size_profile: RoomSizeProfile
var rng: RandomNumberGenerator
var operator_registry: OperatorRegistry
var size: Vector2i

func _init(
	_size_profile: RoomSizeProfile,
	_rng: RandomNumberGenerator,
	_operator_registry: OperatorRegistry
) -> void:
	size_profile = _size_profile
	rng = _rng
	operator_registry = _operator_registry
	size = RoomSizePicker.new(size_profile, rng).pick()

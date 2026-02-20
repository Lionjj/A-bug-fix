# ============================================================================
# LayoutContext
# ============================================================================

class_name LayoutContext
extends RefCounted

var size_profile: RoomSizeProfile
var rng: RandomNumberGenerator
var size: Vector2i

func _init(
	_size_profile: RoomSizeProfile,
	_rng: RandomNumberGenerator,
	_size: Vector2i
) -> void:
	size_profile = _size_profile
	rng = _rng
	size = _size

# ============================================================================
# LayoutContext
# ============================================================================

class_name LayoutContext
extends RefCounted

var size: Vector2i
var size_profile: RoomSizeProfile
var rng: RandomNumberGenerator

func _init(
	_size_profile: RoomSizeProfile,
	_rng: RandomNumberGenerator
) -> void:
	size_profile = _size_profile
	rng = _rng
	size = RoomSizePicker.new(size_profile, rng).pick()

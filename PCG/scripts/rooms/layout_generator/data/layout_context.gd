# ============================================================================
# LayoutContext
# ============================================================================

class_name LayoutContext
extends RefCounted

var size: Vector2i
var size_profile: RoomSizeProfile
var rng: RandomNumberGenerator

# metadati topologici
var has_divider: bool = false
var has_ring: bool = false

# ============================================================================
# RoomSizePicker
# ============================================================================
## Seleziona una dimensione valida per una stanza.
# ============================================================================

class_name RoomSizePicker
extends RefCounted

var profile: RoomSizeProfile
var rng: RandomNumberGenerator

func _init(_profile: RoomSizeProfile, _rng: RandomNumberGenerator) -> void:
	profile = _profile
	rng = _rng


## Restituisce una size valida (Vector2i).
func pick() -> Vector2i:
	var widths: Array[int] = _build_range(profile.min_size.x, profile.max_size.x, profile.step.x)
	var heights: Array[int] = _build_range(profile.min_size.y, profile.max_size.y, profile.step.y)
	
	
	var w: int = widths[rng.randi() % widths.size()]
	var h: int = heights[rng.randi() % heights.size()]

	return Vector2i(w, h)


func _build_range(min_v: int, max_v: int, step: int) -> Array[int]:
	var out: Array[int] = []
	var v: int = min_v

	while v <= max_v:
		out.append(v)
		v += step

	return out

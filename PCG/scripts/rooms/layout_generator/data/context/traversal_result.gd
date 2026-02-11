extends RefCounted
class_name TraversalResult

var reachable: Dictionary[Vector2i, bool]
var returnable: Dictionary[Vector2i, bool]

func _init(
	_reachable: Dictionary[Vector2i, bool],
	_returnable: Dictionary[Vector2i, bool]
) -> void:
	reachable = _reachable
	returnable = _returnable
	

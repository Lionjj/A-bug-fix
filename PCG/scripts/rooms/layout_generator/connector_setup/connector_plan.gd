class_name ConnectorPlan
extends Resource

# bitmask connettori attivi
@export var mask: int = 0

# 4 slot (N,E,S,W) indicizzati da Dir4.idx()
@export var coord: PackedInt32Array = PackedInt32Array([0,0,0,0])
@export var width: PackedInt32Array = PackedInt32Array([4,4,4,4]) # default min=4


func enable(d: int) -> void:
	mask = Dir4.add(mask, d)

func disable(d: int) -> void:
	mask = Dir4.remove(mask, d)

func is_enabled(d: int) -> bool:
	return Dir4.has(mask, d)

func set_opening(d: int, c: int, w: int) -> void:
	enable(d)
	var i: int = Dir4.idx(d)
	coord[i] = c
	width[i] = max(4, w)

func get_coord(d: int) -> int:
	return coord[Dir4.idx(d)]

func get_width(d: int) -> int:
	return width[Dir4.idx(d)]

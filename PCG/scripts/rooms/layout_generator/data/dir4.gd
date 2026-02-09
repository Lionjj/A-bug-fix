class_name Dir4
extends RefCounted

enum D {
	N = 1 << 0,
	E = 1 << 1,
	S = 1 << 2,
	W = 1 << 3,
}

const ORDER: PackedInt32Array = [D.N, D.E, D.S, D.W]

static func has(mask: int, d: int) -> bool:
	return (mask & d) != 0

static func add(mask: int, d: int) -> int:
	return mask | d

static func remove(mask: int, d: int) -> int:
	return mask & ~d

static func idx(d: int) -> int:
	match d:
		D.N: return 0
		D.E: return 1
		D.S: return 2
		D.W: return 3
	return 0

static func axis_step(d: int) -> Vector2i:
	match d:
		D.N: return Vector2i.UP
		D.E: return Vector2i.RIGHT
		D.S: return Vector2i.DOWN
		D.W: return Vector2i.LEFT
	return Vector2i.ZERO

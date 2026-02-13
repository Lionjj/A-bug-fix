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

static func get_random_side(rng: RandomNumberGenerator, exept: int = -1) -> int:
	var candidates: Array[int] = []
	
	for d in Dir4.ORDER:
		if d == exept: continue
		candidates.append(d)
		
	var idx: int = rng.randi() % candidates.size()
	return candidates[idx]
	
static func get_random_side_not_in_mask(rng, mask: int) -> int:
	var candidates: Array[int] = []
	for d in ORDER:
		if not has(mask, d):
			candidates.append(d)
	return candidates[rng.randi() % candidates.size()]

static func get_random_side_in_mask(rng, mask: int) -> int:
	var candidates: Array[int] = []
	for d in ORDER:
		if has(mask, d):
			candidates.append(d)
	return candidates[rng.randi() % candidates.size()]

static func bit_count(mask: int) -> int:
	var c := 0
	for d in ORDER:
		if has(mask, d):
			c += 1
	return c
	
static func get_random_mask(
	rng: RandomNumberGenerator,
	count: int
) -> int:

	if count <= 0:
		return 0
	
	var dirs: Array[int] = []
	for d in ORDER:
		dirs.append(d)
		
	dirs.shuffle()

	var mask: int = 0
	var limit: int = min(count, dirs.size())

	for i in range(limit):
		mask = add(mask, dirs[i])

	return mask

extends Node
var rng :RandomNumberGenerator= RandomNumberGenerator.new()
func set_seed(s:int) -> void: rng.seed = s
func get_rng() -> RandomNumberGenerator: return rng
func randi() -> int: return rng.randi()
func randf() -> float: return rng.randf()
func randi_range(from: int, to: int) -> int: return rng.randi_range(from, to)
func choice(arr:Array): return arr[int(rng.randf() * arr.size())]

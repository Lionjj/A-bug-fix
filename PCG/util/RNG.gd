extends Node
var rng := RandomNumberGenerator.new()
func set_seed(s:int) -> void: rng.seed = s
func randi() -> int: return rng.randi()
func randf() -> float: return rng.randf()
func choice(arr:Array): return arr[int(rng.randf() * arr.size())]

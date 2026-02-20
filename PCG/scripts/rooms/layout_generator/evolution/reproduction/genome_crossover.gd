# ============================================================================
# GenomeCrossover
# ============================================================================
class_name GenomeCrossover
extends RefCounted

var rng: RandomNumberGenerator

func _init(_rng: RandomNumberGenerator) -> void:
	rng = _rng

func crossover(a: Genome, b: Genome) -> Genome:
	push_error("crossover non implementato")
	return a

# ============================================================================
# FitnessEvaluator
# ============================================================================
## Classe astratta rappresentate la fitness
# ============================================================================

class_name FitnessEvaluator
extends RefCounted

func evaluate(genome: Genome) -> float:
	push_error("evaluate non implementato")
	return 0.0

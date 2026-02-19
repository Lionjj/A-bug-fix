# ============================================================================
# GenomeFactory
# ============================================================================
## Classe astratta rappresentate la GenomeFactory
# ============================================================================

extends RefCounted
class_name GenomeFactory

var rng: RandomNumberGenerator

func _init(_rng: RandomNumberGenerator) -> void:
	rng = _rng

## Funzione che deve essere impementata nelle classi figlie
func random_genome() -> Genome:
	push_error("random_genome non implementato")
	return null

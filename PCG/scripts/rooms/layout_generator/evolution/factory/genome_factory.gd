# ============================================================================
# GenomeFactory
# ============================================================================
## Classe astratta rappresentate la GenomeFactory
# ============================================================================

extends RefCounted
class_name GenomeFactory

## Funzione che deve essere impementata nelle classi figlie
func random_genome(rng: RandomNumberGenerator) -> Genome:
	push_error("random_genome non implementato")
	return null

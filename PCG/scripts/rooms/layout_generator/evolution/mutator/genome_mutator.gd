# ============================================================================
# GenomeMutator
# ============================================================================
## Classe atratta rappresentante un Mutatore
# ============================================================================

class_name GenomeMutator
extends RefCounted

## Funzione che deve essere impementata nelle classi figlie
func mutate(genome: Genome) -> Genome:
	push_error("mutate non implementato")
	return genome

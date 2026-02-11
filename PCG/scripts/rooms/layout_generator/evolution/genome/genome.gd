# ============================================================================
# Genome
# ============================================================================
## Classe astratta rappresentate un Genoma
# ============================================================================

class_name Genome
extends RefCounted

## Funzione che deve essere impementata nelle classi figlie
func clone() -> Genome:
	push_error("clone() non implementato")
	return null

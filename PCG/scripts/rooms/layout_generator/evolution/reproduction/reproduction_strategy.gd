class_name ReproductionStrategy
extends RefCounted

func reproduce(
	survivors: Array[Genome],
	factory: GenomeFactory,
	mutator: GenomeMutator,
	rng: RandomNumberGenerator,
	population_size: int,
	mutation_rate: float
) -> Array[Genome]:
	push_error("reproduce() non implementato")
	return []

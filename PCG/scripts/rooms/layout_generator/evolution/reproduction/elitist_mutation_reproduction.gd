class_name ElitistMutationReproduction
extends ReproductionStrategy


func reproduce(
	survivors: Array[Genome],
	factory: GenomeFactory,
	mutator: GenomeMutator,
	rng: RandomNumberGenerator,
	population_size: int,
	mutation_rate: float
) -> Array[Genome]:

	var next: Array[Genome] = []

	# elitismo
	for g in survivors:
		next.append(g.clone())

	# riempi popolazione
	while next.size() < population_size:

		var parent: Genome = survivors[
			rng.randi_range(0, survivors.size() - 1)
		]

		var child: Genome = parent.clone()

		if rng.randf() < mutation_rate:
			child = mutator.mutate(child)

		next.append(child)

	return next

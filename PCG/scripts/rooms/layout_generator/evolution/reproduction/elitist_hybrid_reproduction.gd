# ============================================================================
# ElitistHybridReproduction
# ============================================================================
## Strategia evolutiva con:
## - Elitismo
## - Mutazione
## - Crossover strutturale
# ============================================================================

class_name ElitistHybridReproduction
extends ReproductionStrategy


## Probabilità di usare crossover invece della sola mutazione
const CROSSOVER_RATE: float = 0.5


func reproduce(
	survivors: Array[Genome],
	factory: GenomeFactory,
	mutator: GenomeMutator,
	rng: RandomNumberGenerator,
	population_size: int,
	mutation_rate: float
) -> Array[Genome]:

	var next: Array[Genome] = []

	# -------------------------------------------------
	# 1️⃣ Elitismo: copia diretta dei sopravvissuti
	# -------------------------------------------------
	for g in survivors:
		next.append(g.clone())

	# Crossover operator (solo se Genome supporta)
	var crossover := LayoutGenomeCrossover.new(rng)

	# -------------------------------------------------
	# 2️⃣ Riempimento popolazione
	# -------------------------------------------------
	while next.size() < population_size:

		var parent_a: Genome = survivors[
			rng.randi_range(0, survivors.size() - 1)
		]

		var child: Genome

		# -------------------------------------------------
		# Crossover oppure clone
		# -------------------------------------------------
		if rng.randf() < CROSSOVER_RATE and survivors.size() > 1:

			var parent_b: Genome = survivors[
				rng.randi_range(0, survivors.size() - 1)
			]

			child = crossover.crossover(parent_a, parent_b)

		else:
			child = parent_a.clone()

		# -------------------------------------------------
		# Mutazione eventuale
		# -------------------------------------------------
		if rng.randf() < mutation_rate:
			child = mutator.mutate(child)

		next.append(child)

	return next

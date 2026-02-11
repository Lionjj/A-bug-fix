# ============================================================================
# LayoutEvolutionEngine
# ============================================================================
## Motore evolutivo per la selezione dei layout migliori.
##
## OBIETTIVO:
## - Generare N layout candidati
## - Valutarli tramite LayoutScorer
## - Selezionare i migliori
##
## FILOSOFIA:
## - Selection-based (evolutivo light)
## - Ranking relativo, non assoluto
## - Fail-first: layout non validi scartati subito
##
## NOTE:
## - Stateless
## - Non conosce gli operatori
## - Non modifica direttamente le mask
# ============================================================================

class_name LayoutEvolutionEngine
extends RefCounted


# ---------------------------------------------------------------------------
# Configurazione
# ---------------------------------------------------------------------------

## Numero di layout generati per generazione
const POPULATION_SIZE: int = 32

const GENERATIONS: int = 10

const SURVIVAL_RATE: float = 0.25

const MUTATION_RATE: float = 0.9


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

## Genera e seleziona il miglior layout.
##
## generator: Callable che ritorna una RoomLayoutMask
##
## return: RoomLayoutMask migliore trovata (o null)
static func evolve(context: LayoutContext) -> RoomLayoutMask:
	var rng := context.rng

	# 1) popolazione iniziale
	var population: Array[LayoutGenome] = []
	for i in range(POPULATION_SIZE):
		population.append(
			LayoutGenomeFactory.random_genome(rng, context.size_profile)
		)

	var best_mask: RoomLayoutMask = null
	var best_score := -INF

	# 2) loop evolutivo
	for gen in range(GENERATIONS):
		var evaluated := _evaluate(population, context)

		if evaluated.is_empty():
			# ripartenza soft
			population.clear()
			for i in range(POPULATION_SIZE):
				population.append(
					LayoutGenomeFactory.random_genome(rng, context.size_profile)
				)
			continue

		# aggiorna best globale
		if evaluated[0].score > best_score:
			best_score = evaluated[0].score
			best_mask = evaluated[0].mask

		# 3) selezione
		var survivors := _select(evaluated)

		# 4) riproduzione + mutazione
		population = _reproduce(survivors, rng)

	return best_mask


static func _evaluate(
	population: Array[LayoutGenome],
	context: LayoutContext
) -> Array:
	var scored := []

	for genome in population:
		var mask := RoomLayoutGenerator.generate_from_genome(
			genome, context
		)
		if mask == null:
			continue
		
		var validation: LayoutValidatorContext = LayoutValidator.validate(mask)
		if not validation.is_valid:
			continue

		var score: float = LayoutScorer.score(mask) + validation.score
		if score <= 0.0:
			continue

		scored.append({
			"genome": genome,
			"mask": mask,
			"score": score
		})

	scored.sort_custom(func(a, b):
		return a.score > b.score
	)

	return scored


static func _select(evaluated: Array) -> Array[LayoutGenome]:
	var survivors: Array[LayoutGenome] = []
	var count: int = max(1, int(evaluated.size() * SURVIVAL_RATE))

	for i in range(count):
		survivors.append(evaluated[i].genome)

	return survivors


static func _reproduce(
	survivors: Array[LayoutGenome],
	rng: RandomNumberGenerator
) -> Array[LayoutGenome]:
	var next: Array[LayoutGenome] = []

	# elitismo: copia diretta
	for g in survivors:
		next.append(g.clone())

	# riempi popolazione
	while next.size() < POPULATION_SIZE:
		var parent := survivors[
			rng.randi_range(0, survivors.size() - 1)
		]

		var child := parent.clone()

		if rng.randf() < MUTATION_RATE:
			child = LayoutGenomeMutator.mutate(child, rng)

		next.append(child)

	return next


# ---------------------------------------------------------------------------
# Debug utility
# ---------------------------------------------------------------------------

static func _print_generation_stats(gen: int, evaluated: Array) -> void:
	if evaluated.is_empty():
		print("GEN ", gen, " → nessun layout valido")
		return

	var best = evaluated[0].score
	var worst = evaluated[evaluated.size() - 1].score
	var sum := 0.0

	for e in evaluated:
		print("BEST LAYOUT GEN ", gen)
		print(evaluated[0].mask.to_ascii())

		sum += e.score

	var avg := sum / evaluated.size()

	print(
		"GEN ", gen,
		" | valid: ", evaluated.size(),
		" | best: ", snapped(best, 0.01),
		" | avg: ", snapped(avg, 0.01),
		" | worst: ", snapped(worst, 0.01)
	)

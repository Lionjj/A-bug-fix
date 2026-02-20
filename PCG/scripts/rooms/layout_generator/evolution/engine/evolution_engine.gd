## Motore evolutivo per la selezione dei layout migliori.
##
## OBIETTIVO:
## - Generare N layout candidati
## - Valutarli tramite LayoutScorer
## - Selezionare i migliori

class_name EvolutionEngine
extends RefCounted

var factory: GenomeFactory
var mutator: GenomeMutator
var evaluator: FitnessEvaluator
var selection: SelectionStrategy
var reproduction: ReproductionStrategy
var rng: RandomNumberGenerator

var population_size: int = 32
var generations: int = 10
var survival_rate: float = 0.25
var mutation_rate: float = 0.8

func _init(
	_factory: GenomeFactory,
	_mutator: GenomeMutator,
	_evaluator: FitnessEvaluator,
	_selection: SelectionStrategy,
	_reproduction: ReproductionStrategy,
	_rng: RandomNumberGenerator
):
	factory = _factory
	mutator = _mutator
	evaluator = _evaluator
	selection = _selection
	reproduction = _reproduction
	rng = _rng


func evolve() -> Genome:

	var population: Array[Genome] = []

	for i in range(population_size):
		population.append(factory.random_genome())

	var best_genome: Genome = null
	var best_score: float = -INF

	for gen in range(generations):

		var evaluated: Array[EvaluationResult] = _evaluate(population)

		if evaluated.is_empty():
			population.clear()
			for i in range(population_size):
				population.append(factory.random_genome())
			continue

		if evaluated[0].score > best_score:
			best_score = evaluated[0].score
			best_genome = evaluated[0].genome

		var survivors: Array[Genome] = selection.select(evaluated, survival_rate, rng)
		
		population = reproduction.reproduce(
			survivors, factory, mutator, rng, population_size, mutation_rate
		)

	return best_genome


func _evaluate(population: Array[Genome]) -> Array[EvaluationResult]:
	var t0 := Time.get_ticks_msec()
	var scored: Array[EvaluationResult] = []

	for genome in population:
		var score: float = evaluator.evaluate(genome)

		if score == -INF:
			continue
			
		var result: EvaluationResult = EvaluationResult.new(genome, score)
		
		scored.append(result)

	scored.sort_custom(func(a, b):
		return a.score > b.score
	)
	print("EVALUATE TIME:", Time.get_ticks_msec() - t0, "ms")

	return scored

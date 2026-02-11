class_name TopKSelection
extends SelectionStrategy


func select(
	evaluated: Array,
	survival_rate: float,
	rng: RandomNumberGenerator
) -> Array[Genome]:

	var survivors: Array[Genome] = []
	var count: int = max(1, int(evaluated.size() * survival_rate))

	for i in range(count):
		survivors.append(evaluated[i].genome)

	return survivors

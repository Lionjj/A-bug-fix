# ============================================================================
# LayoutGenomeCrossover
# ============================================================================
## Crossover strutturalmente consapevole per LayoutGenome.
##
## RESPONSABILITÀ:
## - Combinare due genomi validi.
## - Preservare CONNECTOR e BACKBONE.
## - Mescolare operatori secondari.
##
## NON:
## - Non valida il layout.
## - Non applica mutazioni.
# ============================================================================

class_name LayoutGenomeCrossover
extends GenomeCrossover


## Indice da cui iniziano i geni secondari
const FIRST_MUTABLE_INDEX: int = 2


func crossover(a: Genome, b: Genome) -> LayoutGenome:
	
	var ga := a as LayoutGenome
	var gb := b as LayoutGenome

	if ga == null or gb == null:
		push_error("LayoutGenomeCrossover: invalid genome types")
		return a


	var child := LayoutGenome.new()

	# ------------------------------------------------
	# 1) CONNECTOR (obbligatorio)
	# ------------------------------------------------
	child.genes.append(
		_rand_parent_gene(ga, gb, 0)
	)

	# ------------------------------------------------
	# 2) BACKBONE (obbligatorio)
	# ------------------------------------------------
	child.genes.append(
		_rand_parent_gene(ga, gb, 1)
	)

	# ------------------------------------------------
	# 3) SECONDARI
	# ------------------------------------------------
	var sec_a := ga.genes.slice(FIRST_MUTABLE_INDEX)
	var sec_b := gb.genes.slice(FIRST_MUTABLE_INDEX)

	var combined: Array[LayoutGene] = []

	for g in sec_a:
		if rng.randf() < 0.5:
			combined.append(g.clone())

	for g in sec_b:
		if rng.randf() < 0.5:
			combined.append(g.clone())

	for g in combined:
		child.genes.append(g)

	return child


func _rand_parent_gene(
	a: LayoutGenome,
	b: LayoutGenome,
	index: int
) -> LayoutGene:

	if rng.randf() < 0.5:
		return a.genes[index].clone()
	else:
		return b.genes[index].clone()

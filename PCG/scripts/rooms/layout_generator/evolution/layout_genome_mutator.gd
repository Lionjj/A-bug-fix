# ============================================================================
# LayoutGenomeMutator
# ============================================================================
## Applica mutazioni controllate a un LayoutGenome.
# ============================================================================

class_name LayoutGenomeMutator
extends RefCounted


static func mutate(
	genome: LayoutGenome,
	rng: RandomNumberGenerator
) -> LayoutGenome:
	var g := genome.clone()
	if g.genes.is_empty():
		return g

	match rng.randi_range(0, 3):
		0:
			_mutate_param(g, rng)
		1:
			_add_gene(g, rng)
		2:
			_remove_gene(g, rng)
		3:
			_swap_genes(g, rng)

	return g

static func _mutate_param(g: LayoutGenome, rng: RandomNumberGenerator) -> void:
	var gene: LayoutGene = g.genes[rng.randi_range(0, g.genes.size() - 1)]

	if gene.params.is_empty():
		# bootstrap minimo
		gene.params["strength"] = rng.randi_range(1, 4)
	else:
		var keys := gene.params.keys()
		var k = keys[rng.randi_range(0, keys.size() - 1)]
		gene.params[k] += rng.randi_range(-1, 1)


static func _add_gene(g: LayoutGenome, rng: RandomNumberGenerator) -> void:
	var candidates: Array[String] = ["indent", "platform", "ring"]
	var id = candidates[rng.randi() % candidates.size()]

	var idx := rng.randi_range(0, g.genes.size())
	g.genes.insert(idx, LayoutGene.new(id, {}))
	

static func _remove_gene(g: LayoutGenome, rng: RandomNumberGenerator) -> void:
	if g.genes.size() <= 1:
		return

	var idx := rng.randi_range(0, g.genes.size() - 1)

	# Evita di rimuovere il divider base
	if g.genes[idx].operator_id == "divider":
		return

	g.genes.remove_at(idx)
	
static func _swap_genes(g: LayoutGenome, rng: RandomNumberGenerator) -> void:
	if g.genes.size() < 2:
		return

	var a := rng.randi_range(0, g.genes.size() - 1)
	var b := rng.randi_range(0, g.genes.size() - 1)

	if a == b:
		return

	var tmp := g.genes[a]
	g.genes[a] = g.genes[b]
	g.genes[b] = tmp

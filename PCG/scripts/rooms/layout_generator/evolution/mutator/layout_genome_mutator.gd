# ============================================================================
# LayoutGenomeMutator
# ============================================================================
## Applica mutazioni controllate a un LayoutGenome.
# ============================================================================

class_name LayoutGenomeMutator
extends GenomeMutator

var profile: RoomSizeProfile

func _init(_profile: RoomSizeProfile):
	profile = _profile


func mutate(genome: Genome, rng: RandomNumberGenerator) -> Genome:
	var g: LayoutGenome = genome as LayoutGenome
	if g == null:
		return genome

	var clone: LayoutGenome = g.clone()

	match rng.randi_range(0, 3):
		0:
			_mutate_param(clone, rng)
		1:
			_add_gene(clone, rng)
		2:
			_remove_gene(clone, rng)
		3:
			_swap_genes(clone, rng)

	return clone


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

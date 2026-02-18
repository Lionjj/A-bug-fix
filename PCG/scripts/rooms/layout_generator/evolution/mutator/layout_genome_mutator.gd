# ============================================================================
# LayoutGenomeMutator
# ============================================================================
## Applica mutazioni controllate a un LayoutGenome.
# ============================================================================

class_name LayoutGenomeMutator
extends GenomeMutator

const ADD_PRIMARY_OP_PROBABILITY: float = 0.2

var profile: RoomSizeProfile
var registry: OperatorRegistry
var rng: RandomNumberGenerator

func _init(_context: LayoutGenomaContext):
	profile = _context.size_profile
	registry = _context.operator_registry
	rng = _context.rng


func mutate(genome: Genome) -> Genome:
	var g: LayoutGenome = genome as LayoutGenome
	if g == null:
		return genome

	var clone: LayoutGenome = g.clone()

	match rng.randi_range(0, 3):
		0:
			_mutate_param(clone)
		1:
			_add_gene(clone)
		2:
			_remove_gene(clone)
		3:
			_swap_genes(clone)

	return clone


func _mutate_param(g: LayoutGenome) -> void:
	if g.genes.is_empty():
		return
		
	var gene: LayoutGene = g.genes[rng.randi_range(0, g.genes.size() - 1)]
	
	var op: LayoutOperator = registry.get_operator(gene.type)
	if op == null:
		return
	
	op.mutate_params()


func _add_gene(g: LayoutGenome) -> void:
	var role: int = LayoutOperator.Role.SECONDARY
	
	if rng.randf() < ADD_PRIMARY_OP_PROBABILITY:
		role = LayoutOperator.Role.PRIMARY
	
	var picker: OperatorPicker = OperatorPicker.new(registry, rng)
	var type: int = picker.pick_operator(role)
	
	if type == -1:
		return
	
	var op: LayoutOperator = registry.get_operator(type)
	var params: Dictionary = op.create_random_params()

	var idx: int = rng.randi_range(0, g.genes.size())
	g.genes.insert(idx, LayoutGene.new(type, params))

func _remove_gene(g: LayoutGenome) -> void:
	if g.genes.size() <= 1:
		return

	var candidates: Array[int] = []

	for i in range(g.genes.size()):
		var op: LayoutOperator = registry.get_operator(g.genes[i].type)
		if op.role == LayoutOperator.Role.SECONDARY:
			candidates.append(i)

	if candidates.is_empty():
		return

	var idx: int = candidates[rng.randi() % candidates.size()]
	g.genes.remove_at(idx)

	
func _swap_genes(g: LayoutGenome) -> void:
	if g.genes.size() < 2:
		return

	var a: int = rng.randi_range(0, g.genes.size() - 1)
	var b: int = rng.randi_range(0, g.genes.size() - 1)

	if a == b:
		return

	var tmp: LayoutGene = g.genes[a]
	g.genes[a] = g.genes[b]
	g.genes[b] = tmp

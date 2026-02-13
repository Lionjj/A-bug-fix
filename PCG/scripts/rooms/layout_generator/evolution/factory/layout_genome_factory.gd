# ============================================================================
# LayoutGenomeFactory
# ============================================================================
## Crea genomi iniziali e li muta.
# ============================================================================

class_name LayoutGenomeFactory
extends GenomeFactory

var profile: RoomSizeProfile
var operator_registry: OperatorRegistry
var rng: RandomNumberGenerator

func _init(_context: LayoutContext) -> void:
	profile = _context.size_profile
	operator_registry = _context.operator_registry
	rng = _context.rng


func random_genome(rng: RandomNumberGenerator) -> LayoutGenome:
	var g: LayoutGenome = LayoutGenome.new()
	var picker: OperatorPicker = OperatorPicker.new(operator_registry, rng)
	
	# --------------------------------------------------
	# Operatori primari
	# --------------------------------------------------
	
	var primary_type: int = picker.pick_operator(LayoutOperator.Role.PRIMARY)
	if primary_type == -1:
		return g
	
	var primary_op: LayoutOperator = operator_registry.get_operator(primary_type)
	var primary_params : Dictionary = primary_op.create_random_params(rng, profile)
	
	g.genes.append(LayoutGene.new(primary_type, primary_params))
	
	
	# --------------------------------------------------
	# Operatori secondari
	# --------------------------------------------------
	
	## TODO: Attualmente viene generato un solo operatore secondario
	## espandere questa cosa con più operatori
	
	var secondary_type: int = picker.pick_operator(LayoutOperator.Role.SECONDARY)
	if secondary_type == -1:
		return g

	var secondary_op: LayoutOperator = operator_registry.get_operator(secondary_type)
	var secondary_params: Dictionary = secondary_op.create_random_params(rng, profile)

	g.genes.append(LayoutGene.new(secondary_type, secondary_params))
	
	
	# --------------------------------------------------
	# Applicazione dei connettori
	# --------------------------------------------------
	
	
	
	return g

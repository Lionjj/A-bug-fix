# ============================================================================
# LayoutGenomeFactory
# ============================================================================
## Crea genomi iniziali e li muta.
# ============================================================================

class_name LayoutGenomeFactory
extends GenomeFactory

var profile: RoomSizeProfile
var operator_registry: OperatorRegistry


func _init(_context: LayoutGenomaContext) -> void:
	super._init(_context.rng)
	profile = _context.size_profile
	operator_registry = _context.operator_registry


func random_genome() -> LayoutGenome:
	var g: LayoutGenome = LayoutGenome.new()
	## TODO: Il picker va aggiustato per essere riadattato al nuovo registry
	var picker: OperatorPicker = OperatorPicker.new(operator_registry, rng)
	
	# --------------------------------------------------
	# Operatori obbligatori
	# --------------------------------------------------
	
	var connector_type: int = LayoutOperator.Type.CONNECTOR
	var connector_op: LayoutOperator = operator_registry.get_operator(connector_type)
	
	var connector_params: Dictionary = connector_op.create_random_params()
	g.genes.append(LayoutGene.new(connector_type, connector_params))

	# --------------------------------------------------
	# Operatori obbligatori
	# --------------------------------------------------
	
	var backbone_type: int = LayoutOperator.Type.BACKBONE
	var backbone_op: LayoutOperator = operator_registry.get_operator(backbone_type)
	
	var backbone_params: Dictionary = backbone_op.create_random_params()
	g.genes.append(LayoutGene.new(backbone_type, backbone_params))
	
	# --------------------------------------------------
	# Operatori primari
	# --------------------------------------------------
	#
	#var primary_type: int = picker.pick_operator(LayoutOperator.Role.PRIMARY)
	#if primary_type == -1:
		#return g
	#
	#var primary_op: LayoutOperator = operator_registry.get_operator(primary_type)
	#var primary_params : Dictionary = primary_op.create_random_params()
	#
	#g.genes.append(LayoutGene.new(primary_type, primary_params))
	#
	
	# --------------------------------------------------
	# Operatori secondari
	# --------------------------------------------------
	
	## TODO: Attualmente viene generato un solo operatore secondario
	## espandere questa cosa con più operatori
	
	var secondary_type: int = picker.pick_operator(LayoutOperator.Role.SECONDARY)
	if secondary_type == -1:
		return g

	var secondary_op: LayoutOperator = operator_registry.get_operator(secondary_type)
	var secondary_params: Dictionary = secondary_op.create_random_params()

	g.genes.append(LayoutGene.new(secondary_type, secondary_params))
	
	
	# --------------------------------------------------
	# Applicazione dei connettori
	# --------------------------------------------------
	
	return g

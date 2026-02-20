# ============================================================================
# LayoutPhenotypeBuilder
# ============================================================================
## Costruisce il fenotipo (RoomLayoutMask) a partire da un LayoutGenome.
##
## RESPONSABILITÀ:
## - Creare una RoomLayoutMask iniziale
## - Applicare in ordine i geni del genome
## - Restituire mask + ConnectorPlan
# ============================================================================

class_name LayoutPhenotypeBuilder
extends RefCounted


static func build(
	genome: LayoutGenome,
	genome_context: LayoutGenomaContext
) -> LayoutValidatorContext:
	
	if genome == null or genome_context == null:
		return null
	
	var size_profile := genome_context.size_profile
	var rng := genome_context.rng
	var registry := genome_context.operator_registry
	var size := genome_context.size
	
	var layout_context := LayoutContext.new(size_profile, rng, size)
	var mask := RoomLayoutMask.new(layout_context)
	
	if mask == null:
		return null
		
	var operator_context := OperatorContext.new(
		size_profile,
		rng,
		size,
		mask
	)

	for gene in genome.genes:
		_apply_gene(gene, registry, operator_context)

	return LayoutValidatorContext.new(
		mask,
		operator_context.connector_plan
	)


static func _apply_gene(
	gene: LayoutGene,
	registry: OperatorRegistry,
	context: OperatorContext
) -> void:
	
	var operator := registry.instantiate(
		gene.type,
		context,
		gene.params
	)
	
	operator.apply()

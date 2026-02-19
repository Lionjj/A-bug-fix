# ============================================================================
# RoomLayoutGenerator
# ============================================================================
## Pipeline di generazione di una RoomLayoutMask.
##
## RESPONSABILITÀ:
## - Creare una RoomLayoutMask vuota
## - Applicare gli operatori in ordine
## - Gestire i fallimenti senza rompere lo stato
##
## NON FA:
## - scoring
## - selezione
## - evoluzione
##
## FILOSOFIA:
## - Deterministica (seed-based)
## - Fail-first
## - Ogni operatore è opzionale
##
## USO TIPICO:
## - Chiamata diretta (debug)
## - Usata da LayoutEvolutionEngine
##
## ORDINE PIPELINE:
## Size → Divider → Indent → Platform → Ring → Connector
# ============================================================================

class_name RoomLayoutGenerator
extends RefCounted


static func generate_from_genome(
	genome: LayoutGenome,
	genome_context: LayoutGenomaContext
) -> LayoutValidatorContext:
	
	if genome == null or genome_context == null:
		return null
	
	var size_profile := genome_context.size_profile
	var rng := genome_context.rng
	var registry := genome_context.operator_registry
	
	var layout_context: LayoutContext = LayoutContext.new(size_profile, rng)
	
	var mask := RoomLayoutMask.new(layout_context)
	if mask == null:
		return null
		
	var operator_context: OperatorContext = OperatorContext.new(size_profile, rng, mask)

	for gene in genome.genes:
		_apply_gene(gene, registry, operator_context)

	return LayoutValidatorContext.new(mask, operator_context.connector_plan)


static func _apply_gene(
	gene: LayoutGene,
	registry: OperatorRegistry,
	context: OperatorContext
) -> void:
	var operator: LayoutOperator = registry.istanziate(
		gene.type,
		context,
		gene.params
	)
	
	operator.apply()

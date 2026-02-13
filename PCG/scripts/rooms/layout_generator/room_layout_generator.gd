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
	context: LayoutContext
) -> RoomLayoutMask:

	if genome == null or context == null:
		return null

	var mask := RoomLayoutMask.new(context)
	if mask == null:
		return null

	for gene in genome.genes:
		_apply_gene(mask, gene, context)

	return mask


static func _apply_gene(
	mask: RoomLayoutMask,
	gene: LayoutGene,
	context: LayoutContext
) -> void:

	var registry := context.operator_registry
	if registry == null:
		return

	var op: LayoutOperator = registry.get_operator(gene.type)
	if op == null:
		return

	op.apply(mask, context, gene.params)

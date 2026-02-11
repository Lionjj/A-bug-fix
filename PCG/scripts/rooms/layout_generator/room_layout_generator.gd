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

static var OPERATOR_REGISTRY := {
	## --- operatori primari ---
	"divider": DividerOperator,
	"ring": RingOperator,
	"split_corner": SplitCornerOperator,
	
	## --- operatori secondari ---
	"platform": PlatformOperator,
	"indent": IndentOperator,
	"pillar": PillarOperator
}



# ---------------------------------------------------------------------------
# Entry point pubblico
# ---------------------------------------------------------------------------

static func generate(context: LayoutContext) -> RoomLayoutMask:
	# ------------------------------------------------------------
	# 0) Validazione contesto
	# ------------------------------------------------------------
	if context == null:
		return null
	if context.size_profile == null:
		return null
	if context.rng == null:
		return null

	# ------------------------------------------------------------
	# 1) Creazione mask base
	# ------------------------------------------------------------
	var mask: RoomLayoutMask = RoomLayoutMask.new(context)
	if mask == null:
		return null

	# ------------------------------------------------------------
	# 2) Applicazione operatori (fail-soft)
	# ------------------------------------------------------------

	# Divider (primario)
	DividerOperator.apply(mask, context)

	# Indent (locale)
	IndentOperator.apply(mask, context)

	# Platform (secondario)
	PlatformOperator.apply(mask, context)

	# Ring (strutturale, opzionale)
	RingOperator.apply(mask, context)

	## Connector (ultimo, se presente)
	#if Engine.has_singleton("ConnectorOperator"):
		#ConnectorOperator.apply(mask, context)

	return mask


static func generate_from_genome(
	genome: LayoutGenome,
	context: LayoutContext
) -> RoomLayoutMask:
	# 0) validazione minima
	if genome == null or context == null:
		return null

	# 1) crea la mask base (come prima)
	var mask: RoomLayoutMask = RoomLayoutMask.new(context)
	if mask == null:
		return null

	# 2) applica i geni IN ORDINE
	for gene in genome.genes:
		_apply_gene(mask, gene, context)

	return mask


static func _apply_gene(
	mask: RoomLayoutMask,
	gene: LayoutGene,
	context: LayoutContext
) -> void:
	if not OPERATOR_REGISTRY.has(gene.operator_id):
		return

	OPERATOR_REGISTRY[gene.operator_id].apply(mask, context, gene.params)

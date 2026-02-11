# ============================================================================
# LayoutGenome
# ============================================================================
## Genoma completo di una stanza.
## Descrive COME viene generata.
# ============================================================================

class_name LayoutGenome
extends RefCounted

## Sequenza ordinata di operatori
var genes: Array[LayoutGene] = []

func clone() -> LayoutGenome:
	var g := LayoutGenome.new()
	for gene in genes:
		g.genes.append(
			LayoutGene.new(
				gene.operator_id,
				gene.params.duplicate(true)
			)
		)
	return g

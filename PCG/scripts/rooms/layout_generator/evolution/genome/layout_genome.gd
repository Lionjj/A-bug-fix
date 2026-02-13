# ============================================================================
# LayoutGenome
# ============================================================================
## Genoma completo di una stanza.
## Descrive COME viene generata.
# ============================================================================

class_name LayoutGenome
extends Genome

## Sequenza ordinata di operatori
var genes: Array[LayoutGene] = []

func clone() -> LayoutGenome:
	var g: LayoutGenome = LayoutGenome.new()
	for gene in genes:
		g.genes.append(
			LayoutGene.new(
				gene.type,
				gene.params.duplicate(true)
			)
		)
	return g

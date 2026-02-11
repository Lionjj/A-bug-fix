# ============================================================================
# GenomeFactory
# ============================================================================
## Classe astratta rappresentate la FitnessEvaluator
# ============================================================================

class_name LayoutFitnessEvaluator
extends FitnessEvaluator

var context: LayoutContext

func _init(_context: LayoutContext) -> void:
	context = _context
	

func evaluate(genome: Genome) -> float:
	var g: LayoutGenome = genome as LayoutGenome
	if g == null:
		return -INF

	var mask: RoomLayoutMask = RoomLayoutGenerator.generate_from_genome(g, context)
	if mask == null:
		return -INF

	var validation: LayoutValidatorContext = LayoutValidator.validate(mask)
	if not validation.is_valid:
		return -INF

	return LayoutScorer.score(mask) + validation.score

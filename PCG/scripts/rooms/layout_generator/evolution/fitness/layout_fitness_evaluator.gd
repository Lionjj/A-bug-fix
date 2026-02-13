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
	
	var plan: ConnectorPlan = ConnectorPlanner.build(mask)
	if plan == null:
		return -INF
	print(debug_print_with_connectors(mask, plan))
	
	var traversal : float = TraversalAnalyzer._evaluate_traversal(mask, plan)
	print(traversal)
	if traversal < 0:
		return -INF
	

	return LayoutScorer.score(mask) + validation.score

static func debug_print_with_connectors(
	mask: RoomLayoutMask,
	plan: ConnectorPlan
) -> String:

	var grid := []

	# Copia mask in char matrix
	for y in range(mask.size.y):
		var row := []
		for x in range(mask.size.x):
			row.append("#" if mask.is_solid(x, y) else ".")
		grid.append(row)

	# Disegna connettori
	for d in Dir4.ORDER:

		var coord := plan.get_coord(d)
		var width := plan.get_width(d)

		match d:

			Dir4.D.N:
				for i in range(width):
					var x := coord - width/2 + i
					grid[0][x] = "N"

			Dir4.D.S:
				for i in range(width):
					var x := coord - width/2 + i
					grid[mask.size.y - 1][x] = "S"

			Dir4.D.W:
				for i in range(width):
					var y := coord - width/2 + i
					grid[y][0] = "W"

			Dir4.D.E:
				for i in range(width):
					var y := coord - width/2 + i
					grid[y][mask.size.x - 1] = "E"

	# Converte in stringa
	var lines := []
	for y in range(mask.size.y):
		lines.append("".join(grid[y]))

	return "\n".join(lines)

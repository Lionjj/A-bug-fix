# ============================================================================
# RoomLayoutTester
# ============================================================================

extends Node

@onready var text_edit: TextEdit = $TextEdit


func _on_button_pressed() -> void:

	var seed: int = int(text_edit.text)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	print("=== START EVOLUTION | SEED:", seed, "===")

	# --------------------------------------------------
	# Context
	# --------------------------------------------------

	var size_profile := RoomSizeProfile.new()
	var operator_registry := OperatorRegistry.new()
	var context := LayoutContext.new(size_profile, rng, operator_registry)

	# --------------------------------------------------
	# Core Components
	# --------------------------------------------------

	var factory := LayoutGenomeFactory.new(context)
	var mutator := LayoutGenomeMutator.new(context)
	var evaluator := LayoutFitnessEvaluator.new(context)
	var selection := TopKSelection.new()
	var reproduction := ElitistMutationReproduction.new()

	# --------------------------------------------------
	# Engine
	# --------------------------------------------------

	var engine := EvolutionEngine.new(
		factory,
		mutator,
		evaluator,
		selection,
		reproduction,
		rng
	)

	# --------------------------------------------------
	# Evolve
	# --------------------------------------------------

	var best_genome: Genome = engine.evolve()

	if best_genome == null:
		print("❌ Nessun genome valido trovato")
		return

	# Generiamo la mask finale
	var best_layout := RoomLayoutGenerator.generate_from_genome(
		best_genome,
		context
	)

	if best_layout == null:
		print("❌ Layout nullo")
		return

	print("=== BEST LAYOUT ===")
	print(best_layout.to_ascii())
	

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

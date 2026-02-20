# ============================================================================
# RoomLayoutTester
# ============================================================================

extends Node

@onready var text_edit: TextEdit = $TextEdit
var need_to_mute: bool = false

func _on_button_pressed() -> void:
	gen_genome()
	

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

func gen_genome():
	
	var seed: int = int(text_edit.text)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	print("=== START EVOLUTION | SEED:", seed, "===")

	# --------------------------------------------------
	# Context
	# --------------------------------------------------

	var size_profile := RoomSizeProfile.new()
	var room_picker := RoomSizePicker.new(size_profile, rng)
	var size := room_picker.pick()
	var operator_registry := OperatorRegistry.new()
	var traversal_profile := PlayerTraversalProfile.new()
	var context := LayoutGenomaContext.new(
		size_profile, rng, operator_registry, traversal_profile, size
	)
	

	# --------------------------------------------------
	# Core Components
	# --------------------------------------------------

	var factory := LayoutGenomeFactory.new(context)
	var mutator := LayoutGenomeMutator.new(context)
	var evaluator := LayoutFitnessEvaluator.new(context)
	var selection := TopKSelection.new()
	var reproduction := ElitistHybridReproduction.new()

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
	var t0 := Time.get_ticks_msec()
	
	var best_genome: Genome = engine.evolve()
	
	print("EVOLVE TOTAL:", Time.get_ticks_msec() - t0, "ms")
	if best_genome == null:
		print("❌ Nessun genome valido trovato")
		return
	
	t0 = Time.get_ticks_msec()
	# Generiamo la mask finale
	var best_layout := LayoutPhenotypeBuilder.build(
		best_genome,
		context
	)
	print("BUILD TIME:", Time.get_ticks_msec() - t0, "ms")

	if best_layout == null:
		print("❌ Layout nullo")
		return

	print("=== BEST LAYOUT ===")
	print(debug_print_with_connectors(best_layout.mask, best_layout.plan))

#func debug():
	#var seed: int = int(text_edit.text)
#
	#var rng := RandomNumberGenerator.new()
	#rng.seed = seed
#
	#print("=== START EVOLUTION | SEED:", seed, "===")
#
	## --------------------------------------------------
	## Context
	## --------------------------------------------------
#
	#var size_profile := RoomSizeProfile.new()
	#var context := LayoutContext.new(size_profile, rng)
	#var mask: RoomLayoutMask = RoomLayoutMask.new(context)
	#
	#var plan: ConnectorPlan = ConnectorPlanner.build(mask, context.rng)
	#
	#var context_op := OperatorContext.new(size_profile, rng, mask, plan)
	#var operator_registry := OperatorRegistry.new(context_op)
	#var backbone_op := BackboneOperator.new(context_op)
	#backbone_op.params = backbone_op.create_random_params()
	#
	#var plat_op := operator_registry.get_operator(LayoutOperator.Type.PLATFORM)
	#plat_op.params = plat_op.create_random_params()
	##
	##var pillar_op := operator_registry.get_operator(LayoutOperator.Type.PILLAR)
	##pillar_op.params = pillar_op.create_random_params()
	#if need_to_mute:
		#backbone_op.mutate_params()
		#plat_op.mutate_params()
		##pillar_op.mutate_params()
		#need_to_mute = false
	#
	##print(plat_op.params)
	##print(backbone_op.params)
		#
	#backbone_op.apply()
	##print(pillar_op.apply())
	#print(plat_op.apply())
#
	##for d in Dir4.ORDER:
		##if plan.is_enabled(d):
			##e.ensure_connector_access(d)
	##
	#
	 #
	#print(validate_all_connectors(mask, plan, PlayerTraversalProfile.new()))
	##for i in range(0, 3):
		##print(PlatformOperator.new().apply(mask, context))
		##print(PillarOperator.new().apply(mask, context), "\n")
	#
#
#
#func _on_muta_pressed() -> void:
	#need_to_mute = true
	#
	#
#func validate_all_connectors(
	#mask: RoomLayoutMask,
	#plan: ConnectorPlan,
	#profile: PlayerTraversalProfile
#) -> bool:
	#var all_reachable: bool = true
	#var temp_mask := mask.duplicate()
#
	## 1️⃣ Carve tutti i connettori
	#for dir in Dir4.ORDER:
		#if plan.is_enabled(dir):
			#PlayerReachability.carve_connector_volume(temp_mask, plan, dir)
#
	## 2️⃣ Lista connettori attivi
	#var enabled_dirs: Array[int] = []
	#for dir in Dir4.ORDER:
		#if plan.is_enabled(dir):
			#enabled_dirs.append(dir)
#
	## 3️⃣ Test pairwise
	#for i in range(enabled_dirs.size()):
#
		#var from_dir: int = enabled_dirs[i]
		#var start: Vector2i = PlayerReachability.get_connector_entry_cell(
			#temp_mask,
			#plan,
			#from_dir
		#)
#
		#if start.x == -1:
			#print("ERRORE start invalido:", from_dir)
			#return false
#
		#for j in range(enabled_dirs.size()):
#
			#if i == j:
				#continue
#
			#var to_dir: int = enabled_dirs[j]
#
			#var targets := PlayerReachability.get_connector_volume_cells(
				#temp_mask,
				#plan,
				#to_dir
			#)
#
			#var path := PlayerReachability.find_path(
				#temp_mask,
				#profile,
				#start,
				#targets
			#)
#
			#if path.is_empty():
				#print("SOFTLOCK:", from_dir, "->", to_dir)
				#all_reachable = false
			#print(PlayerReachability.debug_draw_path(temp_mask, path))
#
	#return all_reachable

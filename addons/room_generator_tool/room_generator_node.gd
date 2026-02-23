@tool
class_name RoomGeneratorNode
extends Node

@export var seed: int = 1
@export var save_path: String = "res://generated_rooms/room.tscn"

var _last_generated: RoomTemplateMeta = null


# ============================================================
# GENERAZIONE
# ============================================================

func generate() -> RoomTemplateMeta:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# --------------------------
	# Context
	# --------------------------
	var size_profile := RoomSizeProfile.new()
	var room_picker := RoomSizePicker.new(size_profile, rng)
	var size := room_picker.pick()

	var operator_registry := OperatorRegistry.new()
	var traversal_profile := PlayerTraversalProfile.new()

	var context := LayoutGenomaContext.new(
		size_profile,
		rng,
		operator_registry,
		traversal_profile,
		size
	)

	# --------------------------
	# Evolution
	# --------------------------
	var factory := LayoutGenomeFactory.new(context)
	var mutator := LayoutGenomeMutator.new(context)
	var evaluator := LayoutFitnessEvaluator.new(context)
	var selection := TopKSelection.new()
	var reproduction := ElitistHybridReproduction.new()

	var engine := EvolutionEngine.new(
		factory,
		mutator,
		evaluator,
		selection,
		reproduction,
		rng
	)

	var best_genome: Genome = engine.evolve()
	if best_genome == null:
		push_error("No valid genome found")
		return null

	var layout := LayoutPhenotypeBuilder.build(best_genome, context)
	if layout == null:
		push_error("Layout failed")
		return null

	var room := LayoutToRoomTemplateBuilder.build_from_layout(layout)
	if room == null:
		push_error("Room build failed")
		return null

	return room


# ============================================================
# AGGIUNTA ALLA SCENA (PREVIEW EDITABILE)
# ============================================================

func add_to_scene(room: RoomTemplateMeta) -> void:
	var root := get_tree().edited_scene_root
	if root == null:
		push_error("No open scene")
		return

	# Remove previous generated room
	if _last_generated and _last_generated.get_parent():
		_last_generated.queue_free()

	root.add_child(room)
	
	room.get_node_or_null("Placement").queue_free()
	

	_set_owner_recursive(room, root)

	_last_generated = room


# ============================================================
# SALVATAGGIO SU FILE
# ============================================================

func save_last() -> void:
	if _last_generated == null:
		push_error("Nothing generated to save")
		return

	var clone := _last_generated.duplicate()
	
	#if not save_path.ends_with(".tscn"):
		#save_path += ".tscn"
	#
	var dir := save_path.get_base_dir()
	var file := save_path.get_file()
	var base := file.get_basename()
	save_path = dir + "/" + base.to_upper() + ".tscn"
	
	var scene_name := file.get_basename().capitalize()
	clone.name = scene_name
	

	_set_owner_recursive(clone, clone)

	var packed := PackedScene.new()
	if packed.pack(clone) != OK:
		push_error("Pack failed")
		return

	var err := ResourceSaver.save(packed, save_path)
	if err != OK:
		push_error("Save failed: " + str(err))
		return
	
	print("Room saved at:", save_path)


# ============================================================
# UTIL
# ============================================================

func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child, owner)

# ============================================================================
# RoomLayoutTester
# ============================================================================
extends Node

@onready var text_edit: TextEdit = $TextEdit

func _on_button_pressed() -> void:
	var seed := int(text_edit.text)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var size_profile := RoomSizeProfile.new()
	var context := LayoutContext.new(size_profile, rng)

	print("=== START EVOLUTION | SEED:", seed, "===")

	var best_mask := LayoutEvolutionEngine.evolve(context)

	if best_mask == null:
		print("❌ Nessun layout valido trovato")
		return

	print("=== BEST LAYOUT ===")
	print(best_mask.to_ascii())

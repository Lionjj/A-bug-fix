# ============================================================================
# RoomLayoutTester
# ============================================================================
extends Node

var level_seed: int = 2
var room_id: String = "S"
@onready var text_edit: TextEdit = $TextEdit





func _on_button_pressed() -> void:
	var seed = int(text_edit.text)
	# -------------------------------------------------------
	# FASE 1 — Selezione size
	# -------------------------------------------------------
	var room_picker: RoomSizePicker = RoomSizePicker.new(RoomSizeProfile.new())
	var size: Vector2i = room_picker.pick()
	print("\n=== SIZE SELEZIONATA:", size, "===")

	# -------------------------------------------------------
	# Creazione maschera
	# -------------------------------------------------------
	var mask := RoomLayoutMask.new(size)

	# -------------------------------------------------------
	# FASE 2 — Seed iniziale
	# -------------------------------------------------------
	var rng := RandomNumberGenerator.new()
	rng.seed = seed ^ hash(room_id)

	var policy := OpeningPolicy.new()
	var rules := RoomLayoutRules.new(mask, rng, policy)

	rules.apply_seed()
	print("\n--- DOPO SEED ---")
	print(mask.to_ascii())

	# -------------------------------------------------------
	# FASE 3 — Indent (prima dei connettori)
	# -------------------------------------------------------
	# Qui fai layout “interessante” ma ancora senza connettori.
	# Metti SEMPRE pochi indent (1-2) per evitare chiusure/strozzature inutili.c'è un problema però 
	# Se vuoi, randomizza: lato, width, depth.
	#rules.apply_indent(Dir4.D.N, 4, 6)
	#rules.apply_indent(Dir4.D.S, 4, 6)
	#rules.apply_indent(Dir4.D.E, 4, 6)
	#rules.apply_indent(Dir4.D.W, 4, 6)

	print("\n--- DOPO INDENT (pre-connector) ---")
	var op := DividerOperator.new()
	op.apply(mask, rng)
	#var ro:= RingOperator.new()
	#ro.apply(mask, rng)
	#var io:= IndentOperator.new()
	#io.apply(mask, rng)
	var po:= PlatformOperator.new()
	po.apply(mask, rng)
	
	ConnectivityOperator.new().apply(mask)
	print(mask.to_ascii())

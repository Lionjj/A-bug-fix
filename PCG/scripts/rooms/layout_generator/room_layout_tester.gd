# ============================================================================
# RoomLayoutTester
# ============================================================================
extends Node

var level_seed: int = 3
var room_id: String = "S"

func _ready() -> void:
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
	rng.seed = level_seed ^ hash(room_id)

	var policy := OpeningPolicy.new()
	var rules := RoomLayoutRules.new(mask, rng, policy)

	rules.apply_seed()
	print("\n--- DOPO SEED ---")
	print(mask.to_ascii())

	# -------------------------------------------------------
	# FASE 3 — Indent (prima dei connettori)
	# -------------------------------------------------------
	# Qui fai layout “interessante” ma ancora senza connettori.
	# Metti SEMPRE pochi indent (1-2) per evitare chiusure/strozzature inutili.
	# Se vuoi, randomizza: lato, width, depth.
	rules.apply_indent(Dir4.D.N, 4, 6)
	rules.apply_indent(Dir4.D.S, 4, 6)
	#rules.apply_indent(Dir4.D.E, 4, 6)
	#rules.apply_indent(Dir4.D.W, 4, 6)

	print("\n--- DOPO INDENT (pre-connector) ---")
	print(mask.to_ascii())

	# -------------------------------------------------------
	# FASE 4 — Connettori (sulla mask finale)
	# -------------------------------------------------------
	var required_dirs := PackedInt32Array([Dir4.D.N, Dir4.D.S, Dir4.D.E, Dir4.D.W])
	mask.connector_plan = rules.build_connector_plan(required_dirs)

	print("\n--- DOPO CONNETTORI (overlay) ---")
	print(mask.to_ascii_with_connectors())

	# -------------------------------------------------------
	# (opzionale) FASE 4b — 1 indent extra protetto dai connettori
	# -------------------------------------------------------
	# Ora puoi usare constrained perché esiste il plan.
	# Fai pochissime iterazioni altrimenti rovini la stanza.
	# rules.apply_indent_constrained(Dir4.D.N, 4, 4)
	# rules.apply_indent_constrained(Dir4.D.E, 4, 4)

	# print("\n--- DOPO INDENT EXTRA PROTETTI ---")
	# print(mask.to_ascii_with_connectors())

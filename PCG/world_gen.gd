extends Node2D
class_name WorldGen
@export var budget_nodes :int
@export var seed :int
var abil_here :Array[Abilities.Ability]= [Abilities.Ability.GRAPPLE, Abilities.Ability.DASH]	# Abilità che il giocatore possiede
var rng = RandomNumberGenerator.new()

func _ready():
	rng.seed = seed
	build()

func build():
	Rng.set_seed(seed)

	# 1) Progressione
	var G : MissionGraph = load("res://PCG/progression/build_base_graph.gd").build_base()

	# 2) Espansione grammaticale
	load("res://PCG/grammar/expand_driver.gd").run(G, budget_nodes)

	# 3) Vincoli
	if not load("res://PCG/constraints/constraint_validator.gd").solvable(G):
		push_warning("Rigenero (non solvibile)")
		seed += 1; Rng.set_seed(seed)
		get_tree().reload_current_scene(); return

	# 4) Placer + Assembler
	var placer : BTPlacer = load("res://PCG/placer/bt_placer.gd").new()
	var assembler: RoomAssembler = load("res://PCG/rooms/room_assembler.gd").new()
	
	# 4a) caps
	var caps: Dictionary = assembler.caps_decide_for_graph(G, abil_here, rng)

	# 4b) RIPARA caps (promuove i figli all’asse del genitore)
	caps = placer._validate_and_fix_caps(G, caps, true, "promote_child_to_parent")

	# 4c) conns coerenti coi caps riparati
	var conns: Dictionary = {}
	for id in caps.keys():
		caps[id] = assembler.node_axes_caps(G.nodes[id], abil_here)
		var c = caps[id]
		var h := bool(c.get("H", true))
		var v := bool(c.get("V", true))
		conns[id] = {"N": v, "E": h, "S": v, "W": h}

	# DEBUG (facoltativo)
	for id in caps.keys():
		print(id, " -> H:", caps[id]["H"], " V:", caps[id]["V"], "  |  N/E/S/W:", conns[id])
		
	prints("Start:", G.start_id, "neighbors:", G.neighbors(String(G.start_id)))
	for v in G.neighbors(String(G.start_id)):
		prints("S->", v, "caps", caps[v], "conns", conns[v])

	# 5) Piazzamento su griglia (PASSA anche conns!)
	var positions : Dictionary = placer.place(G, rng, caps, conns)
	
	var cell_tiles: Vector2i = assembler.max_room_size_tiles()

	# 6) Istanziazione stanze rispettando i connettori RICHIESTI dai vicini
	for id in positions.keys():
		var cell: Vector2i = positions[id]

		# calcola quali lati servono DAVVERO per collegarsi ai vicini già piazzati
		var req := _required_connectors_for(String(id), positions, G)  # vedi funzione sotto

		# scegli un template che soddisfi req (vedi punto 3)
		var tmpl: PackedScene = assembler.pick_template_with_requirements(G.nodes[id], abil_here, positions, rng, req)
		
		var room: Node2D = assembler.instantiate_room(tmpl, cell, Vector2i(16,16), cell_tiles)

		add_child(room)
		room.owner = self

	# 7) Corridoi & dressing
	CorridorBuilder.connect_adjacent(self, positions, cell_tiles)
	#CorridorBuilder.beautify_corridors(self)  # opzionale, estetica

	# load("res://PCG/dressing/tile_dresser.gd").new().decorate(self, Rng.randi())

func _required_connectors_for(id: String, positions: Dictionary, G: MissionGraph) -> Dictionary:
	var req := {"N":false, "E":false, "S":false, "W":false}
	if not positions.has(id):
		return req

	var p: Vector2i = positions[id]

	# GUARDA TUTTE LE STANZE GIA' PIAZZATE attorno (non solo G.neighbors)
	for other_id_any in positions.keys():
		var other_id := String(other_id_any)
		if other_id == id:
			continue
		var d: Vector2i = positions[other_id] - p
		if d == Vector2i(1, 0):
			req["E"] = true
		elif d == Vector2i(-1, 0):
			req["W"] = true
		elif d == Vector2i(0, 1):
			req["S"] = true
		elif d == Vector2i(0, -1):
			req["N"] = true

	return req

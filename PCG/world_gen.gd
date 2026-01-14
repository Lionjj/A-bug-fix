extends Node2D
class_name WorldGen
@export var budget_nodes :int
@export var seed :int
@export var player: PackedScene
@export var run_level: int = 1
@onready var generator: WFC2DGenerator = $generator
var abil_here :Array[Abilities.Ability]= [Abilities.Ability.GRAPPLE, Abilities.Ability.DASH]	# Abilità che il giocatore possiede
var rng: RandomNumberGenerator
var spawn_point: Vector2
var G : MissionGraph
var rooms: Dictionary[RoomTemplateMeta, bool] = {}

var _rooms_waiting: int = 0

signal all_rooms_done

func _ready():
	build()

func build():
	# 1) Progressione
	G  = load("res://PCG/progression/build_base_graph.gd").build_base()

	# 2) Espansione grammaticale
	load("res://PCG/grammar/expand_driver.gd").run(G, budget_nodes)

	# 3) Vincoli
	if not load("res://PCG/constraints/constraint_validator.gd").solvable(G):
		push_warning("Rigenero (non solvibile)")
		seed += 1; Rng.set_seed(seed)
		get_tree().reload_current_scene(); return
	
	Rng.set_seed(seed)
	rng = Rng.get_rng()
#
	# 4) Placer + Assembler
	#var placer : BTPlacer = load("res://PCG/placer/bt_placer.gd").new()
	
	var assembler: RoomAssembler = load("res://PCG/rooms/room_assembler.gd").new()

	# 5) Piazzamento su griglia 
	var positions : Dictionary[String, Vector2i] = bfs_place_positions_random(G, rng.seed) 
	for n in G.nodes.keys():
		if positions.has(n):
			print("Sta tra le poszioni: ", n)
		else:
			print("Non è stato inserito: ", n, " vicini: ", G.neighbors(n))

	var cell_tiles: Vector2i = assembler.max_room_size_tiles()
	
	cell_tiles += Vector2i(4, 4)
	
	# 6) Istanziazione stanze rispettando i connettori RICHIESTI dai vicini
	for id in positions.keys():
		var cell: Vector2i = positions[id]

		# calcola quali lati servono DAVVERO per collegarsi ai vicini già piazzati
		var req := _required_connectors_for(String(id), positions, G)  # vedi funzione sotto

		# scegli un template che soddisfi req (vedi punto 3)
		var tmpl: PackedScene = assembler.pick_template_with_requirements(G.nodes[id], abil_here, positions, rng, req)
		
		var room: RoomTemplateMeta = assembler.instantiate_room(tmpl, cell, Vector2i(16, 16), cell_tiles)
		
		# Assegna il nodo logioco per le informazioni
		room.logic_node = G.nodes.get(id)
		
		# ==== DEBUG ====
		var n: MissionNode = G.nodes[id]
		var p = positions.get(id, null)
		print(id, " kind=", n.kind, " pos=", p, "tmpl=", room.kind)
		# ==== FINE DEBUG ====
		
		room.add_to_group("rooms")
		
		rooms[room] = false
		
		add_child(room)
		## Spawna gli oggetti in base a cio che è contenuto nei nodi
		#spawner._spawn(room, G.nodes.get(id))
		
		_rooms_waiting +=1
		
		room.owner = self
		
		room.done.connect(_on_room_enemies_done)
	
	#if _rooms_waiting > 0:
		#await all_rooms_done
		
	spawn_point = get_spawn_point()
	
	# 7) Corridoi & dressing
	CorridorBuilder.connect_adjacent(self, positions, cell_tiles, G)

	generator.rect = await _merge_tile()
	generator.start()
	
	await generator.done
	
	add_child(RoomsManager.new(G, rooms, positions, GameManager.player, run_level))
	
	
	
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

func _merge_tile() -> Rect2i:
	var final: TileMapLayer = get_node_or_null("Final")
	var corridor: TileMapLayer = get_node_or_null("Corridor")
	var out: Rect2i = Rect2i()
	if !final or !corridor: return out 
	
	
	var src_layer: Array[TileMapLayer]
	
	for room in get_tree().get_nodes_in_group("rooms"):
		var tile: TileMapLayer = room.get_node_or_null("Collision")
		
		if !tile: continue
		
		src_layer.append(tile)
		
		tile.visible = false
		
	
	src_layer.append(corridor)
	out = _merge(final, src_layer)
	
	
	#for room in get_tree().get_nodes_in_group("rooms"): room.queue_free()
	
	corridor.queue_free()
	
	return out

func _merge(final: TileMapLayer, src_layer: Array[TileMapLayer]) -> Rect2i:
	var min_x :=  2147483647
	var min_y :=  2147483647
	var max_x := -2147483648
	var max_y := -2147483648
	var found := false
	
	for src in src_layer:
		for cell in src.get_used_cells():
			var sid := src.get_cell_source_id(cell)
			if sid == -1:
				continue
			
			var atlas := src.get_cell_atlas_coords(cell)
			
			var world_local_src := src.map_to_local(cell)
			var world_global := src.to_global(world_local_src)
			var dst_local := final.to_local(world_global)
			var dst_map := final.local_to_map(dst_local)
			
			# FUSIBILE DI SICUREZZA: niente coordinate assurde
			if abs(dst_map.x) > 10000 or abs(dst_map.y) > 10000:
				push_warning("Merge: salto cella fuori scala %s da '%s'" % [dst_map, src.name])
				continue
			
			min_x = min(min_x, dst_map.x)
			min_y = min(min_y, dst_map.y)
			max_x = max(max_x, dst_map.x)
			max_y = max(max_y, dst_map.y)
			found = true
			
			final.set_cell(dst_map, sid, atlas)
	
	if not found:
		return Rect2i()  # vuoto

	var w := max_x - min_x + 1
	var h := max_y - min_y + 1

	# Controllo che il rect non sia folle
	if w <= 0 or h <= 0 or w > 10000 or h > 10000:
		push_warning("Merge: rect invalido/ENORME (%d x %d) da [%d..%d]x[%d..%d]. Uso final.get_used_rect()" % [
			w, h, min_x, max_x, min_y, max_y
		])
		var used := final.get_used_rect()
		return Rect2i(used.position, used.size)

	var rect := Rect2i(Vector2i(min_x, min_y), Vector2i(w, h))
	print("Merge rect:", rect)
	return rect

func spawn_palyer(spwan_point: Vector2):
	var player_istance : Player = player.instantiate()
		
	player_istance.global_position = spwan_point
	
	add_child(player_istance)
	
	player_istance.movement_enabled = true
	player_istance.wall_check_enabled = true
	
	GameManager.set_player(player_istance)
	
func get_spawn_point() -> Vector2:
	var start_room: RoomTemplateMeta = get_tree().get_first_node_in_group("rooms")
	if !start_room:
		push_error("Start room not found")
		return Vector2(0,0)
		
	return start_room.get_spawn_point().global_position


func _on_generator_done() -> void:
	$Final.queue_free()
	spawn_palyer(spawn_point)
	await get_tree().process_frame
	await get_tree().physics_frame
	pass

func _on_room_enemies_done() -> void:
	_rooms_waiting -= 1
	if _rooms_waiting <= 0: emit_signal("all_rooms_done")
	
func bfs_place_positions_random(G: MissionGraph, seed: int) -> Dictionary[String, Vector2i]:
	var positions :Dictionary[String, Vector2i]= {}         # id → Vector2i
	var occupied :Dictionary[Vector2i, String]= {}          # Vector2i → id
	var queue : Array[String] = []
	var to_place : Array[String]= []

	# 1. START in (0,0)
	var start := G.start_id
	positions[start] = Vector2i(0, 0)
	occupied[Vector2i(0,0)] = start
	queue.append(start)

	# 2. BFS
	while queue.size() > 0:
		var u = queue.pop_front()
		var u_pos = positions[u]

		for v_any in G.neighbors(u):
			var v := String(v_any)

			# già visitato?
			if positions.has(v):
				continue

			# 3. Trova celle adiacenti libere
			var candidates := _free_adjacent_cells(u_pos, occupied)

			if candidates.is_empty():
				to_place.append(v)
				push_warning("Nessuna posizione disponibile vicino a %s per %s" % [u, v])
				continue

			# 4. Random deterministico
			var chosen = candidates[rng.randi_range(0, candidates.size() - 1)]

			# 5. Registra posizione
			positions[v] = chosen
			occupied[chosen] = v
			queue.append(v)
			
	if !to_place.is_empty(): _place_appended_nodes(G, to_place, positions, occupied)
	
	return positions

func _place_appended_nodes(G: MissionGraph, to_place:Array, positions: Dictionary[String, Vector2i], occupied: Dictionary[Vector2i, String]):
	var queue := to_place.duplicate()
	var checked := []
	var done := []
	checked.append("B")
	
	while !queue.is_empty():
		var current = queue.pop_front()
		if positions.has(current): continue
		
		var adiacents = G.neighbors(current).duplicate().filter(func(node:String): if positions.has(node): return node)
		
		while !adiacents.is_empty():
			var ad = adiacents.pop_front()

			var pos = positions.get(ad)
			
			var candidates = _free_adjacent_cells(pos, occupied)
			
			if !candidates.is_empty():
				var chosen = candidates[rng.randi_range(0, candidates.size() - 1)]
				
				positions[current] = chosen
				occupied[chosen] = current
				done.append(current)
				
				G.add_edge(current, ad)
				adiacents.clear()
				
				queue.append_array(G.neighbors(current).duplicate().filter(func(node: String): if ad != node and !done.has(node): return node))
				
				break
			
			G.erase_edge(ad, current)
			checked.append(ad)
			adiacents.append_array(G.neighbors(ad).duplicate().filter(func(node: String): if !checked.has(node) and positions.has(node): return node))
			

func _free_adjacent_cells(pos: Vector2i, occupied: Dictionary) -> Array:
	var dirs := [
		Vector2i(1,0),
		Vector2i(-1,0),
		Vector2i(0,1),
		Vector2i(0,-1)
	]

	var out := []
	for d in dirs:
		var c = pos + d
		if not occupied.has(c):
			out.append(c)

	return out

func _draw():
	var radius := 20
	var level_gap := 180
	var y_gap := 140

	# ---- 1) BFS PER DISTRIBUIRE I NODI SU LIVELLI ----
	var levels := {}         # livello -> array di id
	var queue := []
	var visited := {}

	queue.append(G.start_id)
	visited[G.start_id] = true
	levels[0] = [G.start_id]

	var current_level := 0

	while queue.size() > 0:
		var next_level_ids := []
		for _i in range(queue.size()):
			var u = queue.pop_front()
			for v in G.neighbors(u):
				if not visited.has(v):
					visited[v] = true
					next_level_ids.append(v)
					queue.append(v)
		if next_level_ids.size() > 0:
			current_level += 1
			levels[current_level] = next_level_ids

	# ---- 2) ASSEGNA POSIZIONI VISIVE ----
	var node_positions := {}

	for lvl in levels.keys():
		var arr = levels[lvl]
		var count = arr.size()

		for i in range(count):
			node_positions[arr[i]] = Vector2(
				lvl * level_gap,
				i * y_gap
			)

	# ---- 3) COLORI PER KIND ----
	var kind_color := {
		"START": Color(0,1,0),
		"HUB": Color(1,0.85,0),
		"KEY_ROOM": Color(0.6,0.2,1),
		"CHALLENGE": Color(1,0.4,0.4),
		"ARENA": Color(1,0.6,0.2),
		"SIDE": Color(0.4,0.9,1),
		"SAVE": Color(0.4,1,0.6),
		"BOSS": Color(1,0,0)
	}

	# ---- 4) DISEGNA ARCHI ----
	for id in G.nodes.keys():
		for n in G.neighbors(id):
			if not node_positions.has(id): continue
			if not node_positions.has(n): continue
			draw_line(
				node_positions[id],
				node_positions[n],
				Color.WHITE,
				2.0
			)

	# ---- 5) DISEGNA NODI E NOMI ----
	var base_font := SystemFont.new()
	base_font.font_italic = true
	

	var debug_font := FontVariation.new()
	debug_font.base_font = base_font



	for id in G.nodes.keys():
		if not node_positions.has(id): continue
		var pos = node_positions[id]
		var kind = G.nodes[id].kind
		var col = kind_color.get(kind, Color(1,1,1))

		# cerchio nodo
		draw_circle(pos, radius, col)

		# background del testo per leggibilità
		var text := "%s (%s)" % [id, kind]
		var string_size := debug_font.get_string_size(text)

		var text_pos = pos + Vector2(-string_size.x/2, radius + 8)

		draw_rect(
			Rect2(text_pos - Vector2(4,4), string_size + Vector2(8,8)),
			Color(0,0,0,0.85),
			true
		)

		draw_string(
			debug_font,
			text_pos,
			text
		)

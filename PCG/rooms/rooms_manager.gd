## Modulo utilizzato per gestire ciò che deve accadere all'interno di una stanza.

extends Node
class_name RoomsManager

var rooms: Dictionary[RoomTemplateMeta, bool] = {}
var room_position: Dictionary[String, Vector2i] = {}
var position_room: Dictionary[Vector2i, String] = {}
var player: Player
var items_spawner: ItemsSpawner
var enemies_spawner: EnemiesSpawner
var G: MissionGraph
var run_level: int = 1

var door_scene : PackedScene = load("res://Scenes/Interactable/Door.tscn") as PackedScene

func _init(_G: MissionGraph, _rooms: Dictionary[RoomTemplateMeta, bool], _room_position: Dictionary[String, Vector2i], _player: Player, _run_level: int) -> void:
	G = _G
	rooms = _rooms
	room_position = _room_position
	player = _player
	run_level = _run_level
	items_spawner = ItemsSpawner.new()
	enemies_spawner = EnemiesSpawner.new()
	
	for k in room_position.keys():
		var value : Vector2i = room_position.get(k)
		position_room[value] = k

func _ready() -> void:
	for room in rooms: 
		
		room.player_entered.connect(_on_room_player_entered)
		room.player_exited.connect(_on_room_player_exited)
		
		## Aggiungo i nemici.
		_add_enemies(room)
		## Aggiungo le porte
		_add_doors(room)
		## Aggiungo gli oggetti
		_add_items(room)
		

func _process(delta: float) -> void:
	if player == null: return
	
	for room in rooms:
		#if rooms.get(room): continue
		room.update_player_presence(player)

## Funzione che gestisce gli eventi che devono accadere quando un giocatore 
## entra in una stanza [param room].
func _on_room_player_entered(room: RoomTemplateMeta) -> void:
	
	print("Player in room:", room.name, " node: ", room.logic_node.id)
	if rooms.get(room, false): return
	
	# Chiudo le porte
	for d in room.doors: d.try_close()
	
	# Inserisco i nemici
	
	# Inserisco spawno gli oggetti quando i nemici sono stati sconfitti
	
	
	
	#var spawn_points : Array[Vector2i] = room.item_spawn_points.duplicate()
	#var items : Dictionary[ItemRegistry.ID, int] = room.items
	#
	#if items.is_empty(): return
	#if spawn_points.is_empty(): return
	#
	#spawner.istanziate_in_position(spawn_points, items, room)
	
	rooms[room] = true

func _on_room_player_exited(room: RoomTemplateMeta) -> void:
	pass
	#rooms[room] = false

## Aggiunge ai varchi di una stanza [param room] le porte che bloccano 
## il passaggio alla stanza successiva.
func _add_doors(room: RoomTemplateMeta) -> void:
	var connectors: Dictionary[String, RoomConnector] = room.get_connectors()
	var rect: Rect2i = room.collision.get_used_rect()
	
	for k in connectors.keys():
		var conn : RoomConnector = connectors.get(k)
		
		# Calcolo i limiti della stanza
		var cell_pos : Vector2i = room.collision.local_to_map(conn.position)
		var cell_x : int = clampi(cell_pos.x, rect.position.x, rect.end.x - 1)
		var cell_y : int = clampi(cell_pos.y, rect.position.y, rect.end.y - 1)
		cell_pos = Vector2i(cell_x, cell_y)
		
		# Se trovi una cella in quel punto non bisonga aprire una porta
		if room.collision.get_cell_tile_data(cell_pos) != null: continue
		
		var x : int = conn.offset_left + conn.offset_right
		var y : int = conn.offset_up + conn.offset_down 
		var pos : Vector2 = room.center_to_top_left(cell_pos, x, y)
		var door : Door = door_scene.instantiate() as Door
		
		var lock_type: MissionGraph.LockType = _get_lock_type(room.logic_node.id, k)
		
		door.setup(room, x, y , pos, k, lock_type)
		room.add_child(door)
		
		## Aggiungi la porta alla lista di porte della stanza
		room.doors.append(door)
		## Se per qualsiasi motivo la porta viene eliminata dalla scena, viene eliminato anche il 
		## suo riferimento alla lista di porte.
		door.tree_exited.connect(func(): room.doors.erase(door))

	var t = G.neighbors(room.logic_node.id)

## Metodo privato che dato un nodo logico [param node] rappresentante la stanza fisicia e il tipo
## del connettore [param conn] restitusice usando il grafo [member G] il tipo di chiusura che avrà 
## quel varco.
func _get_lock_type(node: String, conn: String) -> MissionGraph.LockType:
	var dir: Vector2i = Vector2i.ZERO
	
	match conn:
		"N": dir = Vector2i.UP
		"S": dir = Vector2i.DOWN
		"E": dir = Vector2i.RIGHT
		"W": dir = Vector2i.LEFT
	
	var current_position: Vector2i = room_position.get(node)
	var adiacent_room: String = position_room.get(current_position + dir, "")
	
	return G.get_edge_lock(node, adiacent_room)

## Metodo privato utilizzato per aggiungere gli oggetti all'interno di una stanza [param room].
func _add_items(room: RoomTemplateMeta) -> void:
	## Carica il catalogo degli oggetti che la stanza conterrà.
	room.items = items_spawner.get_catalog(room.logic_node)
	if room.items.is_empty(): return
	
	## Carica le posizioi in cui gli oggetti verranno inseriti.
	room.item_spawn_points = items_spawner.get_spawn_points(room)
	if room.item_spawn_points.is_empty(): return
	
	items_spawner.istanziate_in_position(room.item_spawn_points, room.items, room)

func _add_enemies(room: RoomTemplateMeta)-> void:
	var budget: int = enemies_spawner._compute_budget(run_level, room)
	var room_diff: int = room.logic_node.diff
	
	var enemies: Array[EnemiesRegistry.ID] = enemies_spawner._chose_enemys(room_diff, run_level, budget)

	var wave: int = room.logic_node.enemy_directive.waves
	room.enemies_waves = enemies_spawner._build_wave_plan(budget, wave)
	if room.enemies_waves.is_empty(): return

	room.enemy_spawn_points = enemies_spawner._get_spawn_points(room, enemies.size())
	if room.enemy_spawn_points.is_empty(): return
	
	

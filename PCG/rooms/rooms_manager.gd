## Modulo utilizzato per gestire ciò che deve accadere all'interno di una stanza.

extends Node
class_name RoomsManager

var rooms: Dictionary[RoomTemplateMeta, RoomState] = {}
var room_position: Dictionary[String, Vector2i] = {}
var position_room: Dictionary[Vector2i, String] = {}
var player: Player
var items_spawner: ItemsSpawner
var enemies_spawner: EnemiesSpawner
var G: MissionGraph
var run_level: int = 1

var _combat_room: RoomTemplateMeta = null

var door_scene : PackedScene = load("res://Scenes/Interactable/Door.tscn") as PackedScene

func _init(_G: MissionGraph, _rooms: Dictionary[RoomTemplateMeta, RoomState], _room_position: Dictionary[String, Vector2i], _player: Player, _run_level: int) -> void:
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
	player.died.connect(_on_player_died)
	
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
		room.update_player_presence(player)

## Funzione che gestisce gli eventi che devono accadere quando un giocatore 
## entra in una stanza [param room].
func _on_room_player_entered(room: RoomTemplateMeta) -> void:
	print("Player in room:", room.name, " node: ", room.logic_node.id)
	var state : bool = rooms.get(room, RoomState.new()).done
	if state: return
	
	## Chiudo le porte
	for d in room.doors: 
		d.try_close()
		d.disable_interaction()
	
	## Inizia il combattimento
	_start_room_combat(room)
	
## Funzione che gestisce gli eventi che devono accadere quando un giocatore 
## esce da una stanza [param room].
func _on_room_player_exited(room: RoomTemplateMeta) -> void:
	pass

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
	var item_state: RoomItemState = rooms.get(room).items_state
	## Carica il catalogo degli oggetti che la stanza conterrà.
	var items: Dictionary[ItemRegistry.ID, int] = items_spawner.get_catalog(room.logic_node)
	if items.is_empty(): return
	
	## Carica le posizioi in cui gli oggetti verranno inseriti.
	var item_spawn_points : Array[Vector2i] = items_spawner.get_spawn_points(room)
	if item_spawn_points.is_empty(): return
	
	items_spawner.istanziate_in_position(item_spawn_points, items, room, item_state)
	item_state.items = items
	item_state.item_spawn_points = item_spawn_points
	item_state.spawned = true
	
## Metodo privato utilizzato per inserire i nemici all'interno di una stanza [param room]
func _add_enemies(room: RoomTemplateMeta)-> void:
	if room.logic_node.enemy_directive.combat_type == EnemyDirective.CombatType.NO_COMBAT: return
	
	var enemies_state: RoomEnemyState = rooms.get(room).enemies_state
	
	## Calcolo il budget della stanza
	var budget: int = enemies_spawner.compute_budget(run_level, room)
	var room_diff: int = room.logic_node.diff
	
	## Scelgo i nemici che devo istanziare 
	var enemies: Array[EnemiesRegistry.ID] = enemies_spawner.chose_enemys(room_diff, run_level, budget)
	if enemies.is_empty(): return 

	## Creo le eventuali ondate di nemici 
	var wave: int = room.logic_node.enemy_directive.waves
	var wave_plan: Array[int] = enemies_spawner.build_wave_plan(budget, wave)
	if wave_plan.is_empty(): return

	var spawn_points : Array[Vector2i] = enemies_spawner.get_spawn_points(room, enemies.size())
	if spawn_points.is_empty(): return
	
	enemies_spawner.istanziate_in_position(spawn_points, enemies, room, enemies_state)
	
	for enemy: EnemyEntity in enemies_state.enemies_references:
		enemy.died.connect(func(e: EnemyEntity) -> void:
				_on_enemy_died(room, enemies_state ,e)
		)
	
	enemies_state.queue = enemies
	enemies_state.wave_plan = wave_plan
	enemies_state.spawn_points = spawn_points
	enemies_state.prepared = true

## Metodo privato che fa inizare il combattimento all'interno della stanza [param room].
func _start_room_combat(room: RoomTemplateMeta) -> void:
	_combat_room = room
	var enemies_state: RoomEnemyState = rooms.get(room).enemies_state
	
	if !enemies_state.prepared: _add_enemies(room)
	
	var need_to_fight: bool = room.logic_node.enemy_directive.combat_type != EnemyDirective.CombatType.NO_COMBAT 
	var ther_is_enemies: bool = enemies_state.to_eliminate != 0
	
	if !need_to_fight or !ther_is_enemies: 
		for door in room.doors: 
			door.try_open()
			door.enable_interaction()
		return
	
	if enemies_state.started:
		for enemy: EnemyEntity in enemies_state.enemies_alive:
			enemy.show_entity()
		return
	
	enemies_state.started = true
	_spawn_wave(room, enemies_state)

## Metodo privato utilizzato per la gestione delle ondate di nemici all'interno della stanza [param room]
## sfruttando lo stato dei nemici nella stanza [param enemies_state]
func _spawn_wave(room: RoomTemplateMeta, enemies_state: RoomEnemyState) -> void:
	if enemies_state.wave_index not in range(enemies_state.wave_plan.size()): return
	
	var wave: int = enemies_state.wave_plan[enemies_state.wave_index]
	
	for e in range(wave):
		if enemies_state.enemy_index not in range(enemies_state.enemies_references.size()): return
		
		var enemy: EnemyEntity = enemies_state.enemies_references[enemies_state.enemy_index]
		enemies_state.enemies_alive.append(enemy)
		
		var free_slot: int = enemies_spawner.find_free_slot_index(enemies_state.spawn_points, enemies_state.enemies_alive)
		if free_slot == -1: break
		
		enemy.global_position = enemies_state.spawn_points[free_slot]
		enemy.show_entity()
		
		enemies_state.enemy_index += 1
	
	enemies_state.wave_index += 1
		
## Metodo privato utilizzato per gestire ciò che accande in una stanza [param room], quando un nemico
## [param enemy] viene sconfitto, aggiornado inoltre lo stato dei nemici nella stanza [param enemies_state].
func _on_enemy_died(room: RoomTemplateMeta, enemies_state: RoomEnemyState, enemy: EnemyEntity) -> void:
	if !enemies_state.enemies_alive.has(enemy): return
	
	enemies_state.enemies_alive.erase(enemy)
	enemies_state.to_eliminate -= 1
	
	if !enemies_state.enemies_alive.is_empty(): return
	if enemies_state.to_eliminate == 0: _end_combat(room)
		
	_spawn_wave(room, enemies_state)

## Metodo privato che avvia gli eventi che devono accadere quando i nemici in una stanza [param room]
## sono stati sconfitti.
func _end_combat(room: RoomTemplateMeta) -> void:
	## Stanza completata
	var room_state: RoomState = rooms.get(room)
	room_state.done = true
	
	## Apri le porte
	for door: Door in room.doors: 
		door.try_open()
		door.enable_interaction()
	
	## Spawna gli oggetti
	for item: ItemEntity in room_state.items_state.items_references: item.show_entity()
	
	_combat_room = null

## Metodo privato che gestice l'evento di quando un giocatore muore durante un combattimento.
func _on_player_died() -> void:
	if _combat_room == null: return 
	_reset_room(_combat_room)

## Metodo privato che gestice il reset dei nemici nella stanza [param room].
func _reset_room(room: RoomTemplateMeta) -> void:
	var enemies_state: RoomEnemyState = rooms.get(room).enemies_state
	for door: Door in room.doors: door.try_open()
	_reset_enemies(enemies_state)

## Metodo privsato che resetta lo stato dei nemici [param enemies_state].
func _reset_enemies(enemies_state: RoomEnemyState) -> void:
	enemies_state.wave_index = 0
	enemies_state.enemy_index = 0
	enemies_state.to_eliminate = enemies_state.enemies_references.size()
	enemies_state.enemies_alive.clear()
	enemies_state.started = false
	
	for enemy: EnemyEntity in enemies_state.enemies_references:
		enemy.reset()
		enemy.hide_entity()
	

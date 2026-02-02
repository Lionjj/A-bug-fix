# ============================================================================
# RoomsManager
# ============================================================================
## Modulo utilizzato per gestire ciò che deve accadere all'interno di una stanza.[br]
##
## Responsabilità principali:[br]
## - Collegare le stanze fisiche ([RoomTemplateMeta]) ai loro stati runtime ([RoomState]).[br]
## - Gestire gli eventi di ingresso/uscita del player (chiusura/apertura porte, avvio combattimento).[br]
## - Spawner centralizzati per: item, nemici, trappole, decorazioni.[br]
## - Gestione del combattimento a “stanza”: ondate, reset alla morte, fine stanza.[br]
##
## Note architetturali:[br]
## - Questo manager NON genera geometria: assume che la stanza sia già costruita e abbia:[br]
##   - [member RoomTemplateMeta.collision] (TileMapLayer collisione)[br]
##   - [member RoomTemplateMeta.placement] (RoomPlacementManager con cache candidate)[br]
##   - [member RoomTemplateMeta.logic_node] (MissionNode con direttive combat/trap/budget)[br]
## - Le “chiusure” delle porte dipendono dal grafo missioni ([MissionGraph]) e dal lock sugli edge.[br]
## - La stanza “in combattimento” corrente è tracciata in [member _combat_room].[br]
# ============================================================================

extends Node
class_name RoomsManager


# ---------------------------------------------------------------------------
# State / Mapping
# ---------------------------------------------------------------------------

## Mapping tra stanza fisica e suo stato runtime.
## - Key: [RoomTemplateMeta]
## - Value: [RoomState]
var rooms: Dictionary[RoomTemplateMeta, RoomState] = {}

## Mapping posizione logica (id nodo / nome stanza) -> coordinate griglia.
## - Key: String (id nodo logico o nome)
## - Value: [Vector2i]
var room_position: Dictionary[String, Vector2i] = {}

## Mapping inverso coordinate griglia -> id stanza (String).
## Usato per risalire alla stanza adiacente data una direzione (N/S/E/W).
var position_room: Dictionary[Vector2i, String] = {}

## Reference al player.
var player: Player

## Spawner runtime.
var items_spawner: ItemsSpawner
var enemies_spawner: EnemiesSpawner
var trap_spawner: TrapsSpawner
var deco_spawner: DecoSpawner

## Grafo missioni (lock porte, adiacenze, ecc.).
var G: MissionGraph

## Generatore randomico basato sul seed del livello.
var rng: RandomNumberGenerator

## Livello corrente della run (influenza budget e difficulty).
var run_level: int = 1


# ---------------------------------------------------------------------------
# Combat state
# ---------------------------------------------------------------------------

## Stanza attualmente in combattimento (se null -> nessun combattimento attivo).
var _combat_room: RoomTemplateMeta = null


# ---------------------------------------------------------------------------
# Scenes
# ---------------------------------------------------------------------------

## Scena della porta fisica.
var door_scene: PackedScene = load("res://Scenes/Interactable/Door.tscn") as PackedScene


# ---------------------------------------------------------------------------
# Init / Lifecycle
# ---------------------------------------------------------------------------

## Costruttore runtime.[br]
##
## [param _G] Grafo missioni (lock sugli edge, neighbors, ecc.).[br]
## [param _rooms] Dizionario stanze fisiche -> stato runtime.[br]
## [param _room_position] Mapping id stanza -> posizione griglia (per calcolo adiacenze).[br]
## [param _player] Reference al player (eventi died, presence update).[br]
## [param _run_level] Livello run corrente (influenza budget e difficulty).[br]
func _init(
	_rooms_context: RoomsManagerContext
) -> void:
	G = _rooms_context.graph
	rooms = _rooms_context.rooms
	room_position = _rooms_context.positions
	player = _rooms_context.player
	rng = _rooms_context.rng
	run_level = _rooms_context.run_level

	## Spawner locali (istanze per questo manager)
	items_spawner = ItemsSpawner.new()
	enemies_spawner = EnemiesSpawner.new()
	trap_spawner = TrapsSpawner.new()
	deco_spawner = DecoSpawner.new()

	## Costruisco mapping inverso posizione -> id stanza
	for k: String in room_position.keys():
		var value: Vector2i = room_position.get(k)
		position_room[value] = k


## Setup iniziale:[br]
## - collega segnali player/stanze[br]
## - popola contenuti iniziali (item/trap/nemici/porte/deco)[br]
func _ready() -> void:
	if player == null:
		return

	player.died.connect(_on_player_died)

	for room: RoomTemplateMeta in rooms:
		room.player_entered.connect(_on_room_player_entered)
		room.player_exited.connect(_on_room_player_exited)

		## Popola contenuti stanza (pre-bake)
		_add_items(room)
		_add_traps(room)
		_add_enemies(room)
		_add_doors(room)
		_add_decos(room)


## Update continuo: aggiorna la presenza player dentro le stanze.[br]
## Nota: room.update_player_presence() è responsabile di emettere entered/exited.[br]
##
## [param delta] Delta time (non usato direttamente qui).
func _process(delta: float) -> void:
	if player == null:
		return

	for room: RoomTemplateMeta in rooms:
		room.update_player_presence(player)


# ---------------------------------------------------------------------------
# Room events
# ---------------------------------------------------------------------------

## Gestisce l’evento di ingresso player in una stanza.[br]
## - se stanza già completata -> ignora[br]
## - altrimenti chiude porte e avvia combattimento[br]
##
## [param room] Stanza in cui il player è entrato.
func _on_room_player_entered(room: RoomTemplateMeta) -> void:
	## ============ DEBUG ============
	print("Player in room:", room.name, " node: ", room.logic_node.id)
	## ============ DEBUG ============

	var state_done: bool = rooms.get(room, RoomState.new()).done
	if state_done:
		return

	## Chiudo porte (guard-clause style: qui è “do”, perché è l’evento)
	for d: Door in room.doors:
		d.try_close()
		d.disable_interaction()

	_start_room_combat(room)


## Gestisce l’evento di uscita player dalla stanza.[br]
## Placeholder: puoi usarlo per spegnere luci/deactivate nemici ecc.[br]
##
## [param room] Stanza da cui il player è uscito.
func _on_room_player_exited(room: RoomTemplateMeta) -> void:
	pass


# ---------------------------------------------------------------------------
# Doors
# ---------------------------------------------------------------------------

## Aggiunge le porte sui connettori della stanza.[br]
## - calcola cella connettore (clamp su used_rect)[br]
## - se lì c’è un tile solido -> niente porta[br]
## - altrimenti istanzia porta e setta lock_type da grafo[br]
##
## [param room] Stanza target in cui aggiungere le porte.
func _add_doors(room: RoomTemplateMeta) -> void:
	var connectors: Dictionary[String, RoomConnector] = room.get_connectors()
	var rect: Rect2i = room.collision.get_used_rect()

	for k: String in connectors.keys():
		var conn: RoomConnector = connectors.get(k)

		## Calcolo cella in cui cade il connettore
		var cell_pos: Vector2i = room.collision.local_to_map(conn.position)
		cell_pos.x = clampi(cell_pos.x, rect.position.x, rect.end.x - 1)
		cell_pos.y = clampi(cell_pos.y, rect.position.y, rect.end.y - 1)

		## Se trovi un tile lì -> non serve aprire una porta
		if room.collision.get_cell_tile_data(cell_pos) != null:
			continue

		var x: int = conn.offset_left + conn.offset_right
		var y: int = conn.offset_up + conn.offset_down
		var pos: Vector2 = room.center_to_top_left(cell_pos, x, y)

		var door: Door = door_scene.instantiate() as Door
		var lock_type: MissionGraph.LockType = _get_lock_type(room.logic_node.id, k)

		door.setup(room, x, y, pos, k, lock_type)
		room.add_child(door)

		room.doors.append(door)
		door.tree_exited.connect(func() -> void:
			room.doors.erase(door)
		)

	## (debug/unused)
	var _t = G.neighbors(room.logic_node.id)


## Restituisce il tipo di lock da applicare a una porta, usando il grafo.[br]
## - converte “N/S/E/W” in una direzione[br]
## - trova stanza adiacente via [member room_position] e [member position_room][br]
## - chiede al grafo il lock sull’edge (node -> adjacent)[br]
##
## [param node] ID del nodo logico della stanza corrente.[br]
## [param conn] Stringa direzione del connettore ("N","S","E","W").[br]
##
## @return Tipo di lock sull'edge verso la stanza adiacente.
func _get_lock_type(node: String, conn: String) -> MissionGraph.LockType:
	var dir: Vector2i = Vector2i.ZERO

	match conn:
		"N": dir = Vector2i.UP
		"S": dir = Vector2i.DOWN
		"E": dir = Vector2i.RIGHT
		"W": dir = Vector2i.LEFT

	var current_position: Vector2i = room_position.get(node)
	var adjacent_room: String = position_room.get(current_position + dir, "")

	return G.get_edge_lock(node, adjacent_room)


# ---------------------------------------------------------------------------
# Content population (items / enemies / traps / decos)
# ---------------------------------------------------------------------------

## Aggiunge gli item alla stanza.[br]
## - legge catalogo dal nodo logico[br]
## - calcola spawn points “belli”[br]
## - istanzia rispettando blocchi/distanze (via RoomPlacementManager in ItemsSpawner)[br]
##
## [param room] Stanza target.
func _add_items(room: RoomTemplateMeta) -> void:
	var item_state: RoomItemState = rooms.get(room).items_state

	var items: Dictionary[ItemRegistry.ID, int] = items_spawner.get_catalog(room.logic_node, rng)
	if items.is_empty():
		return

	var item_spawn_points: Array[Vector2i] = items_spawner.get_spawn_points(room, rng)
	if item_spawn_points.is_empty():
		return

	items_spawner.istanziate_in_position(item_spawn_points, items, room, item_state, rng)

	item_state.items = items
	item_state.item_spawn_points = item_spawn_points
	item_state.spawned = true


## Aggiunge i nemici alla stanza (prepara lista e posizioni).[br]
## - rispetta directive NO_COMBAT[br]
## - calcola budget e lista nemici via pesi[br]
## - calcola wave plan e spawn points[br]
## - istanzia e connette died -> _on_enemy_died[br]
##
## [param room] Stanza target.
func _add_enemies(room: RoomTemplateMeta) -> void:
	if room.logic_node.enemy_directive.combat_type == EnemyDirective.CombatType.NO_COMBAT:
		return

	var enemies_state: RoomEnemyState = rooms.get(room).enemies_state

	var budget: int = enemies_spawner.compute_budget(run_level, room)
	var room_diff: int = room.logic_node.diff

	var enemies: Array[EnemiesRegistry.ID] = enemies_spawner.chose_enemys(room_diff, run_level, budget, rng)
	if enemies.is_empty():
		return

	var waves: int = room.logic_node.enemy_directive.waves
	var wave_plan: Array[int] = enemies_spawner.build_wave_plan(budget, waves)
	if wave_plan.is_empty():
		return

	var spawn_points: Array[Vector2i] = enemies_spawner.get_spawn_points(room, rng, enemies.size())
	if spawn_points.is_empty():
		return

	enemies_spawner.istanziate_in_position(spawn_points, enemies, room, enemies_state, rng)

	for enemy: EnemyEntity in enemies_state.enemies_references:
		enemy.died.connect(func(e: EnemyEntity) -> void:
			_on_enemy_died(room, enemies_state, e)
		)

	enemies_state.queue = enemies
	enemies_state.wave_plan = wave_plan
	enemies_state.spawn_points = spawn_points
	enemies_state.prepared = true


## Aggiunge le trappole alla stanza.[br]
## - rispetta directive NO_TRAPS[br]
## - calcola budget e lista trappole via pesi[br]
## - calcola spawn points rispettando policy anti soft-lock (jump height)[br]
##
## [param room] Stanza target.
func _add_traps(room: RoomTemplateMeta) -> void:
	if room.logic_node.trap_directive.trap_type == TrapDirective.TrapType.NO_TRAPS:
		return

	var trap_state: RoomTrapState = rooms.get(room).traps_state

	var budget: int = trap_spawner.compute_budget(run_level, room)
	var room_diff: int = room.logic_node.diff

	var traps: Array[TrapRegistry.ID] = trap_spawner.chose_traps(room_diff, run_level, budget, rng)
	if traps.is_empty():
		return

	var spawn_points: Array[Vector2i] = trap_spawner.get_spawn_points(room, traps.size(), player, rng)
	if spawn_points.is_empty():
		return

	trap_spawner.instantiate_in_position(spawn_points, traps, room, trap_state)

	trap_state.spawn_points = spawn_points
	trap_state.traps = traps
	trap_state.spawned = true


## Aggiunge decorazioni alla stanza, per ogni tipo (GROUND/WALL/CEILING). [br]
##
## [param room] Stanza target.
func _add_decos(room: RoomTemplateMeta) -> void:
	var deco_state: RoomDecoState = rooms.get(room).decos_state

	## TODO: Spegnere luci quando il player esce per ottimizzare performance
	for type in Decoration.DECO_TYPE.values():
		deco_spawner.spawn_room_decos(room, deco_state, type, rng)


# ---------------------------------------------------------------------------
# Combat flow
# ---------------------------------------------------------------------------

## Avvia il combattimento nella stanza.[br]
## - chiude porte già fatto in entered[br]
## - se non serve combattere o non ci sono nemici -> riapre porte e fine[br]
## - se già started -> mostra nemici vivi e fine[br]
## - altrimenti start + spawn prima ondata[br]
##
## [param room] Stanza in cui avviare il combattimento.
func _start_room_combat(room: RoomTemplateMeta) -> void:
	_combat_room = room
	var enemies_state: RoomEnemyState = rooms.get(room).enemies_state

	if not enemies_state.prepared:
		_add_enemies(room)

	var need_to_fight: bool = room.logic_node.enemy_directive.combat_type != EnemyDirective.CombatType.NO_COMBAT
	var there_are_enemies: bool = enemies_state.to_eliminate != 0

	if not need_to_fight or not there_are_enemies:
		for door: Door in room.doors:
			door.try_open()
			door.enable_interaction()
		return

	if enemies_state.started:
		for enemy: EnemyEntity in enemies_state.enemies_alive:
			enemy.show_entity()
		return

	enemies_state.started = true
	_spawn_wave(room, enemies_state)


## Spawna una ondata di nemici, aggiornando indici e lista alive.[br]
##
## [param room] Stanza target.[br]
## [param enemies_state] Stato runtime dei nemici nella stanza.
func _spawn_wave(room: RoomTemplateMeta, enemies_state: RoomEnemyState) -> void:
	if enemies_state.wave_index not in range(enemies_state.wave_plan.size()):
		return

	var wave_count: int = enemies_state.wave_plan[enemies_state.wave_index]

	for _i: int in range(wave_count):
		if enemies_state.enemy_index not in range(enemies_state.enemies_references.size()):
			return

		var enemy: EnemyEntity = enemies_state.enemies_references[enemies_state.enemy_index]
		enemies_state.enemies_alive.append(enemy)

		enemy.show_entity()
		enemies_state.enemy_index += 1

	enemies_state.wave_index += 1


## Callback quando un nemico muore in una stanza.[br]
## - rimuove da alive[br]
## - decrementa to_eliminate[br]
## - se non ci sono alive: o fine combattimento o next wave[br]
##
## [param room] Stanza target.[br]
## [param enemies_state] Stato runtime nemici.[br]
## [param enemy] Nemico morto.
func _on_enemy_died(room: RoomTemplateMeta, enemies_state: RoomEnemyState, enemy: EnemyEntity) -> void:
	if not enemies_state.enemies_alive.has(enemy):
		return

	enemies_state.enemies_alive.erase(enemy)
	enemies_state.to_eliminate -= 1

	if not enemies_state.enemies_alive.is_empty():
		return

	if enemies_state.to_eliminate == 0:
		_end_combat(room)
		return

	_spawn_wave(room, enemies_state)


## Termina il combattimento in stanza:[br]
## - marca stanza done[br]
## - apre porte e riabilita interazione[br]
## - mostra item già istanziati (se erano nascosti)[br]
##
## [param room] Stanza completata.
func _end_combat(room: RoomTemplateMeta) -> void:
	var room_state: RoomState = rooms.get(room)
	room_state.done = true

	for door: Door in room.doors:
		door.try_open()
		door.enable_interaction()

	for item: ItemEntity in room_state.items_state.items_references:
		item.show_entity()

	_combat_room = null


# ---------------------------------------------------------------------------
# Player death / Reset
# ---------------------------------------------------------------------------

## Callback quando il player muore.[br]
## Se c'è un combattimento attivo, resetta la stanza corrente.[br]
func _on_player_died() -> void:
	if _combat_room == null:
		return

	_reset_room(_combat_room)


## Resetta la stanza dopo la morte del player (solo combat state).[br]
## - apre porte[br]
## - resetta i nemici (posizione/HP/stati) e li nasconde[br]
##
## [param room] Stanza da resettare.
func _reset_room(room: RoomTemplateMeta) -> void:
	for door: Door in room.doors:
		door.try_open()

	var enemies_state: RoomEnemyState = rooms.get(room).enemies_state
	_reset_enemies(enemies_state)


## Resetta lo stato dei nemici in [param enemies_state].[br]
## - azzera indici wave/enemy[br]
## - ripristina to_eliminate[br]
## - svuota alive e started[br]
## - reset + hide di ogni EnemyEntity[br]
##
## [param enemies_state] Stato runtime nemici della stanza.
func _reset_enemies(enemies_state: RoomEnemyState) -> void:
	enemies_state.wave_index = 0
	enemies_state.enemy_index = 0
	enemies_state.to_eliminate = enemies_state.enemies_references.size()
	enemies_state.enemies_alive.clear()
	enemies_state.started = false

	for enemy: EnemyEntity in enemies_state.enemies_references:
		enemy.reset()
		enemy.hide_entity()

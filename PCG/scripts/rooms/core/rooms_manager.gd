# ============================================================================
# RoomsManager
# ============================================================================
## Manager runtime delle stanze: gestisce eventi player↔stanza e la logica[br]
## “a stanza” (porte, combattimento, popolamento contenuti, reset).[br]
##
## [b]Responsabilità principali[/b]:[br]
## - Collegare ogni [RoomTemplateMeta] al relativo [RoomState] runtime.[br]
## - Tenere aggiornato in tempo reale l’ingresso/uscita del player nelle stanze.[br]
## - Popolare le stanze con contenuti (item/nemici/trappole/decorazioni) tramite spawner dedicati.[br]
## - Gestire il combattimento a stanza (chiusura porte, ondate, completamento, reset su morte player).[br]
## - Istanziare porte fisiche sui connettori e applicare i lock usando i dati del [MissionGraph].[br]
##[br]
## [b]Cosa NON fa[/b]:[br]
## - Non genera geometria: assume stanze e corridoi già costruiti.[br]
## - Non decide topologia o adiacenze: usa il [MissionGraph] e la griglia di placement.[br]
## - Non implementa la scelta “artistica” dei punti spawn: delega a spawner e a [SmartPlacement].[br]
##[br]
## [b]Prerequisiti sulle stanze[/b]:[br]
## Ogni [RoomTemplateMeta] è atteso avere:[br]
## - [member RoomTemplateMeta.collision]: [TileMapLayer] collisione della stanza.[br]
## - [member RoomTemplateMeta.placement]: cache e utility placement (celle spawnabili, bounds, ecc.).[br]
## - [member RoomTemplateMeta.logic_node]: [MissionNode] con direttive (combat/trap/budget/diff). [br]
## - segnali: player_entered / player_exited emessi da [method RoomTemplateMeta.update_player_presence].[br]
##[br]
## [b]Note architetturali[/b]:[br]
## - Questo manager vive una volta per livello e riceve un [RoomsManagerContext] in _init.[br]
## - La “stanza in combattimento” corrente è tracciata in [member _combat_room].[br]
## - I lock porta dipendono dagli edge del [MissionGraph] (lock type sull’arco verso la stanza adiacente).[br]
# ============================================================================

extends Node
class_name RoomsManager


# ---------------------------------------------------------------------------
# State / Mapping
# ---------------------------------------------------------------------------

## Mapping stanza fisica → stato runtime.[br]
## Key: [RoomTemplateMeta][br]
## Value: [RoomState][br]
var rooms: Dictionary[RoomTemplateMeta, RoomState] = {}

## Mapping id nodo logico → posizione su griglia (celle).[br]
## Serve per determinare le stanze adiacenti quando si deve risalire dall’ID e da una direzione.[br]
var room_position: Dictionary[String, Vector2i] = {}

## Mapping inverso posizione su griglia → id nodo logico.[br]
## Lookup O(1) per “chi c’è in quella cella?” quando apri/locki una porta.[br]
var position_room: Dictionary[Vector2i, String] = {}

## Reference al player runtime.[br]
## Usato per: tracking presenza stanza, connessione a died, policy spawn trappole, ecc.[br]
var player: Player

## Spawner runtime per gli oggetti.[br]
var items_spawner: ItemsSpawner
## Spawner runtime per i nemici.[br]
var enemies_spawner: EnemiesSpawner
## Spawner runtime per le trappole.[br]
var trap_spawner: TrapsSpawner
## Spawner runtime per le decorazioni.[br]
var deco_spawner: DecoSpawner

## Grafo missioni: adiacenze logiche e lock sugli edge.[br]
var G: MissionGraph

## RNG coerente con il seed della run.[br]
var rng: RandomNumberGenerator

## Livello run/difficoltà corrente: influenza budget, scaling, scelte di spawn.[br]
var run_level: int = 1


# ---------------------------------------------------------------------------
# Combat state
# ---------------------------------------------------------------------------

## Stanza attualmente in combattimento.[br]
## Se null → nessun combattimento attivo.[br]
var _combat_room: RoomTemplateMeta = null


# ---------------------------------------------------------------------------
# Scenes
# ---------------------------------------------------------------------------

## Scena della porta fisica istanziata sui connettori delle stanze.[br]
## Se questa path cambia, le porte non verranno create.[br]
var door_scene: PackedScene = load("res://Scenes/Interactable/Door.tscn") as PackedScene


# ---------------------------------------------------------------------------
# Init / Lifecycle
# ---------------------------------------------------------------------------

## Costruttore runtime: aggancia il context e prepara mapping/spawner.[br]
##[br]
## [param _rooms_context]: contiene tutto ciò che serve al manager:[br]
## - [member RoomsManagerContext.graph] (grafo missioni)[br]
## - [member RoomsManagerContext.rooms] (mapping stanza→stato)[br]
## - [member RoomsManagerContext.positions] (id→pos griglia)[br]
## - [member RoomsManagerContext.player] (player runtime)[br]
## - [member RoomsManagerContext.rng] (rng run)[br]
## - [member RoomsManagerContext.run_level] (difficoltà run)[br]
func _init(_rooms_context: RoomsManagerContext) -> void:
	G = _rooms_context.graph
	rooms = _rooms_context.rooms
	room_position = _rooms_context.positions
	player = _rooms_context.player
	rng = _rooms_context.rng
	run_level = _rooms_context.run_level

	# Spawner locali (uno per manager/run)
	items_spawner = ItemsSpawner.new()
	enemies_spawner = EnemiesSpawner.new()
	trap_spawner = TrapsSpawner.new()
	deco_spawner = DecoSpawner.new()

	# Costruisco mapping inverso posizione → id stanza (lookup O(1))
	for k: String in room_position.keys():
		var value: Vector2i = room_position.get(k)
		position_room[value] = k


## Setup iniziale.[br]
## - Connette segnali del player e delle stanze.[br]
## - Popola i contenuti pre-bake (item/trap/nemici/porte/deco).[br]
func _ready() -> void:
	if player == null:
		return

	player.died.connect(_on_player_died)

	for room: RoomTemplateMeta in rooms:
		room.player_entered.connect(_on_room_player_entered)
		room.player_exited.connect(_on_room_player_exited)
		room.placement.init_from_room(room)

		# Popola contenuti stanza
		_add_items(room)
		_add_traps(room)
		_add_doors(room)
		_add_enemies(room)
		_add_decos(room)


## Loop runtime: aggiorna la presenza del player in ogni stanza.[br]
## Nota: [method RoomTemplateMeta.update_player_presence] decide entered/exited e li emette.[br]
##[br]
## [param delta]: delta time (qui non usato direttamente).[br]
func _process(delta: float) -> void:
	if player == null:
		return

	for room: RoomTemplateMeta in rooms:
		room.update_player_presence(player)


# ---------------------------------------------------------------------------
# Room events
# ---------------------------------------------------------------------------

## Evento: il player entra in una stanza.[br]
##[br]
## Comportamento:[br]
## - Se la stanza è già completata (RoomState.done) → non chiude porte e non avvia combat.[br]
## - Altrimenti: chiude tutte le porte presenti e avvia la pipeline di combattimento.[br]
##[br]
## [param room]: stanza in cui il player è entrato.[br]
func _on_room_player_entered(room: RoomTemplateMeta) -> void:
	# DEBUG: utile quando stai validando mapping tra stanza fisica e nodo logico
	print("Player in room:", room.name, " node: ", room.logic_node.id)

	var state_done: bool = rooms.get(room, RoomState.new()).done
	if state_done:
		return

	# Ingresso in stanza non completata → lock fisico immediato
	for d: Door in room.doors:
		d.try_close()
		d.disable_interaction()

	_start_room_combat(room)


## Evento: il player esce da una stanza.[br]
## Placeholder: puoi usarlo per ottimizzazioni (hide deco/luci, disattiva AI, ecc.).[br]
##[br]
## [param room]: stanza da cui il player è uscito.[br]
func _on_room_player_exited(room: RoomTemplateMeta) -> void:
	pass


# ---------------------------------------------------------------------------
# Doors
# ---------------------------------------------------------------------------

## Istanzia le porte fisiche sui connettori della stanza.[br]
##[br]
## Pipeline locale:[br]
## - Recupera i connettori via [method RoomTemplateMeta.get_connectors].[br]
## - Converte la posizione marker in cella tilemap.[br]
## - Se la cella contiene già un tile solido → non serve porta.[br]
## - Calcola dimensioni varco dai offset del [RoomConnector].[br]
## - Istanzia [Door], determina lock_type da grafo e chiama setup.[br]
##[br]
## [param room]: stanza target in cui aggiungere le porte.[br]
func _add_doors(room: RoomTemplateMeta) -> void:
	var connectors: Dictionary[String, RoomConnector] = room.get_connectors()
	var rect: Rect2i = room.collision.get_used_rect()

	for k: String in connectors.keys():
		var conn: RoomConnector = connectors.get(k)

		# Cella in cui cade il marker del connettore (clamp sul used_rect)
		var cell_pos: Vector2i = room.collision.local_to_map(conn.position)
		cell_pos.x = clampi(cell_pos.x, rect.position.x, rect.end.x - 1)
		cell_pos.y = clampi(cell_pos.y, rect.position.y, rect.end.y - 1)

		# Se lì c’è già geometria solida, non ha senso creare la porta/varco
		if room.collision.get_cell_tile_data(cell_pos) != null:
			continue

		# Dimensioni varco in tile: somma dei margini per lato
		var x: int = conn.offset_left + conn.offset_right
		var y: int = conn.offset_up + conn.offset_down

		# Posizione world del top-left del rettangolo varco calcolata dalla stanza
		var pos: Vector2 = room.center_to_top_left(cell_pos, x, y)

		var door: Door = door_scene.instantiate() as Door
		var lock_type: MissionGraph.LockType = _get_lock_type(room.logic_node.id, k)

		door.setup(room, x, y, pos, k, lock_type)
		room.add_child(door)

		room.doors.append(door)

		# Pulizia: se la porta esce dal tree, rimuovila dalla lista stanza
		door.tree_exited.connect(func() -> void:
			room.doors.erase(door)
		)

	# Debug/unused: comodo se vuoi loggare la topologia attorno alla stanza
	var _t = G.neighbors(room.logic_node.id)


## Determina il tipo di lock da applicare ad una porta usando i dati del grafo.[br]
##[br]
## Come funziona:[br]
## - Converte il connettore "N/E/S/W" in un offset grid.[br]
## - Risale alla cella adiacente e al suo id tramite:[br]
##   [member RoomsManager.room_position] + [member RoomsManager.position_room].[br]
## - Chiede al grafo il lock sull’arco (node → adjacent_room).[br]
##[br]
## [param node]: id del nodo logico della stanza corrente.[br]
## [param conn]: direzione connettore ("N","S","E","W").[br]
##[br]
## [return]: tipo di lock sull’edge verso la stanza adiacente.[br]
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

## Popola la stanza con item.[br]
##[br]
## Sequenza:[br]
## - Legge il catalogo item dal nodo logico tramite [ItemsSpawner].[br]
## - Calcola spawn points candidati (tipicamente via [SmartPlacement]).[br]
## - Istanzia rispettando blocchi/occupazione tramite logica dello spawner e state.[br]
## - Registra su [RoomItemState] ciò che è stato spawnato per debug e reset/telemetria.[br]
##[br]
## [param room]: stanza target.[br]
func _add_items(room: RoomTemplateMeta) -> void:
	var item_state: RoomItemState = rooms.get(room).items_state

	var items: Dictionary[ItemRegistry.ID, int] = items_spawner.get_catalog(room.logic_node, rng)
	if items.is_empty():
		return

	var item_spawn_points: Array[Vector2i] = items_spawner.get_spawn_points(room, rng)
	if item_spawn_points.is_empty():
		return

	items_spawner.istanziate_in_position(item_spawn_points, items, room, item_state, rng)
	
	for item: ItemEntity in item_state.items_references:
		item.hide_entity()

	item_state.items = items
	item_state.item_spawn_points = item_spawn_points
	item_state.spawned = true


## Prepara e istanzia i nemici per la stanza.[br]
##[br]
## Sequenza:[br]
## - Rispetta la direttiva [EnemyDirective.CombatType.NO_COMBAT].[br]
## - Calcola budget e lista nemici in base a diff/run tramite [EnemiesSpawner].[br]
## - Costruisce piano ondate (wave_plan) e punti spawn.[br]
## - Istanzia nemici e connette died → [method RoomsManager._on_enemy_died].[br]
## - Salva tutto in [RoomEnemyState] (prepared=true).[br]
##[br]
## [param room]: stanza target.[br]
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


## Popola la stanza con trappole.[br]
##[br]
## Sequenza:[br]
## - Rispetta la direttiva [TrapDirective.TrapType.NO_TRAPS].[br]
## - Calcola budget e lista trappole (pesi/diff/run).[br]
## - Calcola spawn points applicando una policy anti soft-lock (es. jump height del player).[br]
## - Istanzia e registra tutto in [RoomTrapState].[br]
##[br]
## [param room]: stanza target.[br]
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


## Popola la stanza con decorazioni per ogni tipo (GROUND/WALL/CEILING).[br]
##[br]
## Nota: qui si può agganciare ottimizzazione runtime (es. spegnere luci on exit).[br]
##[br]
## [param room]: stanza target.[br]
func _add_decos(room: RoomTemplateMeta) -> void:
	var deco_state: RoomDecoState = rooms.get(room).decos_state

	for type in Decoration.DECO_TYPE.values():
		deco_spawner.spawn_room_decos(room, deco_state, type, rng)


# ---------------------------------------------------------------------------
# Combat flow
# ---------------------------------------------------------------------------

## Avvia il combattimento della stanza.[br]
##[br]
## Regole:[br]
## - Se non serve combattere o non ci sono nemici: riapre porte e finisce.[br]
## - Se il combat è già started: mostra i nemici alive e non respawna.[br]
## - Altrimenti: marca started e spawna la prima ondata.[br]
##[br]
## [param room]: stanza in cui avviare il combattimento.[br]
func _start_room_combat(room: RoomTemplateMeta) -> void:
	_combat_room = room
	var enemies_state: RoomEnemyState = rooms.get(room).enemies_state

	# Lazy prepare: se non erano stati preparati in pre-bake (o erano vuoti), li prepara ora
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
##[br]
## [param room]: stanza target.[br]
## [param enemies_state]: stato runtime dei nemici nella stanza.[br]
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


## Callback: un nemico è morto.[br]
##[br]
## Effetti:[br]
## - rimuove il nemico da alive[br]
## - decrementa to_eliminate[br]
## - se alive è vuoto: o fine combat (to_eliminate==0) o spawn prossima wave[br]
##[br]
## [param room]: stanza target.[br]
## [param enemies_state]: stato runtime nemici.[br]
## [param enemy]: nemico morto.[br]
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


## Termina il combattimento di una stanza.[br]
##[br]
## Effetti:[br]
## - marca la stanza come completata (RoomState.done).[br]
## - apre porte e riabilita interazione.[br]
## - mostra gli item già istanziati (se venivano tenuti nascosti finché combat non finiva).[br]
##[br]
## [param room]: stanza completata.[br]
func _end_combat(room: RoomTemplateMeta) -> void:
	var room_state: RoomState = rooms.get(room)
	var mission_node: MissionNode = room.logic_node 
	room_state.done = true

	for door: Door in room.doors:
		door.try_open()
		door.enable_interaction()

	for item: ItemEntity in room_state.items_state.items_references:
		item.show_entity()
	
	for ability: int in mission_node.grants:
		print("abilità:", ability)
		player.record_ability(ability)

	_combat_room = null


# ---------------------------------------------------------------------------
# Player death / Reset
# ---------------------------------------------------------------------------

## Callback quando il player muore.[br]
## Se c’è un combattimento attivo, resetta la stanza corrente.[br]
func _on_player_died() -> void:
	if _combat_room == null:
		return

	_reset_room(_combat_room)


## Resetta la stanza dopo la morte del player (solo stato combat).[br]
##[br]
## Effetti:[br]
## - apre porte (non completa la stanza)[br]
## - resetta i nemici e li nasconde per ripartire “pulito” al re-entry[br]
##[br]
## [param room]: stanza da resettare.[br]
func _reset_room(room: RoomTemplateMeta) -> void:
	for door: Door in room.doors:
		door.try_open()

	var enemies_state: RoomEnemyState = rooms.get(room).enemies_state
	_reset_enemies(enemies_state)


## Resetta completamente lo stato dei nemici per una stanza.[br]
##[br]
## Effetti:[br]
## - azzera indici wave/enemy[br]
## - ripristina to_eliminate al totale dei nemici istanziati[br]
## - svuota alive e setta started=false[br]
## - chiama reset/hide su ogni [EnemyEntity][br]
##[br]
## [param enemies_state]: stato runtime nemici della stanza.[br]
func _reset_enemies(enemies_state: RoomEnemyState) -> void:
	enemies_state.reset()

	for enemy: EnemyEntity in enemies_state.enemies_references:
		enemy.reset()
		enemy.hide_entity()

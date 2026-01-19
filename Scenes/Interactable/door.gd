## Modulo utilizzato per genstire le porte che possono essere creati tra varchi
class_name Door extends StaticBody2D

@export var unlock_type: MissionGraph.LockType = MissionGraph.LockType.FREE

## Parte estetica della porta
@onready var color_rect: ColorRect = $ColorRect
## Parte fisica della porta
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
## Sprite utilizzato per mostrare il lucchetto quando [member unlock_type] è 
## [b]KEY[/b].
@onready var sprite_lock: Sprite2D = $Lock
## Utilizzato per avviare le animazioni di [member sprite_lock].
## Aimazioni: [b]"lock"[/b], [b]"unlock"[/b].
@onready var animation_player: AnimationPlayer = $AnimationPlayer
## Area di interazione per gestire l'apertura delle porte chiuse a chiave.
@onready var interaction_area: InteractionArea = $InteractionArea
## La forma dell'area di interazione.
@onready var interaction_shape: CollisionShape2D = $InteractionArea/InteractionShape


## Dimensione delle tile.
const TILE_SIZE : int = 16
## Largezza/altezza dell'area di interazione davanti alle porte.
const INTERACT_DIMENSION : int = 24
## Profondità interna dell'area di interazione davanti alla porta della stazna.
const INTERACT_DEPTH : int = 32

## Stabilisce se la porta è aperta o meno
var is_open: bool = false

## Dimesione orizzontale della porta (Numero di tile).
var tiles_x: int
## Dimensione verticale della porta (Numero di tile).
var tiles_y: int
## Posizione utilizzata per inserire la porta.
var pos: Vector2
## (OPZIONALE) Direzione in cui viene posizionata la porta nella stanza.
## Questo valore si rende necessario quando abbiamo una porta che richiede una chiave per essere aperta,
## ed è usato per calcoalre verso quale direzione interna viene posizionata l'area di interazione.
var cardinal: StringName
## TODO: Questo parametro serve per il cleared delle stanze che avverra dopo
var owner_room: RoomTemplateMeta


func setup(_owner_room: RoomTemplateMeta, _tiles_x:int, _tiles_y:int, _pos: Vector2, _cardinal: StringName = "N", _unlock_type: MissionGraph.LockType = MissionGraph.LockType.FREE) -> void:
	tiles_x = max(1, _tiles_x)
	tiles_y = max(1, _tiles_y)
	pos = _pos
	cardinal = _cardinal
	unlock_type = _unlock_type
	owner_room = _owner_room

func _ready() -> void:
	var size : Vector2 = compute_tiles()
	position = pos.snapped(Vector2(TILE_SIZE, TILE_SIZE))
	estetic_setup(size)
	physics_setup(size)
	
	## (opzionale) Questo metodo viene avviato solo se la porta è apribile da una chiave
	_door_locked_setup(size)
	
	try_open()

## Metodo pubblico usato per creare la dimensione estetica della porta in base 
## alla dimensione del varco, vedi [method compute_tiles].
## [param size_px] rappresenta la dimensione.
func estetic_setup(size_px: Vector2) -> void:
	var mat : ShaderMaterial = color_rect.get_material()
	
	mat = mat.duplicate(true) as ShaderMaterial
	color_rect.set_material(mat)

	color_rect.size = size_px
	color_rect.position = Vector2.ZERO

	# per la cornice e il falloff centrale
	mat.set_shader_parameter("gate_size", size_px)
	# per la ripetizione del pattern interno
	mat.set_shader_parameter("tiles", Vector2(tiles_x, tiles_y))

## Metodo pubblico usato per creare la dimensione fisica della porta in base 
## alla dimensione del varco vedi [method compute_tiles].
## [param size_px] rappresenta la dimensione.
func physics_setup(size_px: Vector2) -> void:
	var shape: RectangleShape2D = collision_shape_2d.get_shape()
	
	shape = shape.duplicate(true) as RectangleShape2D
	collision_shape_2d.set_shape(shape)
	
	shape.size = size_px
	collision_shape_2d.position = size_px /2


## Metodo privato usato per inizializzare l'area di interazione davanti alla porta.
## [param size_px] rappresenta la dimensione.
func _interaction_area_setup(size_px: Vector2) -> void:
	## binding con il metodo da chiamare quando il giocatore interagisce con l'area
	interaction_area.interact = Callable(self, "open_whit_key")
	
	## verifichiamo se la porta è verticale o orizziontale
	var is_vertical : bool = tiles_y > tiles_x
	## ricaviamo la direzione della porta
	var dir: Vector2 = _depth_dir_from_cardinal()
	## otteniamo la forma dell'interazione
	var rect: RectangleShape2D = RectangleShape2D.new()
	
	## impostiamo la dimensione della porta
	if is_vertical: rect.size = Vector2(INTERACT_DEPTH, size_px.y + INTERACT_DIMENSION)
	else: 			rect.size = Vector2(size_px.x + INTERACT_DEPTH, INTERACT_DIMENSION)
	
	## Offset: dal centro porta verso fuori (metà porta + metà depth)
	var half_door := size_px * 0.5
	var half_zone := rect.size * 0.5

	## Spingiamo SOLO sull'asse della direzione
	var offset := Vector2(
		dir.x * (half_door.x + half_zone.x),
		dir.y * (half_door.y + half_zone.y)
	)
	
	interaction_shape.set_shape(rect)
	interaction_area.position = half_door + offset
	interaction_shape.disabled = false

## Metodo privato per setuppare il lock estetico della porta.
## [param size_px] rappresenta la dimensione.
func _lock_setup(size_px: Vector2) -> void:
	sprite_lock.position = size_px * .5
	sprite_lock.visible = true
	animation_player.play("lock")

## Metodo privato usato per gestire le porte che richiedono una chiave per aprirsi.
## [param size_px] rappresenta la dimensione.
func _door_locked_setup(size_px: Vector2) -> void:
	if unlock_type != MissionGraph.LockType.KEY: return
	_interaction_area_setup(size_px)
	_lock_setup(size_px)
		
## Metodo privato che calcola la direzione interna dell'area di interazione usando [member cardinal].
func _depth_dir_from_cardinal() -> Vector2:
	match cardinal:
		"N": return Vector2.DOWN
		"S": return Vector2.UP
		"E": return Vector2.LEFT
		"W": return Vector2.RIGHT
	return Vector2.ZERO

## Metodo pubbplico utilizzato per "aprire" la porta.
func open() -> void:
	is_open = true
	
	# Disabilita la collsione con il giocatore
	collision_shape_2d.set_deferred("disabled", true)
	# Disabilita la parte estetica
	color_rect.visible = false

## Metodo pubbplico utilizzato per "aprire" la porta chiusa a chiave.
func open_whit_key() -> void:
	if !PlayerInventory.has_item(ItemRegistry.ID.KEY): return
	
	PlayerInventory.consume_item(ItemRegistry.ID.KEY)
	
	disable_interaction()
	animation_player.play("unlock")
	
	await animation_player.animation_finished
	sprite_lock.visible = false
	
	open()
	disable_interaction()

## Metodo pubblico usato per "chiudere" la porta.
func close() -> void:
	is_open = false
	
	# Abilita la collsione con il giocatore
	collision_shape_2d.set_deferred("disabled", false)
	# Abilita la parte estetica
	color_rect.visible = true

## Metodo pubblico usato per "chiudere" la porta a chiave.
func close_whit_key() -> void:
	enable_interaction()
	
	sprite_lock.visible = true
	animation_player.play("lock")
	close()

## Metodo pubblico usato aprire la porta con qualsiasi tipo di lucchetto.
func try_open() -> void:
	if is_open: return
	
	match unlock_type:
		MissionGraph.LockType.FREE: open() 
		MissionGraph.LockType.ENEMIES_CLEARED: open() 
		## TODO: Attualmente nel caso in cui si sta combattendo dei nemici in una stanza, al termne 
		## del combattimento la chiave, se presente viene consumata automaticamente
		MissionGraph.LockType.KEY: open_whit_key()

## Metodo pubblico usato chiudere la porta con qualsiasi tipo di lucchetto.
func try_close() -> void:
	if !is_open: return
	
	match unlock_type:
		#MissionGraph.LockType.FREE: close() 
		MissionGraph.LockType.ENEMIES_CLEARED: close()
		MissionGraph.LockType.KEY: close_whit_key()

## Metodo pubblico usato per calcolare la dimensione della porta in base al numero
## di tile del varco.
func compute_tiles() -> Vector2:
	return Vector2(
		tiles_x * TILE_SIZE,
		tiles_y * TILE_SIZE
		)

func disable_interaction() -> void:
	if unlock_type != MissionGraph.LockType.KEY: return
	interaction_area.monitoring = false
	interaction_area.monitorable = false
	interaction_shape.set_deferred("disabled", true)


func enable_interaction() -> void:
	if unlock_type != MissionGraph.LockType.KEY: return
	interaction_area.monitoring = true
	interaction_area.monitorable = true
	interaction_shape.set_deferred("disabled", false)

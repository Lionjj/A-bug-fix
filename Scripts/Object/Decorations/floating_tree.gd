extends DecorationEntity
class_name FloatingTree

@export var tree_kind: Array[Texture2D] = [
	
]

@export var flip_h: bool
@export var amplitude: float = 5.0
@export var speed: float = 0.5
@export var z_offset: int = 0  # opzionale: usato per stratificazione

var base_y: float

func _ready():
	super._ready()
	
	z_index = z_offset  # se vuoi forzare ordine Z
	z_as_relative = true
	
	if flip_h == true:
		sprite.flip_h = true

func _process(delta):
	var time = Time.get_ticks_msec() / 1000.0
	position.y = base_y + sin(time * speed * TAU) * amplitude

func pick_random() -> Texture2D:
	if tree_kind.is_empty(): return sprite.texture
	return tree_kind.pick_random()

func prepare_for_spawn() -> void:
	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null: return
	
	sprite.texture = pick_random()
	sprite.flip_h = flip_h
	
	spawn_offset = _compute_anchor_offset()
	footprint_cells = compute_footprint_cells()

func on_spawned() -> void:
	base_y = position.y

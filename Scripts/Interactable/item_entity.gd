## Modulo padre usato per gestire le istanzte degli oggetti.
## Vedi anche [class Item] rappresentate i dati logici degli item.
extends Area2D
class_name ItemEntity

@export var disable_collisions_on_hide : bool = true
@export var spawn_offset: Vector2 = Vector2.ZERO
@export var hide_on_ready: bool = true
@export var footprint_width_cells: int = 1

var sprite_2d_name: String = "Sprite2D"

func _ready() -> void:
	spawn_offset = _compute_anchor_offset()
	footprint_width_cells = compute_footprint_cells()
	hide_entity()

func show_entity() -> void:
	visible = true
	if disable_collisions_on_hide:
		_set_collision_enabled(true)
	set_process(true)
	set_physics_process(true)

func hide_entity() -> void:
	if !hide_on_ready: return
	
	visible = false
	if disable_collisions_on_hide:
		_set_collision_enabled(false)
	set_process(false)
	set_physics_process(false)

func _set_collision_enabled(enabled: bool) -> void:
	# Disabilita tutte le CollisionShape2D sotto questo pickup
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n : Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
			if ch is CollisionShape2D:
				(ch as CollisionShape2D).set_deferred("disabled", not enabled)

func _compute_anchor_offset() -> Vector2:
	var sprite: Sprite2D = get_node_or_null(sprite_2d_name)
	if sprite == null or sprite.texture == null:
		return Vector2.ZERO

	# Rect del disegno in coordinate locali del nodo Sprite2D
	var r: Rect2 = sprite.get_rect()

	# Applica la scala del nodo sprite (get_rect NON include scale)
	r.position *= sprite.scale
	r.size *= sprite.scale

	# r.position è l'angolo alto-sinistra del disegno
	# bottom_local = r.position.y + r.size.y
	# top_local = r.position.y

	var bottom_local := r.position.y + r.size.y
	return Vector2(0.0, -bottom_local)

func compute_footprint_cells(tile_size: Vector2i = Vector2i(16, 16)) -> int:
	var sprite: Sprite2D = get_node_or_null(sprite_2d_name)
	if sprite == null or sprite.texture == null:
		return 1

	var tile_w : float = float(tile_size.x)
	if tile_w <= 0.0:
		return 1

	# Rect del disegno in coordinate locali del nodo Sprite2D
	var r: Rect2 = sprite.get_rect()

	# get_rect non include scale: applicala
	var sx : float = abs(sprite.scale.x)
	r.position.x *= sx
	r.size.x *= sx

	# Larghezza reale in pixel
	var w_px : float = max(1.0, float(r.size.x))

	# celle richieste
	var cells : int = int(ceil(w_px / tile_w))

	# forza dispari (1,3,5...) per simmetria
	if cells % 2 == 0:
		cells += 1

	return max(1, cells)

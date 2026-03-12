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
	var sprite := get_node_or_null(sprite_2d_name) as Node2D
	if sprite == null:
		return Vector2.ZERO

	# Rect del disegno in locale dello sprite
	var local_rect: Rect2
	if sprite is Sprite2D:
		var s := sprite as Sprite2D
		if s.texture == null: return Vector2.ZERO
		local_rect = s.get_rect()
	elif sprite is AnimatedSprite2D:
		var a := sprite as AnimatedSprite2D
		if a.sprite_frames == null: return Vector2.ZERO
		local_rect = a.get_rect()
	else:
		return Vector2.ZERO

	# 4 angoli del rect (spazio locale sprite)
	var p0: Vector2 = local_rect.position
	var p1: Vector2 = local_rect.position + Vector2(local_rect.size.x, 0.0)
	var p2: Vector2 = local_rect.position + Vector2(0.0, local_rect.size.y)
	var p3: Vector2 = local_rect.position + local_rect.size

	# Converti in spazio LOCALE dell'ItemEntity (considera scale/offset/rotazioni di tutto)
	var q0: Vector2 = to_local(sprite.to_global(p0))
	var q1: Vector2 = to_local(sprite.to_global(p1))
	var q2: Vector2 = to_local(sprite.to_global(p2))
	var q3: Vector2 = to_local(sprite.to_global(p3))

	var max_y: float = max(q0.y, q1.y, q2.y, q3.y)

	# voglio che il bordo inferiore tocchi y=0
	return Vector2(0.0, -max_y)


func compute_footprint_cells(tile_size: Vector2i = Vector2i(16, 16)) -> int:
	var sprite := get_node_or_null(sprite_2d_name) as Node2D
	if sprite == null:
		return 1

	var local_rect: Rect2
	if sprite is Sprite2D:
		var s := sprite as Sprite2D
		if s.texture == null: return 1
		local_rect = s.get_rect()
	elif sprite is AnimatedSprite2D:
		var a := sprite as AnimatedSprite2D
		if a.sprite_frames == null: return 1
		local_rect = a.get_rect()
	else:
		return 1

	var p0: Vector2 = local_rect.position
	var p1: Vector2 = local_rect.position + Vector2(local_rect.size.x, 0.0)
	var p2: Vector2 = local_rect.position + Vector2(0.0, local_rect.size.y)
	var p3: Vector2 = local_rect.position + local_rect.size

	var q0: Vector2 = to_local(sprite.to_global(p0))
	var q1: Vector2 = to_local(sprite.to_global(p1))
	var q2: Vector2 = to_local(sprite.to_global(p2))
	var q3: Vector2 = to_local(sprite.to_global(p3))

	var min_x: float = min(q0.x, q1.x, q2.x, q3.x)
	var max_x: float = max(q0.x, q1.x, q2.x, q3.x)
	var width_px: float = max(1.0, max_x - min_x)

	var tile_w := float(tile_size.x)
	if tile_w <= 0.0:
		return 1

	var cells := int(ceil(width_px / tile_w))
	if cells % 2 == 0:
		cells += 1
	return max(1, cells)

func refresh_spawn_data() -> void:
	spawn_offset = _compute_anchor_offset()
	footprint_width_cells = compute_footprint_cells()

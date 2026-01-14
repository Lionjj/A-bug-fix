## Modulo padre usato per gestire le istanzte degli oggetti.
## Vedi anche [class Item] rappresentate i dati logici degli item.
extends Area2D
class_name ItemEntity

@export var disable_collisions_on_hide : bool = true

func _ready() -> void:
	hide_entity()

func show_entity() -> void:
	visible = true
	if disable_collisions_on_hide:
		_set_collision_enabled(true)
	set_process(true)
	set_physics_process(true)

func hide_entity() -> void:
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

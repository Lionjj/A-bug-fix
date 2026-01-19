extends CharacterBody2D
class_name EnemyEntity

signal died(enemy: EnemyEntity)

var _active: bool = true

func show_entity() -> void:
	_set_active(true)

func hide_entity() -> void:
	_set_active(false)

func is_active() -> bool:
	return _active

func _set_active(active: bool) -> void:
	_active = active

	visible = active
	set_process(active)
	set_physics_process(active)

	if not active:
		velocity = Vector2.ZERO

	_disable_collision(active)
	_disable_ai(active)
	_disable_sensors(active)
	_disable_animation(active)

	if active:
		_on_activated()
	else:
		_on_deactivated()

# --- hook: override nei figli ---
func _on_activated() -> void:
	pass

func _on_deactivated() -> void:
	pass

func reset() -> void:
	pass

# --- base generic helpers (come ti avevo scritto prima) ---
func _disable_collision(active: bool) -> void:
	var collider: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider != null:
		collider.set_deferred("disabled", not active)

func _disable_ai(active: bool) -> void:
	var sm: Node = get_node_or_null("StateMachine")
	if sm != null:
		sm.set_process(active)
		sm.set_physics_process(active)

func _disable_sensors(active: bool) -> void:
	pass

func _disable_animation(active: bool) -> void:
	var anim: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim != null:
		if active: anim.play()
		else: anim.stop()

func die() -> void:
	emit_signal("died", self)
	hide_entity()
	#queue_free()

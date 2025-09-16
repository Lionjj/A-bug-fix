extends CharacterBody2D

@export var damage :int

@export var speed: float = 300.0
@export var max_bounces: int = 3

var direction: Vector2 = Vector2.ZERO
var bounces: int = 0


func _ready():
	$BitWaveParticles.emitting = true
	set_collision_mask_value(1, false)
	await get_tree().create_timer(0.5).timeout
	set_collision_mask_value(1, true)
	await get_tree().create_timer(4.0).timeout
	queue_free()

		
func _physics_process(delta):
	var collision = move_and_collide(direction * speed * delta)
	
	if collision:
		# riflessione con la normale della collisione
		direction = direction.bounce(collision.get_normal()).normalized()
		bounces += 1
		
		if bounces >= max_bounces:
			queue_free()
			
			
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.take_damage(damage)
		queue_free()

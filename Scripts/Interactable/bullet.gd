extends Area2D

@export var amount: int = 1
@export var speed := 300.0
@export var direction : Vector2

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.take_damage(amount)
		CombatMechanic.hit_stop(.1, .3)

		queue_free()
	
	if body.is_in_group("Object"):
		
		queue_free()

func _physics_process(delta):
	position += direction * speed * delta

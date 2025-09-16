extends Node2D
@export var damage: int

@export var speed: float = 100.0
@export var direction: int = 1  # 1 = destra, -1 = sinistra

var can_check_ground := false

func _ready() -> void:
	scale.x = abs(scale.x) * direction
	$AnimationPlayer.play("attack")
	
	await get_tree().create_timer(0.3).timeout
	can_check_ground = true

func _physics_process(delta):
	
	position.x += direction * speed * delta
	
	if can_check_ground and not $RayCast2D.is_colliding():
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.take_damage(damage)

extends Area2D

@export var damage: int = 1

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if not body.get_invicible():
			CombatMechanic.applay_knockback(body, global_position, 1200, .08)
		body.take_damage(damage)
		
func _ready() -> void:
	var frames = $AnimatedSprite2D.sprite_frames.get_frame_count("default")
	$AnimatedSprite2D.set_frame_and_progress(randi() % frames, randf())

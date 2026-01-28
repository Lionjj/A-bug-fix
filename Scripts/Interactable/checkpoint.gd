extends ItemEntity
class_name Checkpoint
 
@export var spawnpoint: bool = false

var activated = false


func activate():
	GameManager.current_checkpoint = self
	activated = false
	$AnimationPlayer.play("activated")

func _on_area_entered(area: Area2D) -> void:
	if area.get_parent() is Player && !activated:
		activate()
		area.get_parent().glitch_flash()

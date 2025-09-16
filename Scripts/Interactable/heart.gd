extends Node2D
class_name InteracatbleHeart

@export var amount: int = 1     

func _on_area_2d_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent is Player && parent.heal(amount):
		$AudioStreamPlayer2D.play()
		queue_free()
	
		

extends Node2D
class_name InteracatbleHeart

@export var amount: int = 1     

func _on_area_2d_area_entered(area: Area2D) -> void:
	var paretn = area.get_parent()
	if paretn is Player && paretn.heal(amount):
		queue_free()
	
		

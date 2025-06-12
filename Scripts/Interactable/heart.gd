extends Node2D
class_name InteracatbleHeart
@onready var player = $"../Player"

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.get_parent() is Player and player.heal(1):
		self.queue_free()
		

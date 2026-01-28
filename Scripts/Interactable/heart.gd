extends ItemEntity
class_name InteracatbleHeart

@export var amount: int = 1    
@export var data: Item 
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent is Player && parent.heal(amount):
		audio_player.play()
		queue_free()

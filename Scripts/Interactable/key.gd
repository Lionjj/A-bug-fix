extends ItemEntity
class_name Key
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _on_body_entered(player: Player) -> void:
	var item : Item = Item.new(ItemRegistry.ID.KEY, self.name)
	PlayerInventory.add_item(item)
	audio_player.play()
	queue_free()

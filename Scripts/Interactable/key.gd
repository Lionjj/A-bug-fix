extends ItemEntity
class_name Key

func _on_body_entered(player: Player) -> void:
	var item : Item = Item.new(ItemRegistry.ID.KEY, self.name)
	PlayerInventory.add_item(item)
	queue_free()

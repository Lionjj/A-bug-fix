extends VisibleOnScreenNotifier2D
class_name DinamicNotifier

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func set_up(size_px: Vector2) -> void:
	rect.position = size_px / 2
	rect.size = size_px

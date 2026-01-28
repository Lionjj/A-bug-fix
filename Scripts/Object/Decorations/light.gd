extends DecorationEntity
@onready var notifier: DinamicNotifier = $VisibleOnScreenNotifier2D
@onready var sprite_2d: Sprite2D = $Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	notifier.set_up(sprite_2d.texture.get_size())
	notifier.screen_entered.connect(_on_enter)
	notifier.screen_exited.connect(_on_exit)
	pass # Replace with function body.


func _on_enter():
	active(true)
	
func _on_exit():
	active(false)
	
func active(value: bool) -> void:
	light_active(value)
	$Sprite2D.visible = value

func light_active(value: bool):
	$PointLight2D.visible = value
	$PointLight2D.enabled = value
	
	$PointLight2D2.visible = value
	$PointLight2D2.enabled = value
	
	$PointLight2D3.visible = value
	$PointLight2D3.enabled = value
	
	$PointLight2D4.visible = value
	$PointLight2D4.enabled = value

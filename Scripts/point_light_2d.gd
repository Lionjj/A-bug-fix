extends PointLight2D
class_name DinamicLight

#@export var on_distance: float = 600.0
#@export var off_distance: float = 700.0
#@export var check_interval: float = 0.25
#@onready var notifier: DinamicNotifier = $"../VisibleOnScreenNotifier2D"
#
## Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#notifier.screen_entered.connect(_on_enter())
	#notifier.screen_exited.connect(_on_exit())
	#activate(false)
#
#func _on_enter():
	#activate(true)
	#
#func _on_exit():
	#activate(false)
	#
#func activate(value: bool) -> void:
	#visible = value
	#enabled = value

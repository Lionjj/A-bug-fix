extends Node2D

@export var flip_h: bool
@export var amplitude: float = 5.0
@export var speed: float = 0.5
@export var z_offset: int = 0  # opzionale: usato per stratificazione
@onready var sprite = $Sprite2D

var base_y: float

func _ready():
	base_y = position.y
	z_index = z_offset  # se vuoi forzare ordine Z
	z_as_relative = true
	
	if flip_h == true:
		sprite.flip_h = true

func _process(delta):
	var time = Time.get_ticks_msec() / 1000.0
	position.y = base_y + sin(time * speed * TAU) * amplitude

extends Node2D

@export var speed: float = 10.0
@onready var sprite = $Sprite2D
var direction := 1  # 1 = destra, -1 = sinistra

@export var min_scale: float = 0.5
@export var max_scale: float = 1.5


func _ready():
	speed = randf_range(5.0, 20.0)
	direction = - 1 if randf() < 0.5 else 1
	sprite.flip_h = true if randf() < 0.5 else false
	var scale_value = randf_range(min_scale, max_scale)
	scale = Vector2(scale_value, scale_value)

func _process(delta: float):
	position.x += direction * speed * delta

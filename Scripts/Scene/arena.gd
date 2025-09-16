extends Node2D

@onready var player: Node2D = $Player

func _ready() -> void:
	player.movement_enabled = true

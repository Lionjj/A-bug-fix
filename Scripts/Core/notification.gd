extends MarginContainer

@onready var player_detector = $Area2D
@onready var anim_player = $AnimationPlayer
@export var actions: Array[String]
@export_multiline var text: String = ""

var shown := false

signal action_sender(action: Array[String], text: String)

func _ready():
	modulate.a = 0.0  # Trasparente, ma ancora attivo
	action_sender.emit(actions, text)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
		
	if shown:
		return
	
	shown = true
	anim_player.play("show")

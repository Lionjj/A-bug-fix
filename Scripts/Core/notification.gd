extends Panel

@onready var player_detector = $Area2D
@onready var anim_player = $AnimationPlayer


var shown := false

func _ready():

	modulate.a = 0.0  # Trasparente, ma ancora attivo
	player_detector.body_entered.connect(_on_player_entered)

func _on_player_entered(body):
	if shown:
		return

	if body.name == "Player":  # Assicurati che il nodo Player si chiami proprio "Player"
		shown = true
		anim_player.play("show")

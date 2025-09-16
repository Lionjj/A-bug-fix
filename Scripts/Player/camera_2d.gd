extends Camera2D

var shaking := false
var shake_strength := 0.0
var shake_decay := 0.0

func shake(strength: float = 8.0, decay: float = 5.0):
	shaking = true
	shake_strength = strength
	shake_decay = decay

func _process(delta):
	if shaking:
		# sposta leggermente la camera
		offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)

		# riduce progressivamente l’effetto
		shake_strength = max(shake_strength - shake_decay * delta, 0)

		# ferma lo shake quando è abbastanza debole
		if shake_strength <= 0.1:
			shaking = false
			offset = Vector2.ZERO

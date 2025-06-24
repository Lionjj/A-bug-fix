extends State
class_name PlayerSlide

@export var player: CharacterBody2D
@export var anim: AnimationPlayer
@export var wall_slide_speed := 30.0

func Enter():
	anim.play("slide")
	player.velocity.y = min(player.velocity.y, wall_slide_speed)

func Update(_delta: float):
	# Uscita dallo slide
	if player.is_on_floor():
		Transitioned.emit(self, "Idle")
	elif not _is_touching_wall():
		Transitioned.emit(self, "Fall")

	# Salto dal muro
	if Input.is_action_just_pressed("jump"):
		_wall_jump()
		Transitioned.emit(self, "Jump")

func Physics_Update(_delta: float):
	player.velocity.y = wall_slide_speed

# 🔁 Funzione privata per pulizia del codice
func _wall_jump():
	var dir = -player.direction  # ritorna -1 se a destra, +1 se a sinistra
	var jump_vector = Vector2(dir, -1).normalized() * player.jump_velocity
	player.disable_wall_check_temporarily()
	player.velocity = jump_vector

func _is_touching_wall() -> bool:
	return player.wall_check.is_colliding()

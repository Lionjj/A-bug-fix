extends State
class_name PlayerSlide

@export var player: CharacterBody2D
@export var anim: AnimationPlayer
@export var wall_slide_speed := 30.0
@export var wall_slide_speed_multiplayer := 10
var velocity_y = wall_slide_speed
const SPEED: int = 1200

func Enter():
	anim.play("slide")
	player.velocity.y = min(player.velocity.y, wall_slide_speed)
	velocity_y = wall_slide_speed

func Update(_delta: float):
	# Uscita dallo slide
	if player.is_on_floor():
		Transitioned.emit(self, "Idle")
	elif not _is_touching_wall():
		Transitioned.emit(self, "Fall")
		
	if player.direction == -1 and Input.is_action_pressed("ui_right"):
		player.disable_wall_check_temporarily()
		Transitioned.emit(self, "Fall")
	
	if player.direction == 1 and Input.is_action_pressed("ui_left"):
		player.disable_wall_check_temporarily()
		Transitioned.emit(self, "Fall")
		
	if Input.is_action_just_pressed("ui_down"):
		velocity_y = wall_slide_speed * wall_slide_speed_multiplayer
		
	if Input.is_action_just_released("ui_down") or player.is_on_floor():
		velocity_y = wall_slide_speed
		
	if Input.is_action_pressed("jump"):
		_wall_jump()
		Transitioned.emit(self, "Jump")

func Physics_Update(_delta: float):
	player.velocity.y = velocity_y

func _wall_jump():
	var dir = -player.direction  # ritorna -1 se a destra, +1 se a sinistra
	var jump_vector = Vector2(dir*SPEED, -player.jump_velocity).normalized()
	player.disable_wall_check_temporarily()
	player.velocity = jump_vector

func _is_touching_wall() -> bool:
	return player.wall_check.is_colliding()

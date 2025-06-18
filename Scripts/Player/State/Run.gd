extends State
class_name RunState

@export var player: CharacterBody2D
@export var animation : AnimationPlayer

func Enter():
	animation.play("run")
	player.velocity.y = 0


func Update(delta: float):
	if not (Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right")):
		Transitioned.emit(self, "Idle")  # Torna a Idle se non si muove

	if Input.is_action_just_pressed("jump"):
		player.jump_buffer_timer = player.jump_buffer_time

	# Jump buffer
	if Input.is_action_just_pressed("jump"):
		player.jump_buffer_timer = player.jump_buffer_time

	# Coyote time
	if player.is_on_floor():
		player.coyote_timer = player.coyote_time
	else:
		player.coyote_timer -= delta

	# Salto (condizione combinata)
	if player.coyote_timer > 0 and player.jump_buffer_timer > 0:
		player.coyote_timer = 0
		player.jump_buffer_timer = 0
		Transitioned.emit(self, "Jump")

	if not player.is_on_floor() and player.velocity.y >= 0:
		Transitioned.emit(self, "Fall")
	
	if Input.is_action_just_pressed("attack"):
		Transitioned.emit(self, "Combo1")
	
	if player.hit:
		Transitioned.emit(self, "Hit")

func Physics_Update(delta: float):
	var direction = Input.get_axis("ui_left", "ui_right")
	player.velocity.x = direction * player.speed
	
	animation.switch_direction(player.velocity)

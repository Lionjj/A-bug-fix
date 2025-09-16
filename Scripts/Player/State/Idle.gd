extends State
class_name IdleState

@export var player: CharacterBody2D
@export var speed: float = 200.0
@export var animation : AnimationPlayer


func Enter():
	player.velocity.x = 0
	player.velocity.y = 0
	animation.play("idle")

func Update(delta: float):
	
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		Transitioned.emit(self, "Run")
	
	if Input.is_action_just_pressed("attack"):
		pass
	
	if Input.is_action_just_pressed("jump"):
		player.jump_buffer_timer = player.jump_buffer_time
		Transitioned.emit(self, "Jump")
	
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
	
	if Input.is_action_just_pressed("dodge") and player.can_dodge:
		Transitioned.emit(self, "Dush")
	
	if Input.is_action_just_pressed("parry"):
		Transitioned.emit(self, "Parry")

func Physics_Update(_delta: float):
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		Transitioned.emit(self, "Run")
	
	player.switch_direction(player.velocity)
		

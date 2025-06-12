extends State
class_name FallState

@export var player: CharacterBody2D
@export var animation: AnimationPlayer

func Enter():
	pass

func Update(_delta):
	if player.is_on_floor():
		Transitioned.emit(self, "Idle")
		
	if Input.is_action_just_pressed("attack"):
		Transitioned.emit(self, "Combo1")
	
	if player.hit:
		Transitioned.emit(self, "Hit")

func Physics_Update(delta):
	# Movimento orizzontale in aria
	var direction = Input.get_axis("ui_left", "ui_right")
	player.velocity.x = direction * player.speed
	
	if not player.is_on_floor():
		if player.velocity.y > 0:
			player.velocity.y += player.gravity * (player.fall_multiplier - 1.0) * delta
		elif player.velocity.y < 0 and not Input.is_action_pressed("ui_accept"):
			player.velocity.y += player.gravity * (player.low_jump_multiplier - 1.0) * delta
		else:
			player.velocity.y += player.gravity * delta
	else:
		player.velocity.y = 0
	
	if player.position.y >= 600:
		Transitioned.emit(self, "Death")

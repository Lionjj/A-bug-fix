extends State
class_name JumpState

@export var player: CharacterBody2D
@export var animation : AnimationPlayer
@export var jump_velocity: float = -400.0


func Enter():
	player.velocity.y = jump_velocity
	animation.play("jump")
		
func Update(_delta):
	# Passa a Fall se inizia a cadere
	if player.velocity.y > 0:
		Transitioned.emit(self, "Fall")
	
	if Input.is_action_just_pressed("attack"):
		Transitioned.emit(self, "Combo1")
	
	if player.hit:
		Transitioned.emit(self, "Hit")

func Physics_Update(delta):
	# Movimento orizzontale in aria
	var direction = Input.get_axis("ui_left", "ui_right")
	player.velocity.x = direction * player.speed
	
	# Gestione opzionale: riduci salita se rilasciano il salto
	if player.velocity.y < 0 and not Input.is_action_pressed("jump"):
		player.velocity.y += player.gravity * (player.low_jump_multiplier - 1.0) * delta
	else:
		player.velocity.y += player.gravity * delta

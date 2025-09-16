extends State
class_name JumpState

@export var player: CharacterBody2D
@export var anim: AnimationPlayer


func Enter():
	player.velocity.y = player.jump_velocity
	anim.play("jump")
	GameManager.play_one_shot(player.audio["jump"], 1.0, 0.12, -2.0) 
		
func Update(_delta):
	# Passa a Fall se inizia a cadere
	if player.wall_check.is_colliding() and player.velocity.y > 0:
		Transitioned.emit(self, "Slide")
	
	if player.velocity.y > 0:
		Transitioned.emit(self, "Fall")
	
	if Input.is_action_just_pressed("attack"):
		Transitioned.emit(self, "Combo1")
	
	if player.hit:
		Transitioned.emit(self, "Hit")
	
	if Input.is_action_just_pressed("dodge") and player.can_dodge:
		Transitioned.emit(self, "Dush")

func Physics_Update(delta):
	# Movimento orizzontale in aria
	var direction = Input.get_axis("ui_left", "ui_right")
	player.velocity.x = direction * player.speed
	
	# Gestione opzionale: riduci salita se rilasciano il salto
	if player.velocity.y < 0 and not Input.is_action_pressed("jump"):
		player.velocity.y += player.gravity * (player.low_jump_multiplier - 1.0) * delta
	else:
		player.velocity.y += player.gravity * delta
	
	player.switch_direction(player.velocity)

extends State
class_name PlayerSlide

@export var player: Player
@export var anim: AnimationPlayer
@export var wall_slide_speed := 30.0
@export var wall_slide_speed_multiplayer := 10

@export var wall_jump_push := 1100.0    # spinta orizzontale lontano dal muro
@export var wall_jump_lock_time := 0.12  # piccolo lock input come Hollow Knight

var just_wall_jumped := false
var velocity_y = wall_slide_speed

func Enter():
	anim.play("slide")
	player.velocity.y = min(player.velocity.y, wall_slide_speed)
	velocity_y = wall_slide_speed
	just_wall_jumped = false


func Update(_delta: float):
	# Uscita dallo slide
	if player.is_on_floor():
		Transitioned.emit(self, "Idle")
	elif not _is_touching_wall():
		Transitioned.emit(self, "Fall")
		
	if player.direction == -1 and Input.is_action_pressed("ui_right"):
		player.disable_wall_check_temporarily()
		Transitioned.emit(self, "Fall")
	elif not _is_touching_wall():
		if player.wall_coyote_timer > 0.0: return
		Transitioned.emit(self, "Fall")
	
	if player.direction == 1 and Input.is_action_pressed("ui_left"):
		player.disable_wall_check_temporarily()
		Transitioned.emit(self, "Fall")
	elif not _is_touching_wall():
		if player.wall_coyote_timer > 0.0: return
		Transitioned.emit(self, "Fall")
		
	if Input.is_action_just_pressed("ui_down"):
		velocity_y = wall_slide_speed * wall_slide_speed_multiplayer
		
	if Input.is_action_just_released("ui_down") or player.is_on_floor():
		velocity_y = wall_slide_speed
		
	if Input.is_action_just_pressed("jump"):
		_do_wall_jump_from_coyote()
		Transitioned.emit(self, "Jump")

func Physics_Update(_delta: float):
	if just_wall_jumped: return 
	player.velocity.y = velocity_y
	

func _do_wall_jump_from_coyote():
	var away := -player.last_wall_dir
	if away == 0:
		away = -player.direction  # fallback

	just_wall_jumped = true

	player.disable_wall_check_temporarily()

	# flip e direzione
	player.direction = away
	player.switch_direction(Vector2(away, 0))

	# velocità
	player.reset_jumps()
	player.try_jump()

	# smoothing X
	player.velocity.x = away * wall_jump_push * .8
	player.start_wall_jump_smooth(away * wall_jump_push)

	player.wall_coyote_timer = 0.0



func _is_touching_wall() -> bool:
	return player.wall_check.is_colliding()

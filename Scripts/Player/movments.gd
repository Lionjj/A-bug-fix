# res://Scripts/Player.gd
extends CharacterBody2D
class_name  Player
# Velocità del movimento
@export var speed: float = 200.0
@export var jump_velocity: float = -400.0

@export var gravity_scale: float = 1.0
@export var fall_multiplier: float = 2.5
@export var low_jump_multiplier: float = 3.5

@export var coyote_time: float = 0.1  # In secondi
@export var jump_buffer_time: float = 0.1  # In secondi

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# Gravità
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var animation = $AnimationPlayer

func _physics_process(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed

	# Aggiorna coyote timer
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

	# Aggiorna jump buffer timer
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	# Miglioramento gravità
	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += gravity * (fall_multiplier - 1) * delta
		elif velocity.y < 0 and not Input.is_action_pressed("ui_accept"):
			velocity.y += gravity * (low_jump_multiplier - 1) * delta
		else:
			velocity.y += gravity * delta
	else:
		velocity.y = 0  # Quando sei sul pavimento, azzera la velocità verticale

	# Salto (con coyote time + jump buffer)
	if coyote_timer > 0 and jump_buffer_timer > 0:
		velocity.y = jump_velocity
		coyote_timer = 0  # Resettiamo coyote quando salti
		jump_buffer_timer = 0  # Resettiamo jump buffer quando salti
	
	animation.update_animation(is_on_floor(), velocity)
	move_and_slide()



#func _on_animated_sprite_2d_animation_finished() -> void:
	#if animation.animation == "attack":
		#$AttackArea2D/CollisionShape2D.disabled = true
		#animation.attacking = false

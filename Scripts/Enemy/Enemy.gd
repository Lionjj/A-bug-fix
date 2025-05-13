extends CharacterBody2D
class_name Enemy

var speed = 60
const MAX_HP = 3
var current_hp = 3

@export var gravity_scale: float = 1.0
@export var fall_multiplier: float = 2.5
@export var low_jump_multiplier: float = 3.5

var facing_right = true
var take_hit = false
var dead = false

@onready var anim = $AnimationPlayer

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready() -> void:
	anim.play("walk")
	current_hp = MAX_HP

func _physics_process(delta: float) -> void:
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
	
	if !$RayCast2D.is_colliding() && is_on_floor():
		flip()
	
	velocity.x = speed 
	move_and_slide()
	update_animation()

func flip():
	facing_right = !facing_right
	
	scale.x = abs(scale.x) * -1
	if facing_right:
		speed = abs(speed)
	else:
		speed = abs(speed) * -1

func update_animation():
	# Scegli animazione
	if !take_hit:
		if abs(velocity.x) > 0:
			anim.play("walk")
		else:
			anim.play("idle")

func _on_hitbox_area_entered(area: Area2D) -> void:
	pass


func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.get_parent() is Player && !dead:
#		area.get_parent().die()
		pass

func die():
	if current_hp == 0:
		speed = 0
		dead = true
		anim.play("die")
	else:
		take_hit = true
		anim.play("take_hit")
		await anim.animation_finished
		take_hit = false

func take_damage(damage: int):
	current_hp -= damage

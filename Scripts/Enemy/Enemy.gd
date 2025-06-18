extends CharacterBody2D
class_name Enemy


var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@export var gravity_scale: float = 1.0
@export var fall_multiplier: float = 2.5
@export var low_jump_multiplier: float = 3.5
@onready var healt_container = $HealtContainer.get_children()

# Vita del nemico
@export var max_hp = 3
var current_hp = 3

var hit = false
var dead = false
var texture_0: CompressedTexture2D

# Direzione del nnemico
var direction

signal damaged_player(player: Player)

func _ready() -> void:
	texture_0 = preload("res://Assets/OS/Enemies/0.png")
	current_hp = max_hp
	direction = 1.0

func _physics_process(delta: float) -> void:
	move_and_slide()
	applay_gravity(delta)


func _on_hitbox_area_entered(area: Area2D) -> void:
	pass


func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.get_parent() is Player && !dead:
#		area.get_parent().die()
		pass

func applay_gravity(delta):
		# Gravità
	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += gravity * (fall_multiplier - 1.0) * delta
		elif velocity.y < 0:
			velocity.y += gravity * (low_jump_multiplier - 1.0) * delta
		else:
			velocity.y += gravity * delta
	else:
		velocity.y = 0

func take_damage(damage: int):
	if dead:
		return
	
	healt_container[current_hp - 1].texture = texture_0
	
	current_hp -= damage
	hit = true
	

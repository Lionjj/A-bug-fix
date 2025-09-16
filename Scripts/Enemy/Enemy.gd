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

# Direzione del nemico
var direction

var knockback:Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0

var player: CharacterBody2D

var is_following = false

func _ready() -> void:
	if $Bit0Particles.process_material:
		$Bit0Particles.process_material = $Bit0Particles.process_material.duplicate()

	texture_0 = preload("res://Assets/OS/Enemies/0.png")
	player = get_player()
	current_hp = max_hp
	direction = 1.0
	
	GameManager.increment_enemy()

func _physics_process(delta: float) -> void:
	if knockback_timer > 0.0:
		velocity = knockback
		knockback_timer -= delta
		
		knockback = knockback.lerp(Vector2.ZERO, 0.2)
		
		if knockback_timer <= 0.0:
			knockback = Vector2.ZERO
			velocity = Vector2.ZERO
			
	move_and_slide()
	applay_gravity(delta)

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
	
	var index = max(0, current_hp - 1)
	healt_container[index].texture = texture_0
	
	current_hp -= damage
	hit = true

func get_player() -> CharacterBody2D:
	if player == null:
		player = get_tree().get_first_node_in_group("Player")
	return player

func activate_hitbit():
	$Bit0Particles.visible = true
	$Bit0Particles.emitting = false
	$Bit0Particles.restart()
	$Bit0Particles.emitting = true


func deactivate_hitbit():
	$Bit0Particles.visible = false
	$Bit0Particles.emitting = false
	$Bit0Particles.restart()

func set_knockback(knockback):
	self.knockback = knockback

func set_knockback_timer(time):
	self.knockback_timer = time

func set_following(is_following : bool) -> void:
	self.is_following = is_following

func get_following() -> bool:
	return self.is_following 

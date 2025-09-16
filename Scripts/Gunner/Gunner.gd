extends CharacterBody2D

class_name Gunner

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@export var is_weapon_loaded = true
@export var gravity_scale: float = 1.0
@export var fall_multiplier: float = 2.5
@export var low_jump_multiplier: float = 3.5
@onready var healt_container = $HealtContainer.get_children()
@onready var gun_point = $GunPoint


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

func _ready() -> void:
	player = get_player()
	texture_0 = preload("res://Assets/OS/Enemies/0.png")
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
	
	applay_gravity(delta)
	move_and_slide()
	
	
	if player != null:
		if player.global_position.x < global_position.x:
			direction = -1.0
		else:
			direction = 1.0

		$Sprite2D.flip_h = direction == -1
		$GunPoint.look_at(player.global_position)
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

func get_player() -> CharacterBody2D:
	if player == null:
		player = get_tree().get_first_node_in_group("Player")
	return player

func take_damage(damage: int):
	if dead:
		return
	
	healt_container[current_hp - 1].texture = texture_0
	
	current_hp -= damage
	hit = true

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

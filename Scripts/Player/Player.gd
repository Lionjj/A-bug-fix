# res://Scripts/Player.gd
extends CharacterBody2D
class_name  Player
# Velocità del movimento
@export var speed: float = 200.0

@export var gravity_scale: float = 1.0
@export var fall_multiplier: float = 2.5
@export var low_jump_multiplier: float = 3.5

@export var jump_buffer_time: float = 0.1  # In secondi
@export var jump_velocity: float = -400.0
@export var coyote_time: float = 0.1  # In secondi

var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0
var direction := 1
@onready var attack_area = $AttackArea
@onready var wall_check = $WallCheck
@onready var wall_check_timer = $WallCheckTimer
# Gravità
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var animation = $AnimationPlayer
@onready var state_machine = $StateMachinePlayer
@onready var hud = $HudPlayer
@onready var sprite = $Sprite2D
@onready var shader = sprite.material
@onready var background = $Camera2D/Sprite2D

@export var movement_enabled = false
@export var max_hp = 3
var current_hp

var dead = false
var hit = false

var can_dodge = true
var invincible: bool = false

func _ready() -> void:
	GameManager.player = self
	current_hp = max_hp
	disable_glitch()
	background.visible = true
	movement_enabled = false
	wall_check.enabled = false

func _physics_process(delta):
	if movement_enabled:
		move_and_slide()

func switch_direction(velocity: Vector2):
	if velocity.x != 0:
		direction = sign(velocity.x)
		sprite.flip_h = direction < 0
		sprite.position.x = direction * 4
		attack_area.scale.x = direction
		wall_check.scale.x = direction
		
func take_damage(damage: int):
	if dead || invincible:
		return
	
	current_hp -= damage
	hit = true
	
func heal(amount: int) -> bool:
	var cured = current_hp < max_hp
	if cured:
		current_hp += amount
		hud.gain_heart()
	return cured

func enable_glitch():
	shader.set_shader_parameter("glitch_intensity", 3.0)

func disable_glitch():
	shader.set_shader_parameter("glitch_intensity", 0.0)

func glitch_flash(duration := 0.5):
	enable_glitch()
	await get_tree().create_timer(duration).timeout
	disable_glitch()

func leanding():
	animation.play("jump")
	wall_check.enabled = true

func disable_wall_check_temporarily():
	wall_check.enabled = false
	wall_check_timer.start()


func _on_wall_check_timer_timeout() -> void:
	wall_check.enabled = true

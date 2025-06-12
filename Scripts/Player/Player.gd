# res://Scripts/Player.gd
extends CharacterBody2D
class_name  Player
# Velocità del movimento
@export var speed: float = 200.0

@export var gravity_scale: float = 1.0
@export var fall_multiplier: float = 2.5
@export var low_jump_multiplier: float = 3.5

@export var jump_buffer_time: float = 0.1  # In secondi
@export var coyote_time: float = 0.1  # In secondi
@export var sprite: Sprite2D

var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0
var direction := 1
@onready var attack_area = $AttackArea
# Gravità
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var animation = $AnimationPlayer
@onready var state_machine = $StateMachinePlayer
@onready var hud = $HudPlayer

@export var max_hp = 3
var current_hp

var dead = false
var hit = false

func _ready() -> void:
	GameManager.player = self
	current_hp = max_hp

func _physics_process(delta):
	move_and_slide()

func switch_direction(velocity: Vector2):
	if velocity.x != 0:
		direction = sign(velocity.x)
		sprite.flip_h = direction < 0
		sprite.position.x = direction * 4
		attack_area.scale.x = direction
		
func take_damage(damage: int):
	if dead:
		return
	
	current_hp -= damage
	hit = true
	
func heal(amount: int) -> bool:
	var cured = current_hp < max_hp
	if cured:
		current_hp += amount
		hud.gain_heart()
	return cured

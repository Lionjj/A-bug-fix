# res://Scripts/Player.gd
extends CharacterBody2D
class_name  Player

# Gravità
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# ----------- Nodes -----------
@onready var animation = $AnimationPlayer
@onready var state_machine = $StateMachinePlayer
@onready var hud = $HudPlayer
@onready var sprite = $Sprite2D
@onready var attack_area = $AttackArea
@onready var parry_area = $ParryArea
@onready var wall_check = $WallCheck
@onready var wall_check_timer = $WallCheckTimer
@onready var shader = sprite.material

# ----------- SFX -----------
@export var audio: Dictionary[StringName, AudioStream]

# ----------- Stats -----------
@export var damage : int
@export var max_hp = 3
@export var speed: float = 200.0
@export var invulnerability_duration := 0.8
@export var gravity_scale: float = 1.0
@export var fall_multiplier: float = 2.5
@export var low_jump_multiplier: float = 3.5
@export var jump_buffer_time: float = 0.1  # In secondi
@export var jump_velocity: float = -400.0
@export var coyote_time: float = 0.1  # In secondi

var knockback:Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var current_hp
var jump_buffer_timer = 0.0

# ----------- Movments -----------
@export var movement_enabled: bool
var coyote_timer: float = 0.0
var direction := 1
var attacks ={
	"light" : 1,
	"heavy" : 2,
	"parry" : 3,
}

# ----------- States -----------
@export var invincible: bool = false
@export var wall_check_enabled: bool
var dead = false
var hit = false
var can_dodge = true
var enemy_hit = false

func _ready() -> void:
	GameManager.player = self
	current_hp = max_hp
	disable_glitch()
	wall_check.enabled = wall_check_enabled
	

func _physics_process(delta):
	if knockback_timer > 0.0:
		set_process_input(false)
		velocity = knockback
		knockback_timer -= delta
		
		knockback = knockback.lerp(Vector2.ZERO, 0.2)
		
		if knockback_timer <= 0.0:
			knockback = Vector2.ZERO
			velocity = Vector2.ZERO
			set_process_input(true)
		
		
	move_and_slide()
	
func switch_direction(velocity: Vector2):
	if velocity.x != 0:
		direction = sign(velocity.x)
		sprite.flip_h = direction < 0
		sprite.position.x = direction * 4
		attack_area.scale.x = direction
		wall_check.scale.x = direction
		parry_area.scale.x = direction
		
func take_damage(damage: int):
	if dead || invincible:
		return
	
	current_hp -= damage
	hit = true
	start_invulnerability()
	
func heal(amount: int) -> bool:
	var cured = current_hp < max_hp
	if cured:
		GameManager.play_one_shot(audio["heal"], 1.0, 0.12, -2.0) 
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

func disable_wall_check_temporarily(time = .2):
	wall_check.enabled = false
	wall_check_timer.start(time)

func _on_wall_check_timer_timeout() -> void:
	wall_check.enabled = true

func start_invulnerability(blinck: bool = true):
	invincible = true
	var flash_timer := Timer.new()
	flash_timer.wait_time = invulnerability_duration
	flash_timer.one_shot = true
	flash_timer.connect("timeout", _on_invulnerability_end)
	add_child(flash_timer)
	flash_timer.start()
	
	# Effetto lampeggiante
	if blinck:
		blink_during_invulnerability()

func _on_invulnerability_end():
	invincible = false
	$Sprite2D.visible = true

func blink_during_invulnerability():
	var blink_timer := Timer.new()
	blink_timer.wait_time = 0.1
	blink_timer.one_shot = false
	blink_timer.connect("timeout", func():
		$Sprite2D.visible = not $Sprite2D.visible
	)
	add_child(blink_timer)
	blink_timer.start()
	
	await get_tree().create_timer(invulnerability_duration).timeout
	blink_timer.stop()
	blink_timer.queue_free()
	$Sprite2D.visible = true

func call_hit_stop():
	pass

func set_knockback(knockback):
	self.knockback = knockback

func set_knockback_timer(time):
	self.knockback_timer = time

func get_invicible() -> bool:
	return invincible

func set_invicible(invicible: bool) -> void:
	self.invincible = invicible

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Enemies"):
		body.take_damage(damage)
		CombatMechanic.hit_stop(.1, .2)
		CombatMechanic.applay_knockback(body, global_position, 600, .08)

func set_damage(type: String) -> void:
	self.damage = attacks[type]

func set_objective(text: String) -> void:
	$HudPlayer.set_objective(text)

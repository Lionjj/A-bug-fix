extends State
class_name PlayerCombo1

@export var player: CharacterBody2D
@export var animation_player: AnimationPlayer
@export var attack_area: Area2D

@export var suspend_gravity_factor: float = 0.3
@export var allow_air_movement := true
@export var allow_jump_movement := true
@export var attacking := false



var direction := 1

func Enter():
	if player.velocity.y < 0:
		player.velocity.y *= 0.2  # o 0.1 → smorza la salita
	
	var attack_id = player.set_damage("light")
	attacking = true
	
	emit_signal("attack_windup", Time.get_ticks_msec()/1000.0, attack_id)
	animation_player.play("attack1")
	GameManager.play_one_shot(player.audio["attack1"], 1.0, 0.12, -2.0) 
	await animation_player.animation_finished
	emit_signal("attack_swing", attack_id)
	
	attacking = false
	Transitioned.emit(self, "Idle")

func Update(_delta):
	pass  # Nessun input durante l'attacco

func Physics_Update(delta):
	# Movimento orizzontale facoltativo durante l’attacco
	if allow_air_movement:
		var dir = Input.get_axis("ui_left", "ui_right")
		player.velocity.x = dir * player.speed

	# Gravità sospesa (più leggera del normale)
	if not player.is_on_floor():
		player.velocity.y += player.gravity * suspend_gravity_factor * delta
	else:
		player.velocity.y = 0

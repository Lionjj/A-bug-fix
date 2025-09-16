extends State
class_name PlayerDush
@export var player: CharacterBody2D
@export var animation_player: AnimationPlayer
@export var hitbox_area: Area2D

# ---- dash tuning ----
@export var dash_distance: float = 170.0         # quanti px coprire
@export var dash_duration: float = 0.22          # quanto dura il dash
@export var dash_cooldown: float = 0.6           # ricarica
@export var i_frames: float = 0.25               # invincibilità

# curva opzionale (0..1 -> 0..1). Se nulla, uso cubic ease-out
@export var dash_curve: Curve

# opzionale: fermati subito se sbatti contro un muro
@export var stop_on_wall := true

var _dashing := false
var _dir_x := 1
var _timer := 0.0
var _speed_max := 0.0

func Enter() -> void:
	# Direzione SOLO orizzontale
	var input_x := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	if input_x != 0.0:
		_dir_x = sign(input_x)
	elif "direction" in player and typeof(player.direction) == TYPE_INT and player.direction != 0:
		_dir_x = sign(player.direction)
	else:
		_dir_x = -1 if player.scale.x < 0.0 else 1  # fallback: facing

	# invincibilità + blocco retrigger
	player.invincible = true
	hitbox_area.set_deferred("monitoring", false)
	player.can_dodge = false

	# animazione
	if animation_player:
		animation_player.play("dush") # o "dash" se hai rinominato
		GameManager.play_one_shot(player.audio["dush"], 1.0, 0.12, -2.0) 

	# setup dash
	_timer = dash_duration
	_dashing = true
	_speed_max = dash_distance / dash_duration

	# opzionale: reset Y per muoversi SOLO su X
	player.velocity.y = 0.0

	# fine invincibilità
	get_tree().create_timer(i_frames).timeout.connect(func():
		player.invincible = false
		hitbox_area.monitoring = true
	)

func _sample_curve(t: float) -> float:
	# t in [0,1] -> fattore velocità in [0,1]
	if dash_curve:
		return dash_curve.sample(clamp(t, 0.0, 1.0))
	# cubic ease-out: partenza molto veloce, poi decresce
	return 1.0 - pow(1.0 - clamp(t, 0.0, 1.0), 3.0)

func Physics_Update(delta: float) -> void:
	if not _dashing:
		return

	_timer -= delta
	var progress = 1.0 - max(_timer, 0.0) / dash_duration  # 0 -> 1
	var speed := _speed_max * _sample_curve(progress)

	# SOLO asse X
	player.velocity.x = _dir_x * speed
	player.velocity.y = 0.0

	# interrompi se sbatti su muro
	if stop_on_wall and player.is_on_wall():
		_finish_dash()
		return

	if _timer <= 0.0:
		_finish_dash()

func _finish_dash() -> void:
	_dashing = false
	player.velocity = Vector2.ZERO
	Transitioned.emit(self, "idle")  # torna allo stato idle

func Exit() -> void:
	# riparti il cooldown
	get_tree().create_timer(dash_cooldown).timeout.connect(func():
		player.can_dodge = true
	)

func Update(_delta):
	if Input.is_action_just_pressed("attack"):
		Transitioned.emit(self, "Combo3")

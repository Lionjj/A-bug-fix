extends State
class_name PlayerRoll

@export var player: CharacterBody2D
@export var animation_player: AnimationPlayer
@export var hitbox_area: Area2D

@export var dodge_distance: float = 150.0
@export var dodge_duration: float = 0.4
@export var dodge_cooldown: float = 1.0
@export var dodge_invincibility_time: float = 0.45

var is_dodging = false
var dodge_direction = Vector2.ZERO
var dodge_timer := 0.0

func Enter():
	# Imposta direzione sicura
	if player.velocity.length() > 0:
		dodge_direction = player.velocity.normalized()
	elif typeof(player.direction) == TYPE_INT:
		dodge_direction = Vector2(player.direction, 0).normalized()
	else:
		dodge_direction = Vector2.RIGHT  # fallback

	# Imposta invincibilità
	player.invincible = true
	hitbox_area.set_deferred("monitoring", false)

	# Blocca la possibilità di schivare di nuovo
	player.can_dodge = false

	# Avvia animazione e movimento
	animation_player.play("roll")
	dodge_timer = dodge_duration
	is_dodging = true

	# Timer per fine invincibilità
	var inv_timer = get_tree().create_timer(dodge_invincibility_time)
	inv_timer.timeout.connect(_on_invincibility_end)

func _on_invincibility_end():
	player.invincible = false
	hitbox_area.monitoring = true

func Physics_Update(delta: float):
	if is_dodging:
		dodge_timer -= delta
		player.velocity = dodge_direction * (dodge_distance / dodge_duration)

		if dodge_timer <= 0:
			is_dodging = false
			player.velocity = Vector2.ZERO
			Transitioned.emit(self, "idle")

func Exit():
	player.velocity = Vector2.ZERO

	var cd_timer = get_tree().create_timer(dodge_cooldown)
	cd_timer.timeout.connect(_on_dodge_cooldown_end)

func _on_dodge_cooldown_end():
	player.can_dodge = true

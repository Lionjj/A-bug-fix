extends State
class_name PlayerCombo1

@export var player: CharacterBody2D
@export var animation_player: AnimationPlayer
@export var attack_area: Area2D

@export var suspend_gravity_factor: float = 0.3
@export var allow_air_movement := true
@export var allow_jump_movement := true
@export var attacking := false
@export var damage := 1

var direction := 1

func Enter():
	if player.velocity.y < 0:
		player.velocity.y *= 0.2  # o 0.1 → smorza la salita
	
	attacking = true
	animation_player.play("attack1")
	await get_tree().process_frame
	check_attack_hits()
	await animation_player.animation_finished
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

func check_attack_hits():
	var overlapping = attack_area.get_overlapping_areas()
	for area in overlapping:
		if area.get_parent().is_in_group("Enemies"):
			area.get_parent().take_damage(damage)

extends State
class_name GunnerIdle

@export var enemy: CharacterBody2D
@export var anim: AnimationPlayer
@export var shoot_range := 200.0
@export var shoot_cooldown := 1.5

var timer := 0.0
var player: CharacterBody2D

func Enter():
	timer = 0.0
	anim.play("idle")
	player = enemy.get_player()
	
func Update(delta):

	if enemy.hit:
		Transitioned.emit(self, "Hit")

func Physics_Update(delta):
	timer += delta
	if player == null:
		return
	
	var direction = player.global_position - enemy.global_position
	direction.y = 0

	if direction.length() <= shoot_range && timer >= shoot_cooldown:
		Transitioned.emit(self, "Shoot")
		return  # evita altri transition inutili

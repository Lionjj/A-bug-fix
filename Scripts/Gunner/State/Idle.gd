extends State
class_name GunnerIdle

@export var enemy: CharacterBody2D
@export var anim: AnimationPlayer
@export var shoot_range := 100.0
@export var shoot_cooldown := .2

var player_in_sight = false

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
	
	if player_in_sight and timer >= shoot_cooldown:
		timer = 0.0
		Transitioned.emit(self, "Shoot")
		return
	

func _on_sight_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_sight = true
		return  # evita altri transition inutili

func _on_sight_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_sight = false
		return  # evita altri transition inutili

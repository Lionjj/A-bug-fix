extends State
class_name Parry

@export var player: CharacterBody2D
@export var speed: float = 200.0
@export var animation : AnimationPlayer
var parried = false

var enemy: CharacterBody2D

func Enter():
	parried = false
	player.velocity = Vector2.ZERO
	animation.play("parry")
	GameManager.play_one_shot(player.audio["parry"], 1.0, 0.12, -2.0) 
	await animation.animation_finished
	
	if not parried or player.hit:
		Transitioned.emit(self, "Idle")
	
	Transitioned.emit(self, "Combo2")

func Update(delta: float):
	pass
	
func Physics_Update(_delta: float):
	pass
		
func _on_parry_area_area_entered(area: Area2D) -> void:
	parried = area.is_in_group("Parriable")
	if not parried or player.hit:
		player.set_invicible(false)
		animation.play("parry_no_hit")
		await animation.animation_finished
		return
		
	player.set_invicible(true)
	animation.play("parry_hit")
	await animation.animation_finished
	player.set_invicible(false)
	
	enemy = area.get_parent()
	
	CombatMechanic.hit_stop(.1, .2)
	CombatMechanic.applay_knockback(enemy, player.global_position, 800, .08)
	
	
	
	
	

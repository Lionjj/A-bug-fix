extends State
class_name PlayerHit

@export var player: CharacterBody2D
@export var anim: AnimationPlayer
@export var hud: CanvasLayer

func Enter():
	player.velocity = Vector2.ZERO
	anim.play("hit")
	GameManager.play_one_shot(player.audio["hit"], 1.0, 0.12, -2.0) 
	await anim.animation_finished
	
	hud.lose_heart()
	player.hit = false
	
	if player.current_hp <= 0:
		Transitioned.emit(self, "Death")
	else:
		Transitioned.emit(self, "Idle")

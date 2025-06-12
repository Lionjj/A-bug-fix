extends State
class_name PlayerDeath

@export var player: CharacterBody2D
@export var anim: AnimationPlayer
@export var hud: CanvasLayer

func Enter():
	player.dead = true
	anim.play("die")
	await anim.animation_finished
	player.dead = false
	player.current_hp = player.max_hp
	hud.reset_heart()
	GameManager.respawn_player()
	Transitioned.emit(self, "Idle")

	

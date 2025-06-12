extends State
class_name PlayerHeal

@export var player: CharacterBody2D
@export var anim: AnimationPlayer
@export var hud: CanvasLayer

func Enter():
	if player.current_hp >= player.max_hp:
		heal()

func heal(count: int):
	for i in count:
		hud.gain_heart()
		player.current_hp += 1

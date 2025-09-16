extends State
class_name Stun

@export var enemy: CharacterBody2D
@export var anim: AnimationPlayer
@export var stun_duration: float = .5 # secondi

func Enter():
	enemy.velocity = Vector2.ZERO
	anim.play("stun")
	await anim.animation_finished
	
	await get_tree().create_timer(stun_duration).timeout
	
	Transitioned.emit(self,"Walk")

func Update(delta: float):
	if enemy.hit:
		Transitioned.emit(self,"Hit")

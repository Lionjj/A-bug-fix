extends State
class_name EnemyHit

@export var enemy: CharacterBody2D
@export var anim: AnimationPlayer

func Enter():
	enemy.velocity.x = 0
	anim.play("hit")
	await anim.animation_finished
	enemy.hit = false
	
	if enemy.current_hp <= 0:
		Transitioned.emit(self, "Death")
	else:
		Transitioned.emit(self, "Idle")

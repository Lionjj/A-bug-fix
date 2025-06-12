extends State
class_name EnemyDeath

@export var enemy: CharacterBody2D
@export var anim: AnimationPlayer

func Enter():
	enemy.dead = true
	enemy.velocity = Vector2.ZERO
	anim.play("die")
	await anim.animation_finished
	enemy.queue_free()

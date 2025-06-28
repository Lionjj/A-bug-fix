extends State
class_name EnemyDeath

@export var enemy: CharacterBody2D
@export var anim: AnimationPlayer

var bit_fx = preload("res://Scenes/Object/BitParticle.tscn")

func Enter():
	enemy.dead = true
	enemy.velocity = Vector2.ZERO
	
	var bits = bit_fx.instantiate()
	bits.global_position = enemy.global_position
	get_tree().current_scene.add_child(bits)

#	anim.play("die")
#	await anim.animation_finished

	enemy.queue_free()

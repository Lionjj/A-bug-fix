extends State
class_name EnemyHit

@export var enemy: CharacterBody2D
@export var anim: AnimationPlayer

var bit_fx = preload("res://Scenes/Object/HitBitParticle.tscn")

func Enter():
	enemy.velocity.x = 0
	anim.play("hit")
	if enemy.has_method("activate_hitbit"): enemy.activate_hitbit()
	await anim.animation_finished
	enemy.hit = false
	
	if enemy.has_method("deactivate_hitbit"): enemy.deactivate_hitbit()
	
	if enemy.current_hp <= 0:
		Transitioned.emit(self, "Death")
	else:
		if enemy is Enemy:
			Transitioned.emit(self, "Follow")
		Transitioned.emit(self, "Idle")

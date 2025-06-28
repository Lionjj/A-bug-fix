extends State
class_name  ChangeDirection

@export var enemy: CharacterBody2D

func flip():
	#var direction = 1 if enemy.velocity.x > 0 else -1
	enemy.direction = enemy.direction * -1.0
	enemy.scale.x = abs(enemy.scale.x) * -1.0
		

func Enter():
	flip()
	await get_tree().create_timer(0.01).timeout
	if enemy.hit:
		return
	Transitioned.emit(self, "Idle")

func Update(delta):
	if enemy.current_hp <= 0:
		Transitioned.emit(self, "Death")

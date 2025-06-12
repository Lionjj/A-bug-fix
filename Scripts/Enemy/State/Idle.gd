extends State
class_name EnemyIdle

@export var enemy: CharacterBody2D
@export var anim: AnimationPlayer


var timer := 0.0

func Enter():
	anim.play("idle")
	
func Update(delta):
	Transitioned.emit(self, "Walk")
	
	if enemy.hit:
		Transitioned.emit(self, "Hit")

func Physics_Update(delta):
	pass
#	gravity(delta)
	

#func gravity(delta):
		# Gravità
	#if not enemy.is_on_floor():
		#if enemy.velocity.y > 0:
			#enemy.velocity.y += enemy.gravity * (enemy.fall_multiplier - 1.0) * delta
		#elif enemy.velocity.y < 0:
			#enemy.velocity.y += enemy.gravity * (enemy.low_jump_multiplier - 1.0) * delta
		#else:
			#enemy.velocity.y += enemy.gravity * delta
	#else:
		#enemy.velocity.y = 0

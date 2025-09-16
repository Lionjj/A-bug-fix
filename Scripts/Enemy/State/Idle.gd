extends State
class_name EnemyIdle

@export var enemy: CharacterBody2D
@export var anim: AnimationPlayer


var timer := 0.0

func Enter():
	anim.play("idle")
	$"../../AttackArea2D/CollisionShape2D".disabled = true
	
func Update(delta):
	Transitioned.emit(self, "Walk")
	
	if enemy.hit:
		Transitioned.emit(self, "Hit")
	
	if enemy.current_hp <= 0:
		Transitioned.emit(self, "Death")
	

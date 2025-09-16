extends State
class_name ChooseBossAttack

@export var boss: CharacterBody2D
var last_position: Vector2

func Enter():
	last_position = boss.global_position
	Transitioned.emit(self, "Idle")
	#if last_position.y < 200:
		#Transitioned.emit(self, "ScanAttack")  # strisce verticali/orizzontali
	#elif last_position.x < 300:
		#Transitioned.emit(self, "BitExplosion")
	#elif last_position.y > 300:
		#Transitioned.emit(self, "GroundSlam")
	#else:
		#Transitioned.emit(self, "WaveAttack")

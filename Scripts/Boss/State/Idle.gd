extends State
class_name BossIdle

@export var boss: CharacterBody2D
@export var nav_agent: NavigationAgent2D
@export var threshold := 5.0

var timer := 0.0
var update_interval := .5  # ogni quanto aggiornare la posizione


func Enter():
	await get_tree().create_timer(update_interval).timeout
	boss.target_point = boss.find_closest_point_to_player()
	
	if boss.target_point == null:
		return
	
	nav_agent.target_position = boss.target_point.global_position
	
	#nav_agent.set_target_position(target_point.global_position)

func Update(delta):
	if boss.target_point == null:
		return
	
	if boss.hit:
		Transitioned.emit(self, "Hit")
	
	if boss.global_position.distance_to(boss.target_point.global_position) < threshold:
		boss.velocity = Vector2.ZERO
		Transitioned.emit(self, boss.chose_attack())


func Physics_Update(delta: float):
	if boss.target_point:
		var dir = (boss.target_point.global_position - boss.global_position).normalized()
		boss.velocity = dir * 400.0

extends State
class_name  EnemyFollow

@export var enemy: CharacterBody2D
@export var move_speed := 60

var player: CharacterBody2D


func Enter():
	player = get_tree().get_first_node_in_group("Player")
	
func Update(delta):
	if enemy.hit:
		Transitioned.emit(self, "Hit")
	
	if enemy.current_hp <= 0:
		Transitioned.emit(self, "Death")

	
func Physics_Update(delta):
	if player == null: 
		return
	
	var direction = player.global_position - enemy.global_position
	direction.y = 0
	
	var velocity_x = direction.normalized().x * move_speed if abs(direction.x) > 25 else 0

	if enemy.direction != direction.normalized().x:
		Transitioned.emit(self, "ChangeDirection")
	
	enemy.velocity.x = velocity_x
	
	if direction.length() > 50:
		Transitioned.emit(self, "Walk")
	
	if direction.length() <= 50:
		Transitioned.emit(self, "Attack")

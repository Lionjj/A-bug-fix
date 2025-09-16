extends State
class_name  EnemyFollow

@export var enemy: CharacterBody2D
@export var ray_ground: RayCast2D
@export var move_speed := 60
@export var follow_duration := 5.0

var player: CharacterBody2D
var follow_timer := 0.0

func Enter():
	player = get_tree().get_first_node_in_group("Player")
	# Crea un timer
	follow_timer = 0.0
	enemy.set_following(true)
	
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
	
	if enemy.get_following():
		follow_timer += delta
		if follow_timer >= follow_duration:
			enemy.set_following(false)
			Transitioned.emit(self, "Idle")
		
		if not ray_ground.is_colliding() and enemy.is_on_floor():
			follow_timer = follow_duration
			enemy.set_following(false)
			Transitioned.emit(self, "Idle")
		
		if enemy.direction != direction.normalized().x:
			Transitioned.emit(self, "ChangeDirection")
		
		if direction.length() <= 70:
			Transitioned.emit(self, "Attack")
		
		if not ray_ground.is_colliding():
			enemy.velocity.x = 0
			enemy.set_following(false)
			Transitioned.emit(self, "Idle")
		
		var velocity_x = direction.normalized().x * move_speed if abs(direction.x) > 25 else 0
		enemy.velocity.x = velocity_x
	#if direction.length() > 70:
		#Transitioned.emit(self, "Walk")
	#
	

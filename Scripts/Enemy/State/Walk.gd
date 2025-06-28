extends State
class_name WalkState

@export var enemy: Enemy
@export var ray_ground: RayCast2D
@export var ray_wall: RayCast2D
@export var speed: float = 35
@export var anim: AnimationPlayer

var player: CharacterBody2D

var direction 

func Enter():
	player = get_tree().get_first_node_in_group("Player")
	anim.play("walk")
	direction = enemy.direction
	
func Update(delta):
	if enemy.hit:
		Transitioned.emit(self, "Hit")
	
	var global_direction = player.global_position - enemy.global_position
	if  global_direction.length() < 120:
		Transitioned.emit(self, "Follow")
	
	if enemy.current_hp <= 0:
		Transitioned.emit(self, "Death")

func Physics_Update(delta):
	if enemy:
		enemy.velocity.x = speed * direction

	if enemy.is_on_floor():
		enemy.velocity.y = 0
	else:
		enemy.velocity.y += enemy.gravity * delta

	if not ray_ground.is_colliding() and enemy.is_on_floor():
		Transitioned.emit(self, "ChangeDirection")
	
	if ray_wall.is_colliding() and enemy.is_on_floor():
		Transitioned.emit(self, "ChangeDirection")

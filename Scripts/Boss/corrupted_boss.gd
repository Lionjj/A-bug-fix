extends CharacterBody2D

@onready var nav_agent = $NavigationAgent2D
@export var max_hp = 3
var current_hp = 3

var hit = false
var dead = false

var attack_positions: Array[Node2D] = []

var direction
var player: CharacterBody2D

var target_point: Node2D

signal damaged_player(player: Player)

var knockback:Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0

func _ready() -> void:
	var positions_node = get_tree().current_scene.get_node_or_null("AttackPositions")
	if positions_node == null:
		push_error("❌ Nodo 'AttackPositions' non trovato nella scena corrente!")
		return

	player = get_tree().get_first_node_in_group("Player")
	
	attack_positions = []
	for child in positions_node.get_children():
		if child is Node2D:
			attack_positions.append(child as Node2D)
	
	target_point = attack_positions[0]

	current_hp = max_hp
	direction = 1.0

func _physics_process(delta):
	move_and_slide()

func take_damage(damage: int):
	if dead:
		return
	
	current_hp -= damage
	hit = true

func find_closest_point_to_player() -> Node2D:

	if attack_positions.is_empty():
		push_error("❌ Nessuna posizione disponibile.")
		return null

	var closest := attack_positions[0]
	var min_dist = player.global_position.distance_to(closest.global_position)

	for point in attack_positions:
		var dist = player.global_position.distance_to(point.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = point

	return closest

func chose_attack()->String:
	var attack = ""
	if target_point.name == "TopLeft" or target_point.name == "TopRight":
		attack = "GroundPunch"
	elif target_point.name == "Center":
		attack = "Explosion"
	elif target_point.name == "BottomLeft" or target_point.name == "BottomRight":
		attack = "WaveAttack"
	
	return attack

func set_knockback(knockback):
	self.knockback = knockback

func set_knockback_timer(time):
	self.knockback_timer = time

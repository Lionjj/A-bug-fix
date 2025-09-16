extends State
class_name EnemyAttack1

@export var enemy: CharacterBody2D
@export var anim: AnimationPlayer
@export var ray_ground: RayCast2D
@export var attack_area: Area2D
@export var damage: int = 1
@export var charge_speed: float = 250.0
var charg_direction
var is_stunned = false
var prepare_charging = true

var player: CharacterBody2D


func Enter():
	prepare_charging = true
	is_stunned = false
	charg_direction = (enemy.get_player().global_position - enemy.global_position).normalized()
	
	anim.play("attack")
	if enemy.hit:
		return
	await anim.animation_finished
	
	Transitioned.emit(self,"Walk")

func Update(delta: float):
	if enemy.hit:
		Transitioned.emit(self, "Hit")
	
	if not ray_ground.is_colliding() and enemy.is_on_floor():
		enemy.velocity = Vector2.ZERO
		Transitioned.emit(self, "ChangeDirection")
	
	if is_stunned:
		Transitioned.emit(self, "Stun")

func _on_attack_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if not body.get_invicible():
			body.take_damage(damage)
			CombatMechanic.applay_knockback(body, enemy.global_position, 800, .08)
			CombatMechanic.hit_stop(.1, .2)

func charge():
	prepare_charging = false
	enemy.velocity.x = charg_direction.x*charge_speed

func Physics_Update(delta):
	if prepare_charging:
		enemy.velocity = Vector2.ZERO

func _on_attack_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("PlayerParry"):
		is_stunned = true
		#player = area.get_parent()

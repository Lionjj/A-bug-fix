extends State
class_name EnemyAttack1

@export var enemy: CharacterBody2D
@export var anim: AnimationPlayer
@export var attack_area: Area2D
@export var damage: int = 1

func Enter():
	enemy.velocity.x = 0
	anim.play("attack")
	await anim.animation_finished
	if enemy.hit:
		return
	Transitioned.emit(self,"Walk")

func Update(delta: float):
	if enemy.hit:
		Transitioned.emit(self, "Hit")

func check_attack_hits():
	var overlapping = attack_area.get_overlapping_areas()
	for area in overlapping:
		if area.get_parent().is_in_group("Player"):
			area.get_parent().take_damage(damage)

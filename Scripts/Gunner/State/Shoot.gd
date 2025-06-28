extends State

class_name GunnerShoot

@export var enemy: CharacterBody2D
@export var anim: AnimationPlayer
@export var bullet_scene: PackedScene

@export var damage: int = 1

func Enter():
	await _shoot()
	Transitioned.emit(self, "Idle")

func Update(delta: float):
	if enemy.hit:
		Transitioned.emit(self, "Hit")

func _shoot() -> void:
	anim.play("prepare_shoot")
	await anim.animation_finished
	
	anim.play("shoot")
	await anim.animation_finished

func init_bullet():
	var bullet = bullet_scene.instantiate()
	bullet.global_position = enemy.gun_point.global_position
	var player = enemy.get_player()
	
	var direction = (player.global_position - enemy.global_position).normalized()
	bullet.direction = direction

	get_tree().current_scene.add_child(bullet)

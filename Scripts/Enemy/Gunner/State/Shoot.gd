extends State

class_name GunnerShoot

@export var enemy: EnemyEntity
@export var anim: AnimationPlayer
@export var bullet_scene: PackedScene
@export var marker: Marker2D

@export var damage: int = 1

func Enter():
	await _shoot()
	Transitioned.emit(self, "Idle")

func Update(delta: float):
	if enemy.hit:
		Transitioned.emit(self, "Hit")
	if enemy.current_hp <= 0 or enemy.dead:
		Transitioned.emit(self, "Death")

func _shoot() -> void:
	if _interrupt(): return
	
	anim.play("prepare_shoot")
	await anim.animation_finished
	if _interrupt(): return
	
	anim.play("shoot")
	await anim.animation_finished
	if _interrupt(): return
	
	anim.play("reload")
	await anim.animation_finished
	if _interrupt(): return

func _interrupt() -> bool:
	return enemy.dead or enemy.hit or not enemy.is_active()

func init_bullet():
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	
	var player = enemy.get_player()
	marker.look_at(player.global_position)
	
	bullet.global_position = marker.global_position
	bullet.global_rotation = marker.global_rotation
	
	
	var direction = (player.global_position - marker.global_position).normalized()
	bullet.direction = direction

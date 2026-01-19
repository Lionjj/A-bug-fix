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
	if enemy.dead or not enemy.is_active(): return
	anim.play("prepare_shoot")
	await get_tree().create_timer(anim.current_animation_length).timeout
	
	if enemy.dead or not enemy.is_active(): return
	anim.play("shoot")
	await get_tree().create_timer(anim.current_animation_length).timeout
	
	if enemy.dead or not enemy.is_active(): return
	anim.play("reload")
	await get_tree().create_timer(anim.current_animation_length).timeout

func init_bullet():
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	
	var player = enemy.get_player()
	marker.look_at(player.global_position)
	
	bullet.global_position = marker.global_position
	bullet.global_rotation = marker.global_rotation
	
	
	var direction = (player.global_position - marker.global_position).normalized()
	bullet.direction = direction

extends State

class_name PunchAtt

@export var boss: CharacterBody2D
@export var punch_scene: PackedScene

var reached_position := false

func Enter():
	reached_position = false
	
	var tween = boss.create_tween()
	tween.tween_property(boss, "global_position", boss.target_point.global_position, 1.0)
	tween.tween_callback(Callable(self, "_on_reach_position"))

func _on_reach_position():
	reached_position = true
	spawn_punch_attack()

func spawn_punch_attack():
	if punch_scene == null:
		push_error("❌ punch_scene non assegnato!")
		return
	
	var punch = punch_scene.instantiate()
	punch.global_position = boss.global_position + Vector2(0, -50)
	get_tree().current_scene.add_child(punch)
	
	# ascolta il segnale dal pugno
	punch.connect("punch_hit_ground", Callable(self, "_on_punch_hit_ground"))

func _on_punch_hit_ground(impact_pos: Vector2):
	# Qui fai partire l'onda, camera shake, ecc.
	Transitioned.emit(self, "Idle")

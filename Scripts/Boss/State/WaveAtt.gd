extends State
class_name WaveAtt

@export var boss: CharacterBody2D
@export var wave_scene: PackedScene
@export var anim: AnimationPlayer

var reached_position := false

func Enter():
	reached_position = false
	
	var tween = boss.create_tween()
	tween.tween_property(boss, "global_position", boss.target_point.global_position, 1.0)
	tween.tween_callback(Callable(self, "_on_reach_position"))

func _on_reach_position():
	reached_position = true
	anim.play("bit_fade")
	await anim.animation_finished
	Transitioned.emit(self, "Idle")

func spawn_wave_attack():
	if wave_scene == null:
		push_error("❌ wave_scene non assegnato!")
		return
	
	var wave = wave_scene.instantiate()
	wave.global_position = boss.global_position
	
	# Direzione verso il player
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		var dir = (player.global_position - boss.global_position).normalized()
		wave.direction = dir
	else:
		push_error("❌ Player non trovato, onda non lanciata")
	
	get_tree().current_scene.add_child(wave)

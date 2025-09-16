extends Node2D

@onready var player: Node2D = $Player
@onready var cloud_path: PathFollow2D = $FlawerOBJ/Clouds/CloudPath/PathFollow2D
@export var is_following_cloud = true

func _ready():
	GameManager.set_player(player)
	player.movement_enabled = false
	# 📌 Salva posizione globale di Player e offset della Camera
	var saved_global_pos: Vector2 = player.global_position

	# 📦 Reparent nella nuvola
	#player.reparent(cloud_path)
	player.global_position = cloud_path.global_position + Vector2(0, -10)
	
	# ▶️ Avvia animazione della nuvola
	$WordAnimation.play("cloud_entry")
	await $WordAnimation.animation_finished

	# ⬇️ Avvia animazione salto dalla nuvola
	$WordAnimation.play("jump_off")
	await $WordAnimation.animation_finished

	var global_pos: Vector2 = player.global_position

	player.global_position = saved_global_pos
	

func _process(delta: float) -> void:
	if is_following_cloud:
		player.global_position = cloud_path.global_position + Vector2(0, -10)

func _on_livello_1_change_scene(ack: Callable) -> void:
	$WordAnimation.play("fade_out")
	await $WordAnimation.animation_finished
	
	ack.call()

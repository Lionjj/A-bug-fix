extends Node2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var camera_2d: Camera2D = $Camera2D
@export var unlock_on_quest: StringName

var palyer_cam: Camera2D 


func _ready() -> void:
	if not GameManager.player:
		var player = get_tree().current_scene.get_node_or_null("Player")
		
		if player: 
			palyer_cam = player.get_node_or_null("Camera2D")
	else:
		palyer_cam = GameManager.player.get_node_or_null("Camera2D")
		
	if not palyer_cam:
		return
		
	camera_2d.enabled = false
	if ObjectiveManager.has_signal("quest_completed"):
		ObjectiveManager.quest_completed.connect(start)
		unlock_on_quest = "%s_%s" % [unlock_on_quest, get_tree().current_scene.name]

func start(id: StringName):
	if not unlock_on_quest == id: return
	var anim: AnimationPlayer = get_tree().current_scene.get_node_or_null("WorldAnimation") as AnimationPlayer
	var bg_moon: Parallax2D = get_tree().current_scene.get_node_or_null("BG4") as Parallax2D
	var damaged_file: Area2D = get_tree().current_scene.get_node_or_null("DamagedFile") as Area2D
	
	
	if palyer_cam and camera_2d:
		if anim:
			anim.play("fade_out")
			await anim.animation_finished
		camera_2d.global_position = palyer_cam.global_position
		palyer_cam.enabled = false
		camera_2d.enabled = true
		camera_2d.zoom = Vector2(4, 4)
		GameManager.player.queue_free()
		
	visible = true
	if bg_moon:
		bg_moon.queue_free()
	
	if damaged_file:
		damaged_file.visible = false
	
	if anim:
		anim.play("fade_in")
		await anim.animation_finished
	
	animation_player.play("End")
	await animation_player.animation_finished
	
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()
	
	
	 

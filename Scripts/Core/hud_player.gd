extends CanvasLayer
@export var player: Player
@onready var h_container = $HBoxContainer
var heart_scene


func _ready() -> void:
	reset_heart()
	
func lose_heart() -> void:
	if h_container.get_child_count() <= 0:
		pass
	
	var last_heart = h_container.get_child(h_container.get_child_count() - 1)
	var heart_anim = last_heart.get_node("HeartAnimation")
	
	heart_anim.play("lost")
	await  heart_anim.animation_finished
	
	h_container.remove_child(last_heart)
	last_heart.queue_free()

func reset_heart() -> void:
	for heart in h_container.get_children():
		heart.queue_free()
	
	for i in player.max_hp:
		var heart_scene = preload("res://Scenes/GUI/Heart.tscn").instantiate()
		h_container.add_child(heart_scene)
		
		var heart_anim = heart_scene.get_node("HeartAnimation")
		heart_anim.play("idle")

func gain_heart():
	var heart_scene = preload("res://Scenes/GUI/Heart.tscn").instantiate()
	h_container.add_child(heart_scene)
		
	var heart_anim = heart_scene.get_node("HeartAnimation")
	heart_anim.play("gain")
	await  heart_anim.animation_finished
	
	
	for heart in h_container.get_children():
		var anim = heart.get_node("HeartAnimation")
		anim.play("idle")
		anim.seek(0, true) 

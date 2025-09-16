extends CanvasLayer
@export var player: Player
@onready var h_container = $HBoxContainer
@onready var obj_label = $ObjectiveLabel
var heart_scene = preload("res://Scenes/GUI/Heart.tscn")


func _ready() -> void:
	reset_heart()
	obj_label.text = ObjectiveManager.current_objective_text()
	ObjectiveManager.quest_updated.connect(_refresh)
	ObjectiveManager.quest_started.connect(_refresh)
	ObjectiveManager.quest_completed.connect(_refresh)
	
func lose_heart() -> void:
	if h_container.get_child_count() <= 0:
		pass
	
	var last_heart = h_container.get_child(h_container.get_child_count() - 1)
	var heart_anim = last_heart.get_node("HeartAnimation")
	
	heart_anim.play("lost")
	await  heart_anim.animation_finished

func reset_heart() -> void:
	if not player:
		return 
		
	for heart in h_container.get_children():
		heart.queue_free()
	
	for i in player.max_hp:
		var heart = heart_scene.instantiate()
		h_container.add_child(heart)
		
		var heart_anim = heart.get_node("HeartAnimation")
		heart_anim.play("idle")

func gain_heart():
	var heart = heart_scene.instantiate()
	h_container.add_child(heart)
		
	var heart_anim = heart.get_node("HeartAnimation")
	heart_anim.play("gain")
	await  heart_anim.animation_finished
	
	
	for h in h_container.get_children():
		var anim = h.get_node("HeartAnimation")
		anim.play("idle")
		anim.seek(0, true) 

func _refresh(_id := &"") -> void:
	obj_label.text = ObjectiveManager.current_objective_text()

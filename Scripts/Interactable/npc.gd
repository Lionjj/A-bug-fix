extends Node2D

@onready var interaction_area: InteractionArea = $InteractionArea
@onready var speech_sound = preload("res://Assets/Sound/speech.mp3")
@onready var sprite = $Sprite2D
@export var dialogue_lines: Array[String] = [
]

func _ready() -> void:
	interaction_area.interact = Callable(self, "_on_interact")

	
func _on_interact():
	DialogManager.start_dialog(global_position, dialogue_lines, speech_sound)
	sprite.flip_h = true if interaction_area.get_overlapping_bodies()[0].global_position.x < global_position.x else false
	await DialogManager.dialog_finished

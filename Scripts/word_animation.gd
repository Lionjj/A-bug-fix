extends AnimationPlayer



func _on_livello_1_enter_scene() -> void:
	play("fade_in")
	await animation_finished

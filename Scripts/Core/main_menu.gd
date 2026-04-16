extends Control

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/WorldScenes/IntroScene.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_generate_level_pressed() -> void:
	get_tree().change_scene_to_file("res://PCG/scenes/world/world_gen.tscn")

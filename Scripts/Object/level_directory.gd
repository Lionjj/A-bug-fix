extends Area2D

@export var text = ""

func _on_body_entered(body: Node2D) -> void:
	pass

func _ready() -> void:
	$Control/TitleLevel.text = text

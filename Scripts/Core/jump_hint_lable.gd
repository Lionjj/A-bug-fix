extends Label


func _ready() -> void:
	var key = get_parent().get_parent().get_key_for_action("jump")
	text = "Salta: [%s] " % key

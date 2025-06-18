extends Label


func _ready() -> void:
	var key_left = get_parent().get_parent().get_key_for_action("ui_left")
	var key_right = get_parent().get_parent().get_key_for_action("ui_right")
	text = "Muoviti: [%s] Sinistra / [%s] Destra" % [key_left, key_right]

extends Label

var keys = []

func _on_notification_action_sender(actions: Array[String], text: String) -> void:
	var text_to_insert = text if not text.is_empty() else ""
	
	if not actions.is_empty():

		for action in actions:
			keys.append(GameManager.get_key_for_action(action))
	
		text_to_insert = text % keys
	
	self.text = text_to_insert

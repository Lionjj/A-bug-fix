extends CanvasLayer

func get_key_for_action(action_name: String) -> String:
	var events := InputMap.action_get_events(action_name)
	for event in events:
		if event is InputEventKey:
			return OS.get_keycode_string(event.keycode)

		elif event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_LEFT: return "Mouse Sinistro"
				MOUSE_BUTTON_RIGHT: return "Mouse Destro"
				MOUSE_BUTTON_MIDDLE: return "Mouse Centrale"
				MOUSE_BUTTON_WHEEL_UP: return "Rotella ↑"
				MOUSE_BUTTON_WHEEL_DOWN: return "Rotella ↓"
				MOUSE_BUTTON_WHEEL_LEFT: return "Rotella ←"
				MOUSE_BUTTON_WHEEL_RIGHT: return "Rotella →"
				_: return "Mouse #%d" % event.button_index

		elif event is InputEventJoypadButton:
			return "Gamepad Btn %d" % event.button_index

		elif event is InputEventJoypadMotion:
			return "Gamepad Stick"

	return "?"

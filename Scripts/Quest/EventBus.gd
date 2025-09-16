extends Node

signal game_event(name: StringName, payload)

func emit_ev(name: StringName, payload := {}):
	game_event.emit(name, payload)

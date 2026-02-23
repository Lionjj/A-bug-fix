@tool
extends EditorInspectorPlugin
class_name RoomGeneratoInspectorPlugin


func _can_handle(object):
	return object is RoomGeneratorNode



func _parse_begin(object):
	var ui := preload("res://addons/room_generator_tool/room_generator_inspector_ui.gd").new()
	ui.setup(object)
	add_custom_control(ui)

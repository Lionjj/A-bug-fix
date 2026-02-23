@tool
extends EditorPlugin

var inspector_plugin

func _enter_tree():
	inspector_plugin = preload("res://addons/room_generator_tool/room_generator_inspector_plugin.gd").new()
	add_inspector_plugin(inspector_plugin)

func _exit_tree():
	remove_inspector_plugin(inspector_plugin)

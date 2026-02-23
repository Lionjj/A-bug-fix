@tool
extends VBoxContainer
class_name RoomGeneratorInspectorUi

var target: RoomGeneratorNode

func setup(node: RoomGeneratorNode):
	target = node
	_build()

func _build():
	var generate_btn := Button.new()
	generate_btn.text = "Generate"
	generate_btn.pressed.connect(_on_generate)
	add_child(generate_btn)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save)
	add_child(save_btn)

func _on_generate():
	var room := target.generate()
	if room:
		target.add_to_scene(room)

func _on_save():
	target.save_last()

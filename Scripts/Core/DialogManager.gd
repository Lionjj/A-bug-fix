extends Node

@onready var text_box_scene: Resource = preload("res://Scenes/text_box.tscn")

var dialog_lines: Array[String] = []
var current_line_index = 0

var text_box
var text_box_position: Vector2
var tail_pos: float

var sfx: AudioStream
var speech_player: AudioStreamPlayer

var is_dilog_activate = false
var can_advance_line = false

signal dialog_finished()

func start_dialog(position: Vector2, lines: Array[String], speech_sfx: AudioStream, tail_position = 0.5) -> void:
	if is_dilog_activate:
		return 
		
	dialog_lines = lines
	text_box_position = position
	sfx = speech_sfx
	tail_pos = tail_position
	_show_text_box()
	
	is_dilog_activate = true
	can_advance_line = false

func _show_text_box():
	text_box = text_box_scene.instantiate()
	text_box.finished_displaying.connect(_on_text_box_finished_displaying, CONNECT_ONE_SHOT)
	get_tree().root.add_child(text_box)
	text_box.global_position = text_box_position
	
	_start_speech_loop()
	
	text_box.display_text(dialog_lines[current_line_index])

func _on_text_box_finished_displaying():
	can_advance_line = true
	_stop_speech_loop()
	

func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("interact") &&
		is_dilog_activate &&
		can_advance_line
	): 
		
		text_box.queue_free()
		
		current_line_index += 1
		if current_line_index >= dialog_lines.size():
			is_dilog_activate = false
			current_line_index = 0
			dialog_finished.emit()
			return
		
		_show_text_box()

func _start_speech_loop() -> void:
	if sfx == null:
		return
	# chiudi eventuale player precedente
	if is_instance_valid(speech_player):
		speech_player.queue_free()

	speech_player = AudioStreamPlayer.new()
	speech_player.bus = "UI"  # o "SFX", come preferisci
	# duplichi lo stream per non toccare la risorsa originale
	var st := sfx.duplicate()
	if "loop" in st:
		st.loop = true  # per MP3/OGG
	speech_player.stream = st
	add_child(speech_player)
	speech_player.volume_db = -4.0   # regola a gusto
	speech_player.play()

func _stop_speech_loop() -> void:
	if not is_instance_valid(speech_player):
		return
	# piccolo fade-out per non tagliare secco
	var t := get_tree().create_tween()
	t.tween_property(speech_player, "volume_db", -60.0, 0.12)
	await t.finished
	speech_player.stop()
	speech_player.queue_free()
	speech_player = null

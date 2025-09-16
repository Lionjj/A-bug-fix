extends Node

@export var default_pitch_jitter :float= 0.10
var current_checkpoint : Checkpoint
var player : Player
		
var from_level
var enemy_num : int
		
var file_num : int :
	set(value):
		file_num = value

signal enemy_count_change(new_count: int)

#func _ready() -> void:
		#EventBus.game_event.connect(
			#func(ev: StringName, payload):
				#if ev == &"level_entered":
					#file_num = 0
		#)
		#await EventBus.game_event


func respawn_player():
	if current_checkpoint != null:
		player.position = current_checkpoint.global_position

func increment_enemy(): 
	enemy_num += 1 
	enemy_count_change.emit(enemy_num)

func decrement_enemy(): 
	enemy_num = max(0, enemy_num - 1) 
	enemy_count_change.emit(enemy_num)

func set_player(p : Player): self.player = p

func play_one_shot(
	stream: AudioStream, 
	pitch: float = 1.0,
	pitch_jitter: float = default_pitch_jitter,
	vol_db : float = 0.0, 
	pos: Vector2 = Vector2(0,0), 
	bus: StringName= "SFX", 
	) -> void:
		

	if not (stream and player):
		return 
		
	var p := AudioStreamPlayer2D.new()
	p.bus = bus
	p.stream = stream
	p.volume_db = vol_db
	
	var factor := 1.0
	if pitch_jitter > 0.0:
		# randf_range è comodo; clamp per evitare 0 o valori esagerati
		factor = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.pitch_scale = clamp(pitch * factor, 0.05, 4.0)

	
	add_child(p)
	p.global_position = player.global_position
	p.finished.connect(p.queue_free)
	p.play()

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

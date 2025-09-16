extends MarginContainer

@onready var label = $MarginContainer/Label
@onready var timer = $LetterDisplayTimer

const MAX_WIDTH = 256
const MIN_WIDTH = 64

var text = ""
var letter_index = 0

var letter_time = 0.03
var space_time = 0.06
var punctuation_time = 0.2

signal finished_displaying()

func display_text(text_to_dispaly: String):
	text = text_to_dispaly
	label.text = text_to_dispaly
	
	await resized
		
	custom_minimum_size.x = clamp(size.x, MIN_WIDTH, MAX_WIDTH)
		
	if size.x > MAX_WIDTH:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		await resized
		custom_minimum_size.y = size.y
		
	global_position.x -= size.x / 2
	global_position.y -= size.y + 48
	
	label.text = ""
	_display_letter()

func _display_letter():
	if letter_index >= text.length():
		finished_displaying.emit()
		return
	
	label.text += text[letter_index]
	
	match text[letter_index]:
		"!", ".", ",", "?":
			timer.start(punctuation_time)
		" ":
			timer.start(space_time)
		_:
			timer.start(letter_time)

	
	letter_index += 1


func _on_letter_display_timer_timeout() -> void:
	_display_letter()

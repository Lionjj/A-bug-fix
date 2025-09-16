extends Panel
class_name ErrorWindow

@onready var player = $AudioStreamPlayer2D

@export var messages := [
	"Fatal Error: 0xC0FFEE",
	"Access Violation \n at 0xDEADBEEF",
	"Unknown Exception: \n 0xBADC0DE",
	"Disk Corruption detected.",
	"Driver not found."
]

func randomize_content():
	$NinePatchRect/Title.text = "System Error"
	$NinePatchRect/Body.text = messages[randi() % messages.size()]

func pop_in():
	# animazione ingresso
	player.play(25.90)
	scale = Vector2(0.8, 0.8)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 1.0, 0.12)
	
func tiny_shake():
	var tw := create_tween()
	var base := position
	for i in 4:
		tw.tween_property(self, "position", base + Vector2(randf()*6-3, randf()*6-3), 0.03)
	tw.tween_property(self, "position", base, 0.04)

func _process(delta: float) -> void:
	if player.playing and player.get_playback_position() >= 26.5:
		player.stop()
